use tantivy::query::{BooleanQuery, Occur, Query, QueryParser, RegexQuery, TermQuery};
use tantivy::schema::{Field, IndexRecordOption, Schema};
use tantivy::{Index, Term};

use crate::ffi::{CompletionHit, CompletionQuery, CompletionResponse, QueryMode};
use crate::index::MAX_GRAM;

use super::hit::doc_hit;
use super::parse::{escape_regex, kind_term};
use super::rank;

type Clause = (Occur, Box<dyn Query>);

pub fn item_search(
    index: &Index,
    reader: &tantivy::IndexReader,
    schema: &Schema,
    q: &CompletionQuery,
    prefix: &str,
    limit: u32,
) -> CompletionResponse {
    let empty = CompletionResponse {
        query_id: q.query_id,
        hits: Vec::new(),
        truncated: false,
    };
    let low = prefix.to_ascii_lowercase();
    let phrase = q.mode == QueryMode::Phrase || prefix.contains(' ');
    let mut clauses: Vec<Clause> = Vec::new();
    if phrase {
        push_phrase(&mut clauses, index, schema, prefix);
    } else if let Ok(field) = schema.get_field("name_prefix") {
        clauses.push((Occur::Must, Box::new(prefix_term(field, &low))));
    }
    push_term(
        &mut clauses,
        schema,
        "item_kind",
        q.kind_filter.map(kind_term),
    );
    push_term(&mut clauses, schema, "crate", q.current_crate.as_deref());
    push_module(&mut clauses, schema, q.current_module.as_deref());
    if clauses.is_empty() {
        return empty;
    }
    let searcher = reader.searcher();
    let fetch = (limit as usize).saturating_mul(4).max(40);
    let guard = if phrase { "" } else { low.as_str() };
    let prefix_len = if phrase {
        u64::MAX
    } else {
        low.chars().count() as u64
    };
    let Ok(top) = searcher.search(
        &BooleanQuery::new(clauses),
        &rank::collector(fetch, prefix_len),
    ) else {
        return empty;
    };
    let mut hits: Vec<CompletionHit> = top
        .into_iter()
        .filter_map(|(score, addr)| doc_hit(&searcher, schema, addr, score, guard))
        .collect();
    hits.sort_by(|a, b| b.score.total_cmp(&a.score));
    let truncated = hits.len() > limit as usize;
    hits.truncate(limit as usize);
    CompletionResponse {
        query_id: q.query_id,
        hits,
        truncated,
    }
}

fn prefix_term(field: Field, low: &str) -> TermQuery {
    let gram: String = low.chars().take(MAX_GRAM).collect();
    TermQuery::new(
        Term::from_field_text(field, &gram),
        IndexRecordOption::WithFreqs,
    )
}

fn push_phrase(clauses: &mut Vec<Clause>, index: &Index, schema: &Schema, text: &str) {
    let fields: Vec<Field> = ["name", "path", "signature", "doc_first_paragraph"]
        .iter()
        .filter_map(|n| schema.get_field(n).ok())
        .collect();
    if fields.is_empty() {
        return;
    }
    if let Ok(parsed) = QueryParser::for_index(index, fields).parse_query(text) {
        clauses.push((Occur::Must, parsed));
    }
}

fn push_module(clauses: &mut Vec<Clause>, schema: &Schema, module: Option<&str>) {
    let Some(module) = module else {
        return;
    };
    let Ok(field) = schema.get_field("path_exact") else {
        return;
    };
    let pat = format!("{}.*", escape_regex(&module.to_ascii_lowercase()));
    if let Ok(rx) = RegexQuery::from_pattern(&pat, field) {
        clauses.push((Occur::Must, Box::new(rx)));
    }
}

fn push_term(clauses: &mut Vec<Clause>, schema: &Schema, field: &str, value: Option<&str>) {
    let Some(value) = value else {
        return;
    };
    let Ok(f) = schema.get_field(field) else {
        return;
    };
    let term = Term::from_field_text(f, value);
    clauses.push((
        Occur::Must,
        Box::new(TermQuery::new(term, IndexRecordOption::Basic)),
    ));
}
