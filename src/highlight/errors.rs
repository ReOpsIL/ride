use tree_sitter::Node;

use crate::ffi::ParseErrorSpan;

pub fn collect(root: Node<'_>) -> Vec<ParseErrorSpan> {
    let mut out = Vec::new();
    if root.has_error() {
        walk(root, &mut out);
    }
    out
}

fn walk(node: Node<'_>, out: &mut Vec<ParseErrorSpan>) {
    if node.is_error() || node.is_missing() {
        push(node, out);
        return;
    }
    let mut cursor = node.walk();
    if !cursor.goto_first_child() {
        return;
    }
    loop {
        walk(cursor.node(), out);
        if !cursor.goto_next_sibling() {
            break;
        }
    }
}

fn push(node: Node<'_>, out: &mut Vec<ParseErrorSpan>) {
    let start = node.start_byte();
    let end = first_line_end(node);
    if end > start || node.is_missing() {
        out.push(ParseErrorSpan {
            start_byte: start as u32,
            end_byte: end as u32,
        });
    }
}

fn first_line_end(node: Node<'_>) -> usize {
    let row = node.start_position().row;
    if node.end_position().row == row {
        return node.end_byte();
    }
    let end = last_byte_on(node, row);
    if end > node.start_byte() {
        end
    } else {
        node.start_byte().saturating_add(1).min(node.end_byte())
    }
}

fn last_byte_on(node: Node<'_>, row: usize) -> usize {
    if node.start_position().row > row {
        return node.start_byte();
    }
    if node.end_position().row == row {
        return node.end_byte();
    }
    let mut cursor = node.walk();
    if !cursor.goto_first_child() {
        return node.start_byte();
    }
    let mut end = node.start_byte();
    loop {
        let child = cursor.node();
        if child.start_position().row > row {
            break;
        }
        end = last_byte_on(child, row);
        if child.end_position().row > row || !cursor.goto_next_sibling() {
            break;
        }
    }
    end
}
