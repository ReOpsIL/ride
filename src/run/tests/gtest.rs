use crate::ffi::{TestCase, TestEvent, TestStatus};

use super::event;

const RUN: &str = "[ RUN      ] ";
const OK: &str = "[       OK ] ";
const FAILED: &str = "[  FAILED  ] ";
const SKIPPED: &str = "[  SKIPPED ] ";

pub fn list(text: &str) -> Vec<TestCase> {
    let mut cases = Vec::new();
    let mut suite: Option<String> = None;
    for line in text.lines() {
        if let Some(name) = suite_line(line) {
            suite = Some(name.to_string());
            continue;
        }
        let Some(name) = case_line(line) else {
            continue;
        };
        cases.push(TestCase {
            suite: suite.clone(),
            name: name.to_string(),
            file: None,
            line: None,
        });
    }
    cases
}

fn suite_line(line: &str) -> Option<&str> {
    if line.starts_with(char::is_whitespace) {
        return None;
    }
    let name = strip_comment(line).strip_suffix('.')?;
    (!name.is_empty()).then_some(name)
}

fn case_line(line: &str) -> Option<&str> {
    if !line.starts_with("  ") {
        return None;
    }
    let name = strip_comment(line);
    (!name.is_empty() && !name.ends_with('.')).then_some(name)
}

fn strip_comment(line: &str) -> &str {
    match line.split_once(" # ") {
        Some((head, _)) => head.trim(),
        None => line.trim(),
    }
}

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
