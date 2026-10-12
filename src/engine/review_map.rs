use std::path::{Path, PathBuf};

use crate::error::EngineError;
use crate::ffi::{ReviewDossier, ReviewHunt, ReviewInbox, ReviewMarkLine, ReviewRow};
use crate::review::{self, Inbox, Row};

use super::Engine;

pub(super) fn inbox_view(inbox: Inbox) -> ReviewInbox {
    let counts = inbox.counts;
    ReviewInbox {
        base: inbox.base,
        head: inbox.head,
        upstream: inbox.upstream,
        order: inbox.order,
        grouped: inbox.grouped,
        needs_eyes: counts.needs_eyes,
        verified: counts.verified,
        suspect: counts.suspect,
        question: counts.question,
        unchecked: counts.unchecked,
        equivalent: counts.equivalent,
        light: counts.light,
        behaviour: counts.behaviour,
        docs: counts.docs,
        imports: counts.imports,
        tests: counts.tests,
        formatting: counts.formatting,
        moved: counts.moved,
        rows: inbox.rows.into_iter().map(row_view).collect(),
    }
}

fn row_view(row: Row) -> ReviewRow {
    ReviewRow {
        path: row.path,
        old_path: row.old_path,
        item: row.item,
        name: row.name,
        kind: row.kind,
        change: row.change.label().to_string(),
        group: row.group.label().to_string(),
        checks: row.checks,
        shape: row.shape,
        start_byte: row.start_byte,
        end_byte: row.end_byte,
        line: row.line,
        signature: row.signature,
        doc: row.doc,
        module: row.module,
        callers: row.callers,
        detail: row.detail,
        mark: row.mark,
        mark_author: row.mark_author,
        mark_state: row.mark_state,
        mark_note: row.mark_note,
        mark_id: row.mark_id,
    }
}

pub(super) fn dossier_view(dossier: review::Dossier) -> ReviewDossier {
    ReviewDossier {
        signature: dossier.signature,
        doc: dossier.doc,
        line: dossier.line,
        change: dossier.change,
        checks: dossier.checks,
        callers: dossier.callers,
        callees: dossier.callees,
        claims: dossier.claims,
        marks: dossier.marks.into_iter().map(mark_line).collect(),
        since: dossier.since,
        note: dossier.note,
    }
}

fn mark_line(line: review::MarkLine) -> ReviewMarkLine {
    ReviewMarkLine {
        id: line.id,
        text: line.text,
        own: line.own,
    }
}

pub(super) fn hunt(engine: &Engine, root: &str) -> Result<Vec<ReviewHunt>, EngineError> {
    let git = crate::git::require(Path::new(root))?;
    let events = crate::trail::read(&trail_dir(engine)?, root);
    let Some(failed) = events
        .iter()
        .rev()
        .find(|event| event.kind == "test" && !event.passed)
    else {
        return Ok(Vec::new());
    };
    let green = events
        .iter()
        .rev()
        .find(|event| event.kind == "test" && event.name == failed.name && event.passed);
    let label = green
        .map(|event| format!("on this Mac · {}", short(&event.commit)))
        .unwrap_or_else(|| "merge-base".to_string());
    let (inbox, _, _) = match green {
        Some(event) if !event.commit.is_empty() => review::load_at(&git, Some(&event.commit))?,
        _ => review::load_repo(git.dir())?,
    };
    let calls = review::test_calls(&git, &failed.name);
    let failing = format!("{} {}", failed.name, failed.note);
    Ok(review::hunt(&calls, &inbox.rows, &[])
        .into_iter()
        .map(|hit| ReviewHunt {
            path: hit.path,
            item: hit.item,
            name: hit.name,
            checks: hit.checks,
            on_stack: hit.on_stack,
            open_mark: hit.open_mark,
            failing: failing.clone(),
            base_label: label.clone(),
        })
        .collect())
}

pub(super) fn failing_line(engine: &Engine, root: &str) -> Option<String> {
    let events = crate::trail::read(&trail_dir(engine).ok()?, root);
    events
        .iter()
        .rev()
        .find(|event| event.kind == "test" && !event.passed)
        .map(|event| format!("{}: {}", event.name, event.note))
}

pub(super) fn trail_dir(engine: &Engine) -> Result<PathBuf, EngineError> {
    engine.read(|inner| {
        Path::new(&inner.config.index_dir)
            .parent()
            .map(|parent| parent.join("trail"))
            .unwrap_or_else(|| Path::new(&inner.config.index_dir).join("trail"))
    })
}

fn short(hash: &str) -> &str {
    hash.get(..7).unwrap_or(hash)
}
