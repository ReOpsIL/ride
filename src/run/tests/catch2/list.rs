use crate::ffi::TestCase;

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
            tags(cases.last_mut(), trimmed);
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

fn tags(case: Option<&mut TestCase>, trimmed: &str) {
    let Some(case) = case else {
        return;
    };
    if trimmed.starts_with('[') {
        case.suite = Some(trimmed.to_string());
    }
}
