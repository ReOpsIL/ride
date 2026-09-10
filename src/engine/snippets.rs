use crate::ffi::{CompletionHit, ItemKind};
use crate::highlight::{Lang, Position, Site, SiteAt};
use crate::params;

const RUST: &[(&str, &[&str])] = &[
    ("fn", &["fn ${1:name}($2) {", "    $0", "}"]),
    ("impl", &["impl ${1:Type} {", "    $0", "}"]),
    ("struct", &["struct ${1:Name} {", "    $0", "}"]),
    ("enum", &["enum ${1:Name} {", "    $0", "}"]),
    ("trait", &["trait ${1:Name} {", "    $0", "}"]),
    ("match", &["match ${1:expr} {", "    $0", "}"]),
    ("for", &["for ${1:item} in ${2:iter} {", "    $0", "}"]),
    ("while", &["while ${1:cond} {", "    $0", "}"]),
    ("loop", &["loop {", "    $0", "}"]),
    ("if", &["if ${1:cond} {", "    $0", "}"]),
    ("mod", &["mod ${1:name} {", "    $0", "}"]),
    ("let", &["let ${1:name} = $0;"]),
];

const C: &[(&str, &[&str])] = &[
    (
        "for",
        &[
            "for (${1:int i = 0}; ${2:i < n}; ${3:i++}) {",
            "    $0",
            "}",
        ],
    ),
    ("while", &["while (${1:cond}) {", "    $0", "}"]),
    ("if", &["if (${1:cond}) {", "    $0", "}"]),
    ("do", &["do {", "    $0", "} while (${1:cond});"]),
    ("struct", &["struct ${1:name} {", "    $0", "};"]),
    (
        "switch",
        &[
            "switch (${1:value}) {",
            "case ${2:0}:",
            "    $0",
            "    break;",
            "default:",
            "    break;",
            "}",
        ],
    ),
];

const CPP: &[(&str, &[&str])] = &[
    ("class", &["class ${1:Name} {", "public:", "    $0", "};"]),
    ("namespace", &["namespace ${1:name} {", "$0", "}"]),
];

pub fn calls(hits: &mut [CompletionHit], site: &SiteAt) {
    if site.next_char == Some('(') || matches!(site.site, Site::Identifier(Position::Type)) {
        return;
    }
    for hit in hits.iter_mut().filter(|h| !h.snippet) {
        match hit.item_kind {
            ItemKind::Fn | ItemKind::Method => {
                if let Some(parsed) = params::parse(&hit.signature, &hit.name) {
                    let names = params::names(&hit.signature, &parsed);
                    let args: Vec<String> = names
                        .iter()
                        .enumerate()
                        .map(|(i, n)| format!("${{{}:{}}}", i + 1, n))
                        .collect();
                    hit.insert_text = format!("{}({})$0", hit.name, args.join(", "));
                    hit.snippet = true;
                }
            }
            ItemKind::Macro if !hit.name.is_empty() => {
                hit.insert_text = format!("{}!($0)", hit.name);
                hit.snippet = true;
            }
            _ => {}
        }
    }
}

pub fn keywords(hits: &mut [CompletionHit], site: &SiteAt, lang: Lang) {
    if !matches!(
        site.site,
        Site::Identifier(Position::Value | Position::Unknown)
    ) {
        return;
    }
    let tables: &[&[(&str, &[&str])]] = match lang {
        Lang::Rust => &[RUST],
        Lang::C => &[C],
        Lang::Cpp => &[C, CPP],
        _ => &[],
    };
    for hit in hits.iter_mut().filter(|h| h.item_kind == ItemKind::Keyword) {
        let Some((_, lines)) = tables
            .iter()
            .flat_map(|t| t.iter())
            .find(|(k, _)| *k == hit.name)
        else {
            continue;
        };
        hit.insert_text = render(lines, &site.line_indent);
        hit.snippet = true;
        hit.detail = "snippet".into();
    }
}

pub fn render(lines: &[&str], indent: &str) -> String {
    lines
        .iter()
        .enumerate()
        .map(|(i, l)| {
            if i == 0 {
                (*l).to_string()
            } else {
                format!("{indent}{l}")
            }
        })
        .collect::<Vec<_>>()
        .join("\n")
}
