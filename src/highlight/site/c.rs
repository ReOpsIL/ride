use tree_sitter::Tree;

use super::common::{
    PositionWords, head_before, in_open_comment, inside, is_word, path_segments, position,
    word_start,
};
use super::{Site, SiteAt};

const NO_COMPLETION: &[&str] = &[
    "comment",
    "string_literal",
    "char_literal",
    "raw_string_literal",
    "system_lib_string",
    "string_content",
    "escape_sequence",
    "concatenated_string",
];

const WORDS: PositionWords = PositionWords {
    types: &[
        "struct",
        "enum",
        "union",
        "class",
        "const",
        "static",
        "unsigned",
        "signed",
        "typename",
        "template",
        "new",
        "typedef",
        "extern",
        "inline",
        "volatile",
        "virtual",
        "constexpr",
    ],
    values: &[
        "return", "case", "sizeof", "if", "while", "for", "switch", "else", "do",
    ],
    type_symbols: &[],
    value_symbols: &[
        "=", "(", ",", "{", ";", "+", "-", "*", "/", "!", "==", "!=", "<=", ">=", "&&", "||", "[",
        "|", "?", ":",
    ],
    transparent: &[],
};

const INCLUDES: &[&str] = &["include", "import", "include_next"];

pub fn c(tree: Option<&Tree>, text: &str, at: usize) -> SiteAt {
    classify(tree, text, at, false)
}

pub fn cpp(tree: Option<&Tree>, text: &str, at: usize) -> SiteAt {
    classify(tree, text, at, true)
}

fn classify(tree: Option<&Tree>, text: &str, at: usize, cpp: bool) -> SiteAt {
    if let Some(site) = directive(text, at) {
        return site;
    }
    let start = word_start(text, at, &[]);
    let prefix = text[start..at].to_string();
    let probe = if prefix.is_empty() { at } else { start + 1 };
    if inside(tree, probe, NO_COMPLETION) || in_open_comment(text, start) {
        return SiteAt::none(at);
    }
    let head = head_before(text, start);
    let site = if head.ends_with("->") || (head.ends_with('.') && !head.ends_with("..")) {
        Site::MemberAccess
    } else if cpp && head.ends_with("::") {
        Site::ScopedPath(path_segments(head).0)
    } else {
        Site::Identifier(position(head, &WORDS))
    };
    SiteAt {
        site,
        prefix,
        replace_start: start,
    }
}

fn directive(text: &str, at: usize) -> Option<SiteAt> {
    let line_start = text[..at].rfind('\n').map(|i| i + 1).unwrap_or(0);
    let line = text[line_start..at].trim_start();
    let rest = line.strip_prefix('#')?;
    let rest = rest.trim_start();
    let word_start = at - rest.len();
    let word_end = rest
        .find(|c: char| !is_word(c))
        .map(|e| word_start + e)
        .unwrap_or(at);
    let word = &text[word_start..word_end];
    if word_end == at {
        return Some(SiteAt {
            site: Site::Directive,
            prefix: word.to_string(),
            replace_start: word_start,
        });
    }
    if !INCLUDES.contains(&word) {
        return None;
    }
    let after = text[word_end..at].trim_start();
    let (quoted, body) = if let Some(b) = after.strip_prefix('<') {
        (false, b)
    } else if let Some(b) = after.strip_prefix('"') {
        (true, b)
    } else {
        return None;
    };
    if body.contains(if quoted { '"' } else { '>' }) {
        return Some(SiteAt::none(at));
    }
    let split = body.rfind('/').map(|i| i + 1).unwrap_or(0);
    Some(SiteAt {
        site: Site::Include {
            quoted,
            dir: body[..split].to_string(),
        },
        prefix: body[split..].to_string(),
        replace_start: at - (body.len() - split),
    })
}
