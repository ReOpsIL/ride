use serde_json::Value;

use crate::ffi::{CompletionHit, ItemKind};
use crate::score::TIER_ITEM;
use crate::text::first_sentence;

use super::dialect::Dialect;
use super::kind::item_kind;

const SNIPPET_FORMAT: u64 = 2;
const DEPRECATED_TAG: u64 = 1;

pub struct Parsed {
    pub hit: CompletionHit,
    pub from_trait: bool,
    pub sort_text: String,
}

pub fn parse(item: &Value, dialect: Dialect) -> Option<Parsed> {
    let label = item["label"].as_str()?;
    let detail = item["detail"].as_str().unwrap_or_default();
    let is_macro = label.contains("!(") || detail.starts_with("macro_rules!");
    let kind = item_kind(item["kind"].as_u64()?, is_macro, dialect)?;
    let name = name_of(label);
    if name.is_empty() {
        return None;
    }
    let owner = trait_of(label);
    let insert = insert_text(item).unwrap_or(name);
    let mut hit = CompletionHit::local(name, kind, TIER_ITEM, None);
    hit.snippet = item["insertTextFormat"].as_u64() == Some(SNIPPET_FORMAT) && insert.contains('$');
    hit.insert_text = insert.to_string();
    hit.signature = match dialect {
        Dialect::Rust => signature(name, kind, detail),
        Dialect::Clang => c_signature(name, kind, detail, label),
    };
    hit.detail = owner.unwrap_or_default().to_string();
    hit.doc_paragraph = documentation(item);
    hit.doc_first_sentence = first_sentence(&hit.doc_paragraph);
    hit.deprecated = deprecated(item);
    Some(Parsed {
        hit,
        from_trait: owner.is_some(),
        sort_text: item["sortText"].as_str().unwrap_or_default().to_string(),
    })
}

fn name_of(label: &str) -> &str {
    let head = label
        .trim_start()
        .split(['(', ' ', '<', '!'])
        .next()
        .unwrap_or_default();
    head.rsplit("::").next().unwrap_or_default()
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
    let typed = matches!(
        kind,
        ItemKind::Field | ItemKind::Local | ItemKind::Const | ItemKind::Static
    );
    if typed && !detail.is_empty() {
        return format!("{name}: {detail}");
    }
    match (kind, fn_rest(detail)) {
        (ItemKind::Fn | ItemKind::Method, Some((prefix, rest))) => {
            format!("{prefix}fn {name}{rest}")
        }
        (ItemKind::Macro, _) => detail.to_string(),
        _ => String::new(),
    }
}

fn c_signature(name: &str, kind: ItemKind, detail: &str, label: &str) -> String {
    let label = label.trim();
    let tail = label.find(name).map_or(label, |at| &label[at..]);
    match kind {
        ItemKind::Fn | ItemKind::Method if !detail.is_empty() => format!("{detail} {tail}"),
        ItemKind::Fn | ItemKind::Method => tail.to_string(),
        ItemKind::Field | ItemKind::Local | ItemKind::Const if !detail.is_empty() => {
            format!("{detail} {name}")
        }
        _ => String::new(),
    }
}

fn fn_rest(detail: &str) -> Option<(&str, &str)> {
    let at = detail.find("fn(")?;
    Some((&detail[..at], &detail[at + 2..]))
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

    #[test]
    fn a_clangd_method_reads_like_a_c_declaration() {
        let item = json!({ "label": " area() const", "kind": 2, "detail": "Real",
            "insertTextFormat": 2, "textEdit": { "newText": "area()" }, "sortText": "40620f8barea" });
        let parsed = parse(&item, Dialect::Clang).expect("parsed");
        assert_eq!(parsed.hit.name, "area");
        assert_eq!(parsed.hit.signature, "Real area() const");
        assert!(!parsed.hit.snippet);
    }

    #[test]
    fn a_qualified_clangd_label_is_named_by_its_last_segment() {
        let item = json!({ "label": " geo::Registry", "kind": 7,
            "textEdit": { "newText": "geo::Registry" } });
        let parsed = parse(&item, Dialect::Clang).expect("parsed");
        assert_eq!(parsed.hit.name, "Registry");
        assert_eq!(parsed.hit.insert_text, "geo::Registry");
        assert_eq!(parsed.hit.item_kind, ItemKind::Class);
    }

    #[test]
    fn a_macro_is_named_without_its_bang_and_keeps_its_snippet() {
        let item = json!({ "label": "println!(…)", "kind": 3, "detail": "macro_rules! println",
            "insertTextFormat": 2, "textEdit": { "newText": "println!($0)" } });
        let parsed = parse(&item, Dialect::Rust).expect("parsed");
        assert_eq!(parsed.hit.name, "println");
        assert_eq!(parsed.hit.item_kind, ItemKind::Macro);
        assert_eq!(parsed.hit.insert_text, "println!($0)");
        assert!(parsed.hit.snippet);
    }

    #[test]
    fn a_const_fn_keeps_its_qualifier_in_the_signature() {
        let item =
            json!({ "label": "capacity()", "kind": 2, "detail": "const fn(&self) -> usize" });
        let parsed = parse(&item, Dialect::Rust).expect("parsed");
        assert_eq!(parsed.hit.signature, "const fn capacity(&self) -> usize");
    }

    #[test]
    fn a_local_reads_as_name_and_type() {
        let item = json!({ "label": "total", "kind": 6, "detail": "i32", "sortText": "7ffffff9" });
        let parsed = parse(&item, Dialect::Rust).expect("parsed");
        assert_eq!(parsed.hit.item_kind, ItemKind::Local);
        assert_eq!(parsed.hit.signature, "total: i32");
        assert_eq!(parsed.sort_text, "7ffffff9");
    }

    #[test]
    fn an_alias_label_keeps_the_real_name() {
        let item =
            json!({ "label": "Vec(alias list, vector)", "kind": 22, "detail": "Vec<{unknown}>" });
        let parsed = parse(&item, Dialect::Rust).expect("parsed");
        assert_eq!(parsed.hit.name, "Vec");
        assert_eq!(parsed.hit.signature, "");
    }
}
