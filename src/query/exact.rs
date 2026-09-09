use std::collections::HashSet;

use tantivy::query::{BooleanQuery, Occur, Query, RegexQuery, TermQuery};
use tantivy::schema::IndexRecordOption;
use tantivy::{Index, IndexReader, Term};

use crate::ffi::{CompletionContext, CompletionHit};
use crate::index::live_index_dir;

use super::IndexSrc;
use super::hit::doc_hit;
use super::parse::escape_regex;
use super::rank::Ranking;

pub fn exact_search(
    src: IndexSrc<'_>,
    name: &str,
    qualifier: Option<&str>,
    limit: usize,
) -> Vec<CompletionHit> {
    match src {
        IndexSrc::Live(index, reader) => run(index, reader, name, qualifier, limit),
        IndexSrc::Dir(dir) => {
            let Some(live) = live_index_dir(dir) else {
                return Vec::new();
            };
            let Ok(index) = Index::open_in_dir(live) else {
                return Vec::new();
            };
            let Ok(reader) = index.reader() else {
                return Vec::new();
            };
            run(&index, &reader, name, qualifier, limit)
        }
    }
}

fn run(
    index: &Index,
    reader: &IndexReader,
    name: &str,
    qualifier: Option<&str>,
    limit: usize,
) -> Vec<CompletionHit> {
    let schema = index.schema();
    let Ok(name_exact) = schema.get_field("name_exact") else {
        return Vec::new();
    };
    let low = name.to_ascii_lowercase();
    let mut clauses: Vec<(Occur, Box<dyn Query>)> = vec![(
        Occur::Must,
        Box::new(TermQuery::new(
            Term::from_field_text(name_exact, &low),
            IndexRecordOption::Basic,
        )),
    )];
    if let Some(q) = qualifier
        && let Ok(path_exact) = schema.get_field("path_exact")
    {
        let pat = format!(
            ".*{}::{}",
            escape_regex(&q.to_ascii_lowercase()),
            escape_regex(&low)
        );
        if let Ok(rx) = RegexQuery::from_pattern(&pat, path_exact) {
            clauses.push((Occur::Must, Box::new(rx)));
        }
    }
    let ranking = Ranking {
        prefix_len: low.chars().count() as u64,
        context: CompletionContext::Unknown,
    };
    let searcher = reader.searcher();
    let Ok(top) = searcher.search(
        &BooleanQuery::new(clauses),
        &tantivy::collector::TopDocs::with_limit(limit * 4).tweak_score(
            move |seg: &tantivy::SegmentReader| {
                let cols = super::rank::Columns::open(seg);
                move |doc: tantivy::DocId, bm25: tantivy::Score| cols.score(doc, bm25, ranking)
            },
        ),
    ) else {
        return Vec::new();
    };
    let mut seen = HashSet::new();
    let mut hits: Vec<CompletionHit> = top
        .into_iter()
        .filter_map(|(score, addr)| doc_hit(&searcher, &schema, addr, score, &low))
        .filter(|h| seen.insert((h.path.clone(), h.crate_name.clone())))
        .collect();
    hits.sort_by(|a, b| b.score.total_cmp(&a.score));
    hits.truncate(limit);
    hits
}
