use crate::highlight::{Lang, Leaf, parse_source};

use super::identity::{self, ParsedItem};
use super::model::{CallSite, Change, FileInput, Row, skipped};
use super::pair;
use super::rows;
use super::shape::{self, digests};

const LIMIT: usize = 1_000_000;

pub(crate) struct Classified {
    pub rows: Vec<Row>,
    pub shapes: Vec<String>,
    pub calls: Vec<CallSite>,
    pub defs: Vec<String>,
    pub items: Vec<ParsedItem>,
}

pub(crate) fn classify(file: &FileInput) -> Classified {
    if skipped(&file.path) {
        return empty();
    }
    if file.binary || too_big(file) || !code_lang(&file.path) {
        return file_row(file);
    }
    let old = side(&file.path, file.old_text.as_deref());
    let new = side(&file.path, file.new_text.as_deref());
    if old.items.is_empty() && new.items.is_empty() {
        return empty_outline(file, &old, &new);
    }
    let calls = file
        .new_text
        .as_deref()
        .map(|text| calls_of(&file.path, text, &new.leaves))
        .unwrap_or_default();
    let mut paired = pair::pair(file, old.items, new.items);
    if import_only(&paired.rows) && old.imports != new.imports {
        paired
            .rows
            .push(rows::light(&file.path, "import", "(imports)", "import"));
    }
    Classified {
        rows: paired.rows,
        shapes: paired.shapes,
        calls,
        defs: paired.defs,
        items: paired.items,
    }
}

struct Side {
    items: Vec<ParsedItem>,
    leaves: Vec<Leaf>,
    imports: String,
}

fn side(path: &str, text: Option<&str>) -> Side {
    let Some(text) = text else {
        return Side {
            items: Vec::new(),
            leaves: Vec::new(),
            imports: String::new(),
        };
    };
    let Some(lang) = Lang::recognized(Some(path)) else {
        return Side {
            items: Vec::new(),
            leaves: Vec::new(),
            imports: String::new(),
        };
    };
    let Ok(parsed) = parse_source(lang, text) else {
        return Side {
            items: Vec::new(),
            leaves: Vec::new(),
            imports: String::new(),
        };
    };
    let items = identity::parse_items(path, lang, text, &parsed.outline, &parsed.leaves);
    let imports = import_key(&parsed.leaves);
    Side {
        items,
        leaves: parsed.leaves,
        imports,
    }
}

fn empty_outline(file: &FileInput, old: &Side, new: &Side) -> Classified {
    if old.imports != new.imports {
        return Classified {
            rows: vec![rows::light(&file.path, "import", "(imports)", "import")],
            ..empty()
        };
    }
    let lang = Lang::recognized(Some(&file.path)).unwrap_or(Lang::Rust);
    let old_code = digests(lang, &old.leaves, 0, u32::MAX).code;
    let new_code = digests(lang, &new.leaves, 0, u32::MAX).code;
    if old_code != new_code {
        return file_row(file);
    }
    empty()
}

fn import_only(rows: &[Row]) -> bool {
    !rows.iter().any(|row| row.detail.is_empty())
}

fn import_key(leaves: &[Leaf]) -> String {
    leaves
        .iter()
        .filter(|leaf| leaf.import)
        .map(|leaf| leaf.text.as_str())
        .collect::<Vec<_>>()
        .join("\0")
}

fn calls_of(path: &str, text: &str, leaves: &[Leaf]) -> Vec<CallSite> {
    let kept: Vec<&Leaf> = leaves.iter().collect();
    let mut out = Vec::new();
    for pair in kept.windows(2) {
        if shape::is_ident(&pair[0].kind) && pair[1].text == "(" {
            let (line, _) = identity::line_span(text, pair[0].start, pair[0].end);
            out.push(CallSite {
                name: pair[0].text.clone(),
                path: path.to_string(),
                line,
            });
        }
    }
    out
}

fn file_row(file: &FileInput) -> Classified {
    if file.old_text.is_none() && file.new_text.is_none() && !file.binary {
        return empty();
    }
    Classified {
        rows: vec![rows::plain(
            &file.path,
            file_name(&file.path),
            "file",
            Change::File,
            "",
        )],
        ..empty()
    }
}

fn code_lang(path: &str) -> bool {
    matches!(
        Lang::recognized(Some(path)),
        Some(Lang::Rust | Lang::C | Lang::Cpp)
    )
}

fn too_big(file: &FileInput) -> bool {
    file.old_text
        .as_ref()
        .is_some_and(|text| text.len() > LIMIT)
        || file
            .new_text
            .as_ref()
            .is_some_and(|text| text.len() > LIMIT)
}

fn file_name(path: &str) -> &str {
    path.rsplit('/').next().unwrap_or(path)
}

fn empty() -> Classified {
    Classified {
        rows: Vec::new(),
        shapes: Vec::new(),
        calls: Vec::new(),
        defs: Vec::new(),
        items: Vec::new(),
    }
}
