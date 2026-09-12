use std::collections::HashMap;

use crate::ffi::{TestCase, TestEvent, TestStatus};

use super::{event, suite_of};

pub fn list(text: &str) -> Vec<TestCase> {
    text.lines().filter_map(case).collect()
}

fn case(line: &str) -> Option<TestCase> {
    if line.starts_with(char::is_whitespace) {
        return None;
    }
    let name = line
        .strip_suffix(": test")
        .or_else(|| line.strip_suffix(": benchmark"))?;
    if name.is_empty() {
        return None;
    }
    Some(TestCase {
        suite: suite_of(name),
        name: name.to_string(),
        file: None,
        line: None,
    })
}

pub fn parse(text: &str) -> Vec<TestEvent> {
    let mut outputs = stdout_blocks(text);
    let mut events = Vec::new();
    for line in text.lines() {
        let Some((name, status)) = result(line) else {
            continue;
        };
        let mut e = event(suite_of(name), name, status, None);
        if let Some(output) = outputs.remove(name) {
            e.output = output;
        }
        events.push(e);
    }
    events
}

fn result(line: &str) -> Option<(&str, TestStatus)> {
    let rest = line.strip_prefix("test ")?;
    let (name, outcome) = rest.split_once(" ... ")?;
    let status = if outcome == "ok" || outcome.starts_with("ok ") {
        TestStatus::Passed
    } else if outcome.starts_with("FAILED") {
        TestStatus::Failed
    } else if outcome.starts_with("ignored") {
        TestStatus::Ignored
    } else {
        return None;
    };
    Some((name.trim(), status))
}

fn stdout_blocks(text: &str) -> HashMap<String, String> {
    let mut blocks = HashMap::new();
    let mut open: Option<(String, Vec<&str>)> = None;
    for line in text.lines() {
        if let Some(name) = block_start(line) {
            close(&mut open, &mut blocks);
            open = Some((name.to_string(), Vec::new()));
            continue;
        }
        if block_end(line) {
            close(&mut open, &mut blocks);
            continue;
        }
        if let Some((_, lines)) = open.as_mut() {
            lines.push(line);
        }
    }
    close(&mut open, &mut blocks);
    blocks
}

fn block_start(line: &str) -> Option<&str> {
    let rest = line.strip_prefix("---- ")?;
    rest.strip_suffix(" stdout ----")
        .or_else(|| rest.strip_suffix(" stderr ----"))
}

fn block_end(line: &str) -> bool {
    line == "failures:" || line.starts_with("test result:")
}

fn close(open: &mut Option<(String, Vec<&str>)>, blocks: &mut HashMap<String, String>) {
    let Some((name, lines)) = open.take() else {
        return;
    };
    let text = lines.join("\n").trim().to_string();
    blocks
        .entry(name)
        .and_modify(|existing: &mut String| {
            existing.push('\n');
            existing.push_str(&text);
        })
        .or_insert(text);
}
