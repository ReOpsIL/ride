use crate::ffi::{TestCase, TestEvent, TestStatus};

use super::event;

pub fn list(text: &str) -> Vec<TestCase> {
    let mut cases: Vec<TestCase> = Vec::new();
    let mut listing = false;
    for line in text.lines() {
        if line.ends_with("test cases:") {
            listing = true;
            continue;
        }
        if !listing {
            continue;
        }
        if !line.starts_with("  ") {
            listing = !line.trim().is_empty();
            continue;
        }
        let trimmed = line.trim();
        if line.starts_with("    ") {
            detail(cases.last_mut(), trimmed);
            continue;
        }
        cases.push(TestCase {
            suite: None,
            name: trimmed.to_string(),
            file: None,
            line: None,
        });
    }
    cases
}

fn detail(case: Option<&mut TestCase>, trimmed: &str) {
    let Some(case) = case else {
        return;
    };
    if trimmed.starts_with('[') {
        case.suite = Some(trimmed.to_string());
        return;
    }
    if let Some((file, line)) = source_location(trimmed) {
        case.file = Some(file.to_string());
        case.line = Some(line);
    }
}

fn source_location(text: &str) -> Option<(&str, u32)> {
    let (file, line) = text.rsplit_once(':')?;
    Some((file, line.trim().parse().ok()?))
}

pub fn parse(text: &str) -> Vec<TestEvent> {
    text.lines().filter_map(assertion).collect()
}

fn assertion(line: &str) -> Option<TestEvent> {
    let (location, rest) = line.split_once(": ")?;
    let (file, number) = source_location(location)?;
    let (verb, detail) = match rest.split_once(": ") {
        Some((verb, detail)) => (verb, detail),
        None => (rest.trim_end_matches(':'), ""),
    };
    let status = match verb {
        "passed" => TestStatus::Passed,
        "failed" => TestStatus::Failed,
        _ => return None,
    };
    let name = format!("{file}:{number}");
    let mut e = event(Some(file.to_string()), &name, status, None);
    e.output = detail.to_string();
    Some(e)
}
