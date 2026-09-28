use serde_json::Value;

use crate::ffi::CompletionHit;

use super::members::members;
use super::parse::parse;
use super::scope::scope;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Shape {
    Members,
    Scope,
}

pub fn completion_hits(result: &Value, shape: Shape) -> Vec<CompletionHit> {
    let parsed = result
        .get("items")
        .unwrap_or(result)
        .as_array()
        .map(Vec::as_slice)
        .unwrap_or_default()
        .iter()
        .filter_map(parse)
        .collect();
    match shape {
        Shape::Members => members(parsed),
        Shape::Scope => scope(parsed),
    }
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::*;
    use crate::ffi::ItemKind;

    fn names(hits: &[CompletionHit]) -> Vec<&str> {
        hits.iter().map(|h| h.name.as_str()).collect()
    }

    fn members_sample() -> Value {
        json!({ "isIncomplete": true, "items": [
            { "label": "map(…)(as Iterator)", "kind": 2, "detail": "fn(self, F) -> Map<Self, F>",
              "insertTextFormat": 2, "textEdit": { "newText": "map(${1:f})$0" },
              "documentation": { "kind": "markdown", "value": "Takes a closure. More text." } },
            { "label": "rev()(alias reverse) (as Iterator)", "kind": 2, "detail": "fn(self) -> Rev<Self>",
              "insertTextFormat": 2, "textEdit": { "newText": "rev()$0" } },
            { "label": "remainder()", "kind": 2, "detail": "fn(&self) -> Option<&str>",
              "insertTextFormat": 2, "textEdit": { "newText": "remainder()$0" } },
            { "label": "len", "kind": 5, "detail": "usize" },
            { "label": "match", "kind": 14 }
        ]})
    }

    #[test]
    fn members_list_fields_then_inherent_then_trait_methods() {
        let hits = completion_hits(&members_sample(), Shape::Members);
        assert_eq!(names(&hits), ["len", "remainder", "map", "rev"]);
    }

    #[test]
    fn a_trait_method_keeps_its_snippet_signature_and_owner() {
        let hits = completion_hits(&members_sample(), Shape::Members);
        let map = hits.iter().find(|h| h.name == "map").expect("map");
        assert!(map.snippet);
        assert_eq!(map.insert_text, "map(${1:f})$0");
        assert_eq!(map.signature, "fn map(self, F) -> Map<Self, F>");
        assert_eq!(map.detail, "Iterator");
        assert_eq!(map.doc_first_sentence, "Takes a closure");
        assert_eq!(map.item_kind, ItemKind::Method);
    }

    #[test]
    fn scope_follows_relevance_then_name_and_drops_keywords() {
        let result = json!([
            { "label": "self::", "kind": 14, "sortText": "7fffffff" },
            { "label": "HashMap", "kind": 22, "sortText": "7ffffffa" },
            { "label": "total", "kind": 6, "detail": "i32", "sortText": "7ffffff9" },
            { "label": "Counter", "kind": 22, "sortText": "7ffffffa" },
            { "label": "println!(…)", "kind": 3, "detail": "macro_rules! println", "sortText": "7fffffff" }
        ]);
        let hits = completion_hits(&result, Shape::Scope);
        assert_eq!(names(&hits), ["total", "Counter", "HashMap", "println"]);
    }
}
