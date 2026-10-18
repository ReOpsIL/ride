use std::path::{Path, PathBuf};

use crate::abspath::{absolute, absolute_string};
use crate::ffi::DiagnosticLabel;

use super::message::Span;

struct Site {
    file_name: String,
    byte_start: u32,
    byte_end: u32,
    line_start: u32,
    line_end: u32,
    column_start: u32,
    column_end: u32,
}

struct Placed {
    label: DiagnosticLabel,
    column_end: u32,
}

pub(super) fn primary(root: &Path, span: &Span) -> DiagnosticLabel {
    place(root, span).label
}

pub(super) fn secondary(root: &Path, spans: &[Span], primary_path: &str) -> Vec<DiagnosticLabel> {
    ranked(
        root,
        spans.iter().filter(|span| !span.is_primary),
        primary_path,
    )
}

pub(super) fn labelled(root: &Path, spans: &[Span], primary_path: &str) -> Vec<DiagnosticLabel> {
    ranked(
        root,
        spans.iter().filter(|span| span.label.is_some()),
        primary_path,
    )
}

fn ranked<'a>(
    root: &Path,
    spans: impl Iterator<Item = &'a Span>,
    primary_path: &str,
) -> Vec<DiagnosticLabel> {
    let mut placed: Vec<Placed> = spans.map(|span| place(root, span)).collect();
    placed.sort_by(|left, right| {
        rank(&left.label.path, primary_path)
            .cmp(&rank(&right.label.path, primary_path))
            .then_with(|| left.label.path.cmp(&right.label.path))
            .then_with(|| left.label.byte_start.cmp(&right.label.byte_start))
            .then_with(|| left.label.column.cmp(&right.label.column))
            .then_with(|| left.column_end.cmp(&right.column_end))
    });
    placed.into_iter().map(|item| item.label).collect()
}

fn rank(path: &str, primary_path: &str) -> u8 {
    u8::from(path != primary_path)
}

fn place(root: &Path, span: &Span) -> Placed {
    let (site, macro_name) = call_site(root, span);
    Placed {
        column_end: site.column_end,
        label: DiagnosticLabel {
            path: absolute_string(root, &site.file_name),
            byte_start: site.byte_start,
            byte_end: site.byte_end.max(site.byte_start),
            line_start: site.line_start,
            line_end: site.line_end,
            column: site.column_start,
            text: span.label.clone(),
            macro_name,
        },
    }
}

fn call_site(root: &Path, span: &Span) -> (Site, Option<String>) {
    let mut cursor = span;
    let mut via: Option<String> = None;
    let mut chosen: Option<(Site, Option<String>)> = None;
    loop {
        if in_workspace(root, &cursor.file_name) {
            chosen = Some((site_of(cursor), via.clone()));
        }
        let Some(expansion) = cursor.expansion.as_deref() else {
            break;
        };
        via = Some(expansion.macro_decl_name.clone());
        cursor = &expansion.span;
    }
    match chosen {
        Some((site, name)) => (site, name.as_deref().map(declared)),
        None => (site_of(span), None),
    }
}

fn declared(name: &str) -> String {
    if name.starts_with("#[") {
        name.to_string()
    } else {
        format!("{}!", name.trim_end_matches('!'))
    }
}

fn in_workspace(root: &Path, file: &str) -> bool {
    if root.as_os_str().is_empty() {
        return false;
    }
    PathBuf::from(absolute_string(root, file)).starts_with(absolute(Path::new(""), root))
}

fn site_of(span: &Span) -> Site {
    Site {
        file_name: span.file_name.clone(),
        byte_start: span.byte_start,
        byte_end: span.byte_end,
        line_start: span.line_start,
        line_end: span.line_end,
        column_start: span.column_start,
        column_end: span.column_end,
    }
}
