use tantivy::collector::TopDocs;
use tantivy::query::{BooleanQuery, Occur, QueryParser, RegexQuery, TermQuery};
use tantivy::schema::IndexRecordOption;
use tantivy::{Index, Term};

use crate::ffi::{CompletionHit, CompletionQuery, CompletionResponse, QueryMode};

use super::hit::doc_hit;
use super::parse::{escape_regex, kind_term};

pub fn item_search(
    index: &Index,
    reader: &tantivy::IndexReader,
    schema: &tantivy::schema::Schema,
    name_exact: tantivy::schema::Field,
    q: &CompletionQuery,
    prefix: &str,
    limit: u32,
) -> CompletionResponse {
    let searcher = reader.searcher();
    let mut clauses: Vec<(Occur, Box<dyn tantivy::query::Query>)> = Vec::new();
    let low = prefix.to_ascii_lowercase();
    let pat = format!("{}.*", escape_regex(&low));
    if let Ok(rx) = RegexQuery::from_pattern(&pat, name_exact) {
        clauses.push((Occur::Should, Box::new(rx)));
    }
    if let Ok(path_exact) = schema.get_field("path_exact")
        && let Ok(rx) = RegexQuery::from_pattern(&pat, path_exact)
    {
        clauses.push((Occur::Should, Box::new(rx)));
    }
    let text_fields: Vec<_> = ["name", "path", "signature", "doc_first_paragraph"]
        .iter()
        .filter_map(|n| schema.get_field(n).ok())
        .collect();
    if !text_fields.is_empty() && (q.mode == QueryMode::Phrase || prefix.contains(' ')) {
        let parser = QueryParser::for_index(index, text_fields);
        if let Ok(parsed) = parser.parse_query(prefix) {
            clauses.push((Occur::Should, parsed));
        }
    }
    push_term(
        &mut clauses,
        schema,
        "item_kind",
        q.kind_filter.map(kind_term),
    );
    push_term(&mut clauses, schema, "crate", q.current_crate.as_deref());
    if let Some(module) = &q.current_module
        && let Ok(path_exact) = schema.get_field("path_exact")
    {
        let pat = format!("{}.*", escape_regex(&module.to_ascii_lowercase()));
        if let Ok(rx) = RegexQuery::from_pattern(&pat, path_exact) {
            clauses.push((Occur::Must, Box::new(rx)));
        }
    }
    if clauses.is_empty() {
        return CompletionResponse {
            query_id: q.query_id,
            hits: Vec::new(),
            truncated: false,
        };
    }
    let bq = BooleanQuery::new(clauses);
    let fetch = (limit as usize).saturating_mul(4).max(20);
    let Ok(top) = searcher.search(&bq, &TopDocs::with_limit(fetch)) else {
        return CompletionResponse {
            query_id: q.query_id,
            hits: Vec::new(),
            truncated: false,
        };
    };
    let mut hits: Vec<CompletionHit> = top
        .into_iter()
        .filter_map(|(score, addr)| doc_hit(&searcher, schema, addr, score, prefix))
        .collect();
    hits.sort_by(|a, b| {
        b.score
            .partial_cmp(&a.score)
            .unwrap_or(std::cmp::Ordering::Equal)
    });
    let truncated = hits.len() > limit as usize;
    hits.truncate(limit as usize);
    CompletionResponse {
        query_id: q.query_id,
        hits,
        truncated,
    }
}

fn push_term(
    clauses: &mut Vec<(Occur, Box<dyn tantivy::query::Query>)>,
    schema: &tantivy::schema::Schema,
    field: &str,
    value: Option<&str>,
) {
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
