use std::panic::{AssertUnwindSafe, catch_unwind};

use crate::cheatsheet::{self, Selected};
use crate::ffi::{CheatEntry, CheatSection, CheatSheetResponse};
use crate::highlight::{Context, Site, SiteAt};

use super::Engine;
use super::snippets::render;

#[uniffi::export]
impl Engine {
    pub fn cheat_sheet(&self, session_id: u64, cursor_byte: u32, all: bool) -> CheatSheetResponse {
        catch_unwind(AssertUnwindSafe(|| {
            lookup(self, session_id, cursor_byte, all)
        }))
        .unwrap_or_else(|_| CheatSheetResponse::empty(cursor_byte))
    }
}

fn lookup(engine: &Engine, session_id: u64, cursor_byte: u32, all: bool) -> CheatSheetResponse {
    let Some((sheet, site, ctx)) = engine
        .read(|i| {
            let session = i.sessions.get(&session_id)?;
            let site = session.site_at(cursor_byte);
            let ctx = context_for(&site, session.context_at(cursor_byte));
            Some((cheatsheet::sheet(session.lang()), site, ctx))
        })
        .ok()
        .flatten()
    else {
        return CheatSheetResponse::empty(cursor_byte);
    };
    let (Some(sheet), Some(ctx)) = (sheet, ctx) else {
        return CheatSheetResponse::empty(cursor_byte);
    };
    let member = matches!(site.site, Site::MemberAccess);
    let sections = cheatsheet::select(sheet, ctx, &site.prefix, all)
        .iter()
        .map(|s| section(s, &site.line_indent, member))
        .collect();
    CheatSheetResponse {
        sections,
        replace_start_byte: site.replace_start as u32,
        prefix: site.prefix.clone(),
        context: ctx.name().into(),
    }
}

fn context_for(site: &SiteAt, detected: Context) -> Option<Context> {
    match site.site {
        Site::None => None,
        Site::Attribute { .. } => Some(Context::Attribute),
        Site::Include { .. } | Site::Directive => Some(Context::Preprocessor),
        Site::UsePath(_) => Some(Context::Use),
        Site::MemberAccess | Site::ScopedPath(_) | Site::StructLiteral(_) => {
            Some(Context::Expression)
        }
        Site::Identifier(_) => Some(detected),
    }
}

fn section(selected: &Selected<'_>, indent: &str, member: bool) -> CheatSection {
    CheatSection {
        title: selected.section.title.clone(),
        matched: selected.matched,
        entries: selected
            .entries
            .iter()
            .map(|e| {
                let mut lines: Vec<&str> = e.lines.iter().map(String::as_str).collect();
                if member && let Some(first) = lines.first_mut() {
                    *first = without_receiver(first);
                }
                CheatEntry {
                    name: e.name.clone(),
                    doc: e.doc.clone(),
                    snippet: render(&lines, indent),
                }
            })
            .collect(),
    }
}

fn without_receiver(line: &str) -> &str {
    let Some(rest) = line.strip_prefix("${") else {
        return line;
    };
    let Some(close) = rest.find('}') else {
        return line;
    };
    let after = &rest[close + 1..];
    after
        .strip_prefix("->")
        .or_else(|| after.strip_prefix('.'))
        .filter(|tail| {
            tail.chars()
                .next()
                .is_some_and(|c| c.is_alphanumeric() || c == '_')
        })
        .unwrap_or(line)
}
