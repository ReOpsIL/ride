use std::collections::HashMap;
use std::path::Path;
use std::sync::OnceLock;

use tree_sitter::Node;

use crate::highlight::Lang;

use super::doc_block;

#[derive(Clone)]
pub struct PrimDoc {
    pub markdown: String,
    pub path: String,
    pub line: u32,
}

pub fn lift(name: &str) -> Option<PrimDoc> {
    table().and_then(|rows| rows.get(name).cloned())
}

fn table() -> Option<&'static HashMap<String, PrimDoc>> {
    static ROWS: OnceLock<Option<HashMap<String, PrimDoc>>> = OnceLock::new();
    ROWS.get_or_init(load).as_ref()
}

fn load() -> Option<HashMap<String, PrimDoc>> {
    let sysroot = crate::discover::rustc_sysroot().ok().flatten()?;
    let path = sysroot.join("lib/rustlib/src/rust/library/core/src/primitive_docs.rs");
    let text = std::fs::read_to_string(&path).ok()?;
    let tree = doc_block::parse(Lang::Rust, &text)?;
    let mut rows = HashMap::new();
    collect(tree.root_node(), &text, &path, &mut rows);
    Some(rows)
}

fn collect(node: Node<'_>, text: &str, path: &Path, rows: &mut HashMap<String, PrimDoc>) {
    if node.kind() == "mod_item"
        && let Some(name) = primitive_name(node, text)
        && let Some(markdown) = doc_block::markdown_of(Lang::Rust, node, text)
        && !markdown.trim().is_empty()
    {
        rows.insert(
            name,
            PrimDoc {
                markdown,
                path: path.display().to_string(),
                line: doc_block::line_at(text, node.start_byte()),
            },
        );
    }
    let mut walk = node.walk();
    if walk.goto_first_child() {
        loop {
            collect(walk.node(), text, path, rows);
            if !walk.goto_next_sibling() {
                break;
            }
        }
    }
}

fn primitive_name(node: Node<'_>, text: &str) -> Option<String> {
    let mut sib = node.prev_named_sibling();
    while let Some(s) = sib {
        match s.kind() {
            "attribute_item" => {
                if let Some(name) = attr_value(&node_text(s, text), "rustc_doc_primitive") {
                    return Some(name);
                }
            }
            "line_comment" | "block_comment" => {}
            _ => break,
        }
        sib = s.prev_named_sibling();
    }
    None
}

fn attr_value(text: &str, key: &str) -> Option<String> {
    let rest = text.get(text.find(key)? + key.len()..)?.trim_start();
    let rest = rest.strip_prefix('=')?.trim_start();
    let quote = rest.chars().next()?;
    if quote != '"' {
        return None;
    }
    rest[quote.len_utf8()..]
        .split(quote)
        .next()
        .filter(|body| !body.is_empty())
        .map(str::to_string)
}

fn node_text(node: Node<'_>, text: &str) -> String {
    text.get(node.start_byte()..node.end_byte().min(text.len()))
        .unwrap_or("")
        .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_toolchain_primitive_docs_name_i32_and_str() {
        let Some(rows) = table() else {
            return;
        };
        let i32 = rows.get("i32").expect("i32");
        assert!(
            i32.markdown.contains("32-bit signed integer"),
            "{}",
            i32.markdown
        );
        let str_docs = rows.get("str").expect("str");
        assert!(
            str_docs.markdown.contains("String slices"),
            "{}",
            str_docs.markdown
        );
    }
}
