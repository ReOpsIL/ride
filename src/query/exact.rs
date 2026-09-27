use std::collections::HashSet;

use tantivy::collector::TopDocs;
use tantivy::query::{BooleanQuery, Occur, Query, RegexQuery, TermQuery};
use tantivy::schema::{IndexRecordOption, Schema};
use tantivy::{DocId, Index, IndexReader, Score, SegmentReader, Term};

use crate::ffi::{CompletionContext, CompletionHit};

use super::IndexSrc;
use super::hit::doc_hit;
use super::parse::escape_regex;
use super::rank::{Columns, Ranking};

type Clause = (Occur, Box<dyn Query>);

pub fn exact_search(
    src: IndexSrc<'_>,
    name: &str,
    qualifier: Option<&str>,
    limit: usize,
) -> Vec<CompletionHit> {
    src.with(Vec::new(), |index, reader| {
        run(index, reader, name, qualifier, limit)
    })
}

fn run(
    index: &Index,
    reader: &IndexReader,
    name: &str,
    qualifier: Option<&str>,
    limit: usize,
) -> Vec<CompletionHit> {
    let schema = index.schema();
    let low = name.to_ascii_lowercase();
    let Some(clauses) = clauses(&schema, &low, qualifier) else {
        return Vec::new();
    };
    let ranking = Ranking {
        prefix_len: low.chars().count() as u64,
        context: CompletionContext::Unknown,
    };
    let searcher = reader.searcher();
    let collector = TopDocs::with_limit(limit * 4).tweak_score(move |seg: &SegmentReader| {
        let cols = Columns::open(seg);
        move |doc: DocId, bm25: Score| cols.score(doc, bm25, ranking)
    });
    let Ok(top) = searcher.search(&BooleanQuery::new(clauses), &collector) else {
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

fn clauses(schema: &Schema, low: &str, qualifier: Option<&str>) -> Option<Vec<Clause>> {
    let name_exact = schema.get_field("name_exact").ok()?;
    let mut clauses: Vec<Clause> = vec![(
        Occur::Must,
        Box::new(TermQuery::new(
            Term::from_field_text(name_exact, low),
            IndexRecordOption::Basic,
        )),
    )];
    if let Some(q) = qualifier
        && let Ok(path_exact) = schema.get_field("path_exact")
    {
        let pat = format!(
            "(.*::)?{}::{}",
            escape_regex(&q.to_ascii_lowercase()),
            escape_regex(low)
        );
        if let Ok(rx) = RegexQuery::from_pattern(&pat, path_exact) {
            clauses.push((Occur::Must, Box::new(rx)));
        }
    }
    Some(clauses)
}
