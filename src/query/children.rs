use tantivy::query::{BooleanQuery, Occur, Query, RegexQuery, TermQuery};
use tantivy::schema::{IndexRecordOption, Schema};
use tantivy::{Index, IndexReader, Term};

use crate::ffi::{CompletionContext, CompletionHit, ItemKind};
use crate::index::MAX_GRAM;

use super::IndexSrc;
use super::collect::BestPerName;
use super::hit::doc_hit;
use super::parse::{escape_regex, kind_term};
use super::rank::Ranking;
use super::search::open_dir;

pub enum Filter {
    Parent(String),
    Kind(ItemKind),
}

pub fn children(
    src: IndexSrc<'_>,
    parent: &str,
    prefix: &str,
    limit: usize,
    context: CompletionContext,
) -> Vec<CompletionHit> {
    listed(
        src,
        Filter::Parent(parent.to_string()),
        prefix,
        limit,
        context,
    )
}

pub fn listed(
    src: IndexSrc<'_>,
    filter: Filter,
    prefix: &str,
    limit: usize,
    context: CompletionContext,
) -> Vec<CompletionHit> {
    match src {
        IndexSrc::Live(index, reader) => run(index, reader, &filter, prefix, limit, context),
        IndexSrc::Dir(dir) => open_dir(dir)
            .map(|(index, reader)| run(&index, &reader, &filter, prefix, limit, context))
            .unwrap_or_default(),
    }
}

fn run(
    index: &Index,
    reader: &IndexReader,
    filter: &Filter,
    prefix: &str,
    limit: usize,
    context: CompletionContext,
) -> Vec<CompletionHit> {
    let schema = index.schema();
    let low = prefix.to_ascii_lowercase();
    let Some(filter_clause) = clause(&schema, filter) else {
        return Vec::new();
    };
    let mut clauses: Vec<(Occur, Box<dyn Query>)> = vec![(Occur::Must, filter_clause)];
    if !low.is_empty()
        && let Ok(field) = schema.get_field("name_prefix")
    {
        let gram: String = low.chars().take(MAX_GRAM).collect();
        clauses.push((
            Occur::Must,
            Box::new(TermQuery::new(
                Term::from_field_text(field, &gram),
                IndexRecordOption::Basic,
            )),
        ));
    }
    let ranking = Ranking {
        prefix_len: low.chars().count() as u64,
        context,
    };
    let searcher = reader.searcher();
    let Ok(top) = searcher.search(
        &BooleanQuery::new(clauses),
        &BestPerName {
            limit: limit.saturating_mul(4).max(40),
            ranking,
        },
    ) else {
        return Vec::new();
    };
    let mut hits: Vec<CompletionHit> = top
        .into_iter()
        .filter_map(|(score, addr)| doc_hit(&searcher, &schema, addr, score, &low))
        .collect();
    hits.sort_by(|a, b| b.score.total_cmp(&a.score));
    hits
}

fn clause(schema: &Schema, filter: &Filter) -> Option<Box<dyn Query>> {
    match filter {
        Filter::Kind(kind) => {
            let field = schema.get_field("item_kind").ok()?;
            Some(Box::new(TermQuery::new(
                Term::from_field_text(field, kind_term(*kind)),
                IndexRecordOption::Basic,
            )))
        }
        Filter::Parent(parent) => {
            let parent = parent.to_ascii_lowercase();
            if let Ok(field) = schema.get_field("parent_path") {
                return Some(Box::new(TermQuery::new(
                    Term::from_field_text(field, &parent),
                    IndexRecordOption::Basic,
                )));
            }
            let field = schema.get_field("path_exact").ok()?;
            let pat = format!("{}::[^:]+", escape_regex(&parent));
            RegexQuery::from_pattern(&pat, field)
                .ok()
                .map(|rx| Box::new(rx) as Box<dyn Query>)
        }
    }
}
