use serde::Deserialize;

use crate::ffi::{TestCase, TestEvent, TestStatus};

use super::event;

#[derive(Deserialize)]
struct Listing {
    #[serde(default)]
    tests: Vec<Entry>,
    #[serde(rename = "backtraceGraph", default)]
    graph: Graph,
}

#[derive(Deserialize)]
struct Entry {
    name: String,
    #[serde(default)]
    backtrace: Option<usize>,
}

#[derive(Deserialize, Default)]
struct Graph {
    #[serde(default)]
    files: Vec<String>,
    #[serde(default)]
    nodes: Vec<Node>,
}

#[derive(Deserialize)]
struct Node {
    #[serde(default)]
    file: Option<usize>,
    #[serde(default)]
    line: Option<u32>,
}

pub fn list(text: &str) -> Vec<TestCase> {
    let Ok(listing) = serde_json::from_str::<Listing>(text) else {
        return Vec::new();
    };
    listing
        .tests
        .iter()
        .map(|entry| {
            let node = entry.backtrace.and_then(|i| listing.graph.nodes.get(i));
            let file = node
                .and_then(|n| n.file)
                .and_then(|i| listing.graph.files.get(i))
                .cloned();
            TestCase {
                suite: suite_of(&entry.name),
                name: entry.name.clone(),
                file,
                line: node.and_then(|n| n.line),
            }
        })
        .collect()
}

fn suite_of(name: &str) -> Option<String> {
    name.rsplit_once('.').map(|(suite, _)| suite.to_string())
}

pub fn parse(text: &str) -> Vec<TestEvent> {
    let mut events: Vec<TestEvent> = Vec::new();
    for line in text.lines() {
        if summary(line) {
            break;
        }
        if let Some(name) = start(line) {
            events.push(event(suite_of(name), name, TestStatus::Started, None));
            continue;
        }
        if let Some(e) = outcome(line) {
            events.push(e);
            continue;
        }
        append(events.last_mut(), line);
    }
    for event in events.iter_mut() {
        event.output = event.output.trim().to_string();
    }
    events
}

fn summary(line: &str) -> bool {
    line.contains("% tests passed") || line.starts_with("Total Test time")
}

fn start(line: &str) -> Option<&str> {
    let rest = line.strip_prefix("    Start ")?;
    let (_, name) = rest.split_once(": ")?;
    Some(name.trim())
}

fn outcome(line: &str) -> Option<TestEvent> {
    let rest = line.split_once(" Test #")?.1.split_once(": ")?.1;
    let (name, tail) = rest.split_once(" ..")?;
    let status = if tail.contains("Passed") {
        TestStatus::Passed
    } else if tail.contains("Failed") || tail.contains("Timeout") {
        TestStatus::Failed
    } else if tail.contains("Skipped") || tail.contains("Not Run") {
        TestStatus::Ignored
    } else {
        return None;
    };
    let name = name.trim();
    Some(event(suite_of(name), name, status, duration_ms(tail)))
}

fn duration_ms(tail: &str) -> Option<u64> {
    let seconds: f64 = tail
        .trim_end()
        .strip_suffix(" sec")?
        .rsplit(' ')
        .next()?
        .parse()
        .ok()?;
    Some((seconds * 1000.0).round() as u64)
}

fn append(event: Option<&mut TestEvent>, line: &str) {
    let Some(event) = event else {
        return;
    };
    if line.trim().is_empty() && event.output.is_empty() {
        return;
    }
    if !event.output.is_empty() {
        event.output.push('\n');
    }
    event.output.push_str(line);
}
