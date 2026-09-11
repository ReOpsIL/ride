use tree_sitter::{Node, Parser, Tree};

use crate::highlight::Lang;

use super::doc_comment;
use super::doxygen;

pub struct Lifted {
    pub markdown: String,
    pub start_byte: usize,
}

const ITEMS: &[&str] = &[
    "function_item",
    "function_signature_item",
    "struct_item",
    "enum_item",
    "enum_variant",
    "union_item",
    "trait_item",
    "const_item",
    "static_item",
    "type_item",
    "associated_type",
    "mod_item",
    "macro_definition",
    "function_definition",
    "declaration",
    "field_declaration",
    "struct_specifier",
    "class_specifier",
    "union_specifier",
    "enum_specifier",
    "type_definition",
    "alias_declaration",
    "concept_definition",
    "namespace_definition",
    "preproc_def",
    "preproc_function_def",
];

pub fn lift(lang: Lang, source: &str, byte: usize) -> Option<Lifted> {
    if source.is_empty() {
        return None;
    }
    let tree = parse(lang, source)?;
    let last = source.len().saturating_sub(1);
    let node = item_at(tree.root_node(), byte.min(last))?;
    let markdown = markdown(lang, node, source)?;
    Some(Lifted {
        markdown,
        start_byte: node.start_byte(),
    })
}

pub fn line_at(text: &str, byte: usize) -> u32 {
    if text.is_empty() {
        return 0;
    }
    let byte = byte.min(text.len());
    text.get(..byte)
        .map(|s| s.bytes().filter(|&b| b == b'\n').count() as u32 + 1)
        .unwrap_or(0)
}

fn markdown(lang: Lang, node: Node<'_>, source: &str) -> Option<String> {
    match lang {
        Lang::Rust => Some(fences(&doc_comment::rust(node, source))),
        Lang::C | Lang::Cpp => Some(doxygen::to_markdown(&doc_comment::c(node, source))),
        Lang::Markdown | Lang::Toml | Lang::Make | Lang::Cmake => None,
    }
}

pub(crate) fn item_range(lang: Lang, source: &str, byte: usize) -> Option<(usize, usize)> {
    if source.is_empty() {
        return None;
    }
    let tree = parse(lang, source)?;
    let last = source.len().saturating_sub(1);
    let node = item_at(tree.root_node(), byte.min(last))?;
    Some((node.start_byte(), node.end_byte().min(source.len())))
}

pub(crate) fn parse(lang: Lang, source: &str) -> Option<Tree> {
    let grammar = lang.grammar()?;
    let mut parser = Parser::new();
    parser.set_language(&grammar.language).ok()?;
    parser.parse(source, None)
}

pub(crate) fn item_at<'a>(root: Node<'a>, byte: usize) -> Option<Node<'a>> {
    let mut node = root.descendant_for_byte_range(byte, byte)?;
    loop {
        if ITEMS.contains(&node.kind()) {
            return Some(node);
        }
        node = node.parent()?;
    }
}

fn fences(md: &str) -> String {
    let mut out = String::new();
    let mut in_fence = false;
    for line in md.lines() {
        match fence_line(line, in_fence) {
            Some(rewritten) => {
                in_fence = !in_fence;
                out.push_str(&rewritten);
            }
            None => out.push_str(line),
        }
        out.push('\n');
    }
    out
}

fn fence_line(line: &str, in_fence: bool) -> Option<String> {
    let trimmed = line.trim_start();
    let indent = line.len() - trimmed.len();
    if indent > 3 {
        return None;
    }
    let info = trimmed.strip_prefix("```")?;
    if in_fence {
        return Some(line.to_string());
    }
    let mut s = line[..indent].to_string();
    s.push_str("```");
    s.push_str(rust_info(info));
    Some(s)
}

fn rust_info(info: &str) -> &str {
    let first = info.trim().split([',', ' ']).next().unwrap_or("");
    match first {
        "" | "ignore" | "should_panic" | "no_run" | "compile_fail" | "edition2015"
        | "edition2018" | "edition2021" | "edition2024" => "rust",
        _ => info.trim_end(),
    }
}
