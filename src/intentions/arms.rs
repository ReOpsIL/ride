use tree_sitter::Node;

use crate::ffi::{ItemKind, TextEdit};
use crate::highlight::Member;
use crate::highlight::symbol::node_text;

use super::scrutinee::{enclosing_indent, scrutinee_type};

pub struct MatchSite {
    pub type_name: String,
    pub covered: Vec<String>,
    pub insert_byte: u32,
    pub lead: String,
    pub indent: String,
}

pub fn match_site(root: Node<'_>, text: &str, byte: u32) -> Option<MatchSite> {
    let node = enclosing_match(root, byte as usize)?;
    let body = node.child_by_field_name("body")?;
    let arms = arm_nodes(body);
    let covered = covered_variants(&arms, text)?;
    let type_name = scrutinee_type(node, text)?;
    let (insert_byte, lead, indent) = anchor(body, &arms, text)?;
    Some(MatchSite {
        type_name,
        covered,
        insert_byte,
        lead,
        indent,
    })
}

pub fn arm_text(site: &MatchSite, members: &[Member], text: &str) -> Option<TextEdit> {
    let mut seen: Vec<String> = site.covered.clone();
    let mut missing: Vec<String> = Vec::new();
    for member in members.iter().filter(|m| m.item.kind == ItemKind::Variant) {
        if seen.contains(&member.item.name) {
            continue;
        }
        seen.push(member.item.name.clone());
        missing.push(arm(&site.type_name, member, text));
    }
    if missing.is_empty() {
        return None;
    }
    let body: String = missing
        .iter()
        .map(|entry| format!("\n{}{entry}", site.indent))
        .collect();
    let inserted = format!("{}{body}", site.lead);
    Some(TextEdit {
        start_byte: site.insert_byte,
        end_byte: site.insert_byte,
        text: inserted.clone(),
        caret_byte: site.insert_byte + inserted.len() as u32,
    })
}

fn arm(type_name: &str, member: &Member, text: &str) -> String {
    let from = member.item.name_start_byte as usize + member.item.name.len();
    let rest = text
        .get(from..member.item.end_byte as usize)
        .unwrap_or_default()
        .trim_start();
    let shape = if rest.starts_with('(') {
        "(..)"
    } else if rest.starts_with('{') {
        " { .. }"
    } else {
        ""
    };
    format!("{type_name}::{}{shape} => todo!(),", member.item.name)
}

fn enclosing_match<'a>(root: Node<'a>, byte: usize) -> Option<Node<'a>> {
    let mut node = root.descendant_for_byte_range(byte, byte);
    while let Some(current) = node {
        if current.kind() == "match_expression" {
            return Some(current);
        }
        node = current.parent();
    }
    None
}

fn arm_nodes(body: Node<'_>) -> Vec<Node<'_>> {
    let mut cursor = body.walk();
    body.named_children(&mut cursor)
        .filter(|child| child.kind() == "match_arm")
        .collect()
}

fn covered_variants(arms: &[Node<'_>], text: &str) -> Option<Vec<String>> {
    let mut out = Vec::new();
    for node in arms {
        let pattern = node.child_by_field_name("pattern")?;
        collect(pattern, text, &mut out)?;
    }
    Some(out)
}

fn collect(node: Node<'_>, text: &str, out: &mut Vec<String>) -> Option<()> {
    match node.kind() {
        "match_pattern" | "or_pattern" => {
            let mut cursor = node.walk();
            let children: Vec<Node<'_>> = node.named_children(&mut cursor).collect();
            if children.is_empty() {
                return None;
            }
            for child in children {
                collect(child, text, out)?;
            }
            Some(())
        }
        "scoped_identifier" => {
            out.push(last_segment(&node_text(node, text))?);
            Some(())
        }
        "tuple_struct_pattern" | "struct_pattern" => {
            let name = node.child_by_field_name("type")?;
            out.push(last_segment(&node_text(name, text))?);
            Some(())
        }
        _ => None,
    }
}

fn last_segment(path: &str) -> Option<String> {
    let name = path.trim().rsplit("::").next()?.trim();
    (!name.is_empty()).then(|| name.to_string())
}

fn anchor(body: Node<'_>, arms: &[Node<'_>], text: &str) -> Option<(u32, String, String)> {
    let open = body.child(0)?;
    let close = body.child(body.child_count().checked_sub(1)?)?;
    let Some(last) = arms.last() else {
        let indent = format!("{}    ", enclosing_indent(text, close.start_byte()));
        return Some((open.end_byte() as u32, String::new(), indent));
    };
    let indent = enclosing_indent(text, arms.first()?.start_byte());
    let mut at = last.end_byte();
    while text
        .as_bytes()
        .get(at)
        .is_some_and(|b| *b == b' ' || *b == b'\t')
    {
        at += 1;
    }
    let lead = if text.as_bytes().get(at) == Some(&b',') {
        at += 1;
        String::new()
    } else {
        at = last.end_byte();
        ",".to_string()
    };
    Some((at as u32, lead, indent))
}
