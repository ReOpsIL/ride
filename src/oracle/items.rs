use serde_json::Value;

use crate::ffi::{CompletionHit, ItemKind};
use crate::score::TIER_ITEM;
use crate::text::first_sentence;

const METHOD: u64 = 2;
const FUNCTION: u64 = 3;
const FIELD: u64 = 5;
const PROPERTY: u64 = 10;
const SNIPPET_FORMAT: u64 = 2;
const DEPRECATED_TAG: u64 = 1;

pub fn member_hits(result: &Value) -> Vec<CompletionHit> {
    let items = result
        .get("items")
        .unwrap_or(result)
        .as_array()
        .map(Vec::as_slice)
        .unwrap_or_default();
    let mut hits: Vec<(Owner, CompletionHit)> = items.iter().filter_map(member).collect();
    hits.sort_by(|a, b| a.0.cmp(&b.0).then_with(|| a.1.name.cmp(&b.1.name)));
    hits.into_iter().map(|(_, hit)| hit).collect()
}

#[derive(PartialEq, Eq, PartialOrd, Ord)]
enum Owner {
    Field,
    Inherent,
    Trait,
}

fn member(item: &Value) -> Option<(Owner, CompletionHit)> {
    let kind = match item["kind"].as_u64()? {
        METHOD => ItemKind::Method,
        FUNCTION => ItemKind::Fn,
        FIELD | PROPERTY => ItemKind::Field,
        _ => return None,
    };
    let label = item["label"].as_str()?;
    let name = name_of(label);
    if name.is_empty() {
        return None;
    }
    let detail = item["detail"].as_str().unwrap_or_default();
    let owner_trait = trait_of(label);
    let mut hit = CompletionHit::local(name, kind, TIER_ITEM, None);
    let insert = insert_text(item).unwrap_or(name);
    hit.snippet = item["insertTextFormat"].as_u64() == Some(SNIPPET_FORMAT) && insert.contains('$');
    hit.insert_text = insert.to_string();
    hit.signature = signature(name, kind, detail);
    hit.detail = owner_trait.unwrap_or_default().to_string();
    hit.doc_paragraph = documentation(item);
    hit.doc_first_sentence = first_sentence(&hit.doc_paragraph);
    hit.deprecated = deprecated(item);
    let owner = match (kind, owner_trait) {
        (ItemKind::Field, _) => Owner::Field,
        (_, Some(_)) => Owner::Trait,
        _ => Owner::Inherent,
    };
    Some((owner, hit))
}

fn name_of(label: &str) -> &str {
    label
        .split(['(', ' ', '<'])
        .next()
        .unwrap_or_default()
        .trim()
}

fn trait_of(label: &str) -> Option<&str> {
    let start = label.rfind("(as ")? + 4;
    label[start..].strip_suffix(')')
}

fn insert_text(item: &Value) -> Option<&str> {
    item["textEdit"]["newText"]
        .as_str()
        .or_else(|| item["insertText"].as_str())
}

fn signature(name: &str, kind: ItemKind, detail: &str) -> String {
    match (kind, detail.strip_prefix("fn")) {
        (ItemKind::Field, _) => format!("{name}: {detail}"),
        (_, Some(rest)) => format!("fn {name}{rest}"),
        _ => detail.to_string(),
    }
}

fn documentation(item: &Value) -> String {
    let doc = &item["documentation"];
    doc.as_str()
        .or_else(|| doc["value"].as_str())
        .unwrap_or_default()
        .to_string()
}

fn deprecated(item: &Value) -> bool {
    item["deprecated"].as_bool().unwrap_or(false)
        || item["tags"]
            .as_array()
            .is_some_and(|tags| tags.iter().any(|t| t.as_u64() == Some(DEPRECATED_TAG)))
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::*;

    fn sample() -> Value {
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
    fn fields_then_inherent_then_trait_methods() {
        let names: Vec<String> = member_hits(&sample()).into_iter().map(|h| h.name).collect();
        assert_eq!(names, ["len", "remainder", "map", "rev"]);
    }

    #[test]
    fn a_trait_method_keeps_its_snippet_signature_and_owner() {
        let hits = member_hits(&sample());
        let map = hits.iter().find(|h| h.name == "map").expect("map");
        assert!(map.snippet);
        assert_eq!(map.insert_text, "map(${1:f})$0");
        assert_eq!(map.signature, "fn map(self, F) -> Map<Self, F>");
        assert_eq!(map.detail, "Iterator");
        assert_eq!(map.doc_first_sentence, "Takes a closure");
        assert_eq!(map.item_kind, ItemKind::Method);
    }

    #[test]
    fn a_field_reads_as_name_and_type() {
        let hits = member_hits(&sample());
        let len = hits.iter().find(|h| h.name == "len").expect("len");
        assert_eq!(len.signature, "len: usize");
        assert!(!len.snippet);
        assert_eq!(len.insert_text, "len");
    }
}
