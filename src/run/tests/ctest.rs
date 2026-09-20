use crate::ffi::{TestEvent, TestStatus};

use super::event;

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
    let rest = line.trim_start().strip_prefix("Start")?.trim_start();
    let (number, name) = rest.split_once(':')?;
    is_number(number).then(|| name.trim())
}

fn outcome(line: &str) -> Option<TestEvent> {
    let (counter, rest) = line.trim_start().split_once("Test")?;
    let (done, total) = counter.trim().split_once('/')?;
    if !is_number(done) || !is_number(total) {
        return None;
    }
    let rest = rest.trim_start().strip_prefix('#')?;
    let (number, rest) = rest.split_once(':')?;
    if !is_number(number) {
        return None;
    }
    let (name, tail) = rest.split_once(" ..")?;
    let status = if tail.contains("Passed") {
        TestStatus::Passed
    } else if tail.contains("Skipped") || tail.contains("Not Run") {
        TestStatus::Ignored
    } else {
        TestStatus::Failed
    };
    let name = name.trim();
    Some(event(suite_of(name), name, status, duration_ms(tail)))
}

fn is_number(s: &str) -> bool {
    !s.is_empty() && s.bytes().all(|b| b.is_ascii_digit())
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
