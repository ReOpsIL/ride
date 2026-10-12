use std::fs;

use crate::follow::Mark;
use crate::git::{self, Git};
use crate::highlight::{Lang, parse_source};

use super::identity::{self, calls_in};
use super::model::Row;
use super::since;

#[derive(Debug, Clone, Default)]
pub struct Dossier {
    pub signature: String,
    pub doc: String,
    pub line: u32,
    pub change: String,
    pub checks: Vec<String>,
    pub callers: Vec<String>,
    pub callees: Vec<String>,
    pub claims: Vec<String>,
    pub marks: Vec<MarkLine>,
    pub since: Vec<String>,
    pub note: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MarkLine {
    pub id: String,
    pub text: String,
    pub own: bool,
}

pub fn build(git: &Git, row: &Row, marks: &[Mark], base: &str, author: &str) -> Dossier {
    let text = fs::read_to_string(git.dir().join(&row.path)).unwrap_or_default();
    let mut dossier = Dossier {
        signature: row.signature.clone(),
        doc: row.doc.clone(),
        line: row.line,
        change: row.change.label().to_string(),
        checks: row.checks.clone(),
        callers: callers(git, &row.name, &row.path, row.line),
        callees: callees(&row.path, &text, row.start_byte, row.end_byte, &row.name),
        claims: claims(git, base, &row.path, row.line),
        marks: listed_marks(marks, &row.path, &row.item, author),
        since: Vec::new(),
        note: note_line(marks, row),
    };
    if row.mark_state == "stale"
        && !row.mark_id.is_empty()
        && let Some(mark) = marks.iter().find(|mark| mark.id == row.mark_id)
    {
        dossier.since = since_lines(git, &mark.commit, &row.path, &row.item, &text);
    }
    dossier
}

pub fn item_text(path: &str, text: &str, item_key: &str) -> Option<String> {
    let lang = Lang::recognized(Some(path))
        .filter(|lang| matches!(lang, Lang::Rust | Lang::C | Lang::Cpp))?;
    let parsed = parse_source(lang, text).ok()?;
    let items = identity::parse_items(path, lang, text, &parsed.outline, &parsed.leaves);
    let item = items.into_iter().find(|item| item.item == item_key)?;
    text.get(item.start as usize..item.end as usize)
        .map(str::to_string)
}

fn callees(path: &str, text: &str, start: u32, end: u32, name: &str) -> Vec<String> {
    let Some(lang) = Lang::recognized(Some(path)) else {
        return Vec::new();
    };
    let Ok(parsed) = parse_source(lang, text) else {
        return Vec::new();
    };
    calls_in(&parsed.leaves, start, end, name)
}

fn callers(git: &Git, name: &str, path: &str, line: u32) -> Vec<String> {
    let pattern = format!("{name}(");
    let Ok(out) = git.run_accepting(
        &[
            "grep", "-n", "-I", "-F", "-e", &pattern, "--", "*.rs", "*.c", "*.h", "*.cpp", "*.cc",
            "*.hpp",
        ],
        &[0, 1],
    ) else {
        return Vec::new();
    };
    let mut found = Vec::new();
    for row in out.stdout.lines() {
        let Some((file, rest)) = row.split_once(':') else {
            continue;
        };
        let Some((line_no, _)) = rest.split_once(':') else {
            continue;
        };
        let Ok(number) = line_no.parse::<u32>() else {
            continue;
        };
        if file == path && number == line {
            continue;
        }
        found.push(format!("{file}:{number}"));
        if found.len() == 8 {
            break;
        }
    }
    found
}

fn claims(git: &Git, base: &str, path: &str, line: u32) -> Vec<String> {
    if line == 0 || base.is_empty() {
        return Vec::new();
    }
    let range = format!("-L{line},{line}:{path}");
    let spec = format!("{base}..HEAD");
    let Ok(out) = git.run(&["log", "--format=%s", &range, &spec]) else {
        return Vec::new();
    };
    out.stdout
        .lines()
        .take(5)
        .map(|line| format!("author's words · {line}"))
        .collect()
}

pub fn listed_marks(marks: &[Mark], path: &str, item: &str, author: &str) -> Vec<MarkLine> {
    marks
        .iter()
        .filter(|mark| mark.path == path && mark.item == item)
        .map(|mark| MarkLine {
            id: mark.id.clone(),
            text: mark_text(mark),
            own: !mark.id.is_empty() && mark.author == author,
        })
        .collect()
}

fn mark_text(mark: &Mark) -> String {
    let who = if mark.agent {
        "claim"
    } else {
        mark.mark.as_str()
    };
    format!("{who} · {} · {}", mark.author, mark.note)
}

fn note_line(marks: &[Mark], row: &Row) -> String {
    marks
        .iter()
        .find(|mark| {
            mark.mark == "note"
                && mark.path == row.path
                && mark.item == row.item
                && basis_matches(&mark.basis, &row.shape)
        })
        .map(|mark| mark.note.clone())
        .unwrap_or_else(|| "Missing".to_string())
}

fn since_lines(git: &Git, commit: &str, path: &str, item: &str, now: &str) -> Vec<String> {
    if commit.is_empty() {
        return Vec::new();
    }
    let Some(old) = git::blob_at(git, commit, path) else {
        return Vec::new();
    };
    let Some(old_item) = item_text(path, &old, item) else {
        return Vec::new();
    };
    let Some(new_item) = item_text(path, now, item) else {
        return Vec::new();
    };
    since::lines(&old_item, &new_item)
}

fn basis_matches(basis: &str, shape: &str) -> bool {
    !basis.is_empty() && (basis == shape || (basis.len() >= 8 && shape.starts_with(basis)))
}
