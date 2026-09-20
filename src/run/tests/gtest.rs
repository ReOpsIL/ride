use crate::ffi::{TestEvent, TestStatus};

use super::event;

const RUN: &str = "[ RUN      ] ";
const OK: &str = "[       OK ] ";
const FAILED: &str = "[  FAILED  ] ";
const SKIPPED: &str = "[  SKIPPED ] ";

pub fn parse(text: &str) -> Vec<TestEvent> {
    let mut events = Vec::new();
    let mut running: Option<(String, Vec<&str>)> = None;
    for line in text.lines() {
        if let Some(full) = line.strip_prefix(RUN) {
            let full = full.trim();
            events.push(split_name(full, TestStatus::Started, None));
            running = Some((full.to_string(), Vec::new()));
            continue;
        }
        if let Some(e) = outcome(line, &mut running) {
            events.push(e);
            continue;
        }
        if let Some((_, output)) = running.as_mut() {
            output.push(line);
        }
    }
    events
}

fn outcome(line: &str, running: &mut Option<(String, Vec<&str>)>) -> Option<TestEvent> {
    let (rest, status) = if let Some(rest) = line.strip_prefix(OK) {
        (rest, TestStatus::Passed)
    } else if let Some(rest) = line.strip_prefix(FAILED) {
        (rest, TestStatus::Failed)
    } else if let Some(rest) = line.strip_prefix(SKIPPED) {
        (rest, TestStatus::Ignored)
    } else {
        return None;
    };
    let (full, duration_ms) = split_duration(rest.trim());
    let full = full.split_once(", where ").map_or(full, |(name, _)| name);
    let (name, output) = running.take()?;
    if name != full {
        *running = Some((name, output));
        return None;
    }
    let mut e = split_name(full, status, duration_ms);
    e.output = output.join("\n").trim().to_string();
    Some(e)
}

fn split_duration(rest: &str) -> (&str, Option<u64>) {
    let Some((head, tail)) = rest.rsplit_once(" (") else {
        return (rest, None);
    };
    let ms = tail
        .strip_suffix(')')
        .and_then(|t| t.strip_suffix(" ms"))
        .and_then(|t| t.parse().ok());
    match ms {
        Some(ms) => (head, Some(ms)),
        None => (rest, None),
    }
}

fn split_name(full: &str, status: TestStatus, duration_ms: Option<u64>) -> TestEvent {
    match full.split_once('.') {
        Some((suite, name)) => event(Some(suite.to_string()), name, status, duration_ms),
        None => event(None, full, status, duration_ms),
    }
}
