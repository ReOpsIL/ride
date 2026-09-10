use std::collections::HashSet;
use std::path::PathBuf;

use crate::ffi::{Diagnostic, DiagnosticLevel};

use super::offsets::LineOffsets;

const LEVELS: &[(&str, DiagnosticLevel)] = &[
    (": fatal error: ", DiagnosticLevel::Error),
    (": error: ", DiagnosticLevel::Error),
    (": warning: ", DiagnosticLevel::Warning),
    (": note: ", DiagnosticLevel::Note),
];

struct Location {
    path: PathBuf,
    line: u32,
    column: u32,
    end: Option<(u32, u32)>,
}

pub fn parse_clang(text: &str) -> Vec<Diagnostic> {
    let mut offsets = LineOffsets::default();
    let mut seen = HashSet::new();
    text.lines()
        .filter_map(|line| parse_line(line, &mut offsets))
        .filter(|d| seen.insert((d.path.clone(), d.byte_start, d.message.clone())))
        .collect()
}

fn parse_line(line: &str, offsets: &mut LineOffsets) -> Option<Diagnostic> {
    let (at, marker, level) = LEVELS
        .iter()
        .filter_map(|(m, l)| line.find(m).map(|i| (i, *m, *l)))
        .min_by_key(|(i, _, _)| *i)?;
    let loc = location(&line[..at])?;
    let (message, code) = split_code(&line[at + marker.len()..]);
    let byte_start = offsets.byte_at(&loc.path, loc.line, loc.column);
    let byte_end = loc
        .end
        .map(|(l, c)| offsets.byte_at(&loc.path, l, c))
        .unwrap_or(byte_start)
        .max(byte_start);
    Some(Diagnostic {
        path: loc.path.display().to_string(),
        byte_start,
        byte_end,
        line: loc.line,
        column: loc.column,
        level,
        message: message.to_string(),
        code,
    })
}

fn location(loc: &str) -> Option<Location> {
    let (head, ranges) = match loc.find('{') {
        Some(i) => (&loc[..i], Some(&loc[i..])),
        None => (loc, None),
    };
    let head = head.strip_suffix(':').unwrap_or(head);
    let (rest, column) = head.rsplit_once(':')?;
    let (path, line) = rest.rsplit_once(':')?;
    Some(Location {
        path: PathBuf::from(path),
        line: line.parse().ok()?,
        column: column.parse().ok()?,
        end: ranges.and_then(first_range_end),
    })
}

fn first_range_end(ranges: &str) -> Option<(u32, u32)> {
    let inner = ranges.strip_prefix('{')?.split('}').next()?;
    let (_, end) = inner.split_once('-')?;
    let (line, column) = end.split_once(':')?;
    Some((line.parse().ok()?, column.parse().ok()?))
}

fn split_code(message: &str) -> (&str, Option<String>) {
    match message.rsplit_once(" [") {
        Some((text, rest)) if rest.starts_with('-') && rest.ends_with(']') => {
            (text, Some(rest[..rest.len() - 1].to_string()))
        }
        _ => (message, None),
    }
}
