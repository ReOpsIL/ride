use std::path::{Path, PathBuf};

use crate::ffi::{CompletionHit, DefinitionResponse, ItemKind};
use crate::oracle::Target;
use crate::text::collapse_ws;

use super::Engine;
use super::oracle_ask::ask;

const SERVER_SCORE: f32 = 3000.0;
const SIGNATURE_SPAN: usize = 400;
const KINDS: &[(&str, ItemKind)] = &[
    ("struct", ItemKind::Struct),
    ("enum", ItemKind::Enum),
    ("trait", ItemKind::Trait),
    ("union", ItemKind::Union),
    ("class", ItemKind::Class),
    ("namespace", ItemKind::Namespace),
    ("mod", ItemKind::Mod),
    ("macro_rules!", ItemKind::Macro),
    ("#define", ItemKind::Macro),
    ("type", ItemKind::Type),
    ("typedef", ItemKind::Type),
    ("using", ItemKind::Type),
    ("const", ItemKind::Const),
    ("static", ItemKind::Static),
    ("let", ItemKind::Local),
];

pub fn definition(
    engine: &Engine,
    session_id: u64,
    cursor_byte: u32,
) -> Option<DefinitionResponse> {
    let (ask, symbol, declared_here) = engine
        .read(|i| {
            let session = i.sessions.get(&session_id)?;
            let symbol = session.symbol_at(cursor_byte)?;
            let declared_here = session
                .outline()
                .iter()
                .any(|o| o.name_start_byte == symbol.start_byte);
            Some((ask(i, session_id)?, symbol, declared_here))
        })
        .ok()
        .flatten()?;
    let own = ask.doc.path.clone();
    let site = symbol.start_byte as usize;
    let here = declared_here.then(|| Target {
        path: own.clone(),
        name_byte: site,
        text: ask.doc.text.clone(),
    });
    let mut targets = ask.oracle.definitions(ask.doc, &ask.stale, site);
    if targets.is_empty() {
        return None;
    }
    if let Some(here) = here.filter(|h| !targets.iter().any(|t| same(t, h))) {
        targets.push(here);
    }
    let hits = targets.iter().map(|t| hit(&symbol.name, t, &own)).collect();
    Some(DefinitionResponse {
        symbol: Some(symbol),
        hits,
    })
}

fn hit(name: &str, target: &Target, own: &Path) -> CompletionHit {
    let signature = signature_at(&target.text, target.name_byte);
    let mut hit = CompletionHit::local(name, kind_of(&signature, name), SERVER_SCORE, None);
    let byte = target.name_byte as u32;
    hit.byte_start = Some(byte);
    hit.name_byte = Some(byte);
    hit.source_path = (real(&target.path) != real(own)).then(|| target.path.display().to_string());
    hit.signature = signature;
    hit
}

fn signature_at(text: &str, name_byte: usize) -> String {
    let start = text[..name_byte.min(text.len())]
        .rfind('\n')
        .map_or(0, |i| i + 1);
    let mut end = (start + SIGNATURE_SPAN).min(text.len());
    while !text.is_char_boundary(end) {
        end -= 1;
    }
    let span = &text[start..end];
    let cut = span.find(['{', ';']).unwrap_or(span.len());
    collapse_ws(&span[..cut])
}

fn kind_of(signature: &str, name: &str) -> ItemKind {
    let head = signature.split(name).next().unwrap_or_default();
    let words: Vec<&str> = head
        .split(|c: char| c.is_whitespace() || c == '(')
        .collect();
    KINDS
        .iter()
        .find(|(word, _)| words.contains(word))
        .map_or(ItemKind::Fn, |(_, kind)| *kind)
}

fn same(a: &Target, b: &Target) -> bool {
    a.name_byte == b.name_byte && real(&a.path) == real(&b.path)
}

fn real(path: &Path) -> PathBuf {
    std::fs::canonicalize(path).unwrap_or_else(|_| path.to_path_buf())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_signature_stops_at_the_body() {
        let text =
            "/// doc\npub fn collect<B>(self) -> B\nwhere B: FromIterator {\n    todo!()\n}\n";
        let byte = text.find("collect").expect("name");
        assert_eq!(
            signature_at(text, byte),
            "pub fn collect<B>(self) -> B where B: FromIterator"
        );
    }

    #[test]
    fn the_declaration_keyword_picks_the_kind() {
        assert_eq!(kind_of("pub struct Counter", "Counter"), ItemKind::Struct);
        assert_eq!(
            kind_of("class Rect : public Shape", "Rect"),
            ItemKind::Class
        );
        assert_eq!(kind_of("bool is_square() const", "is_square"), ItemKind::Fn);
        assert_eq!(kind_of("let total = 1", "total"), ItemKind::Local);
    }
}
