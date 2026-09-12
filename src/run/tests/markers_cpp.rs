use crate::ffi::{TestFramework, TestMarker};

pub(super) fn cpp(text: &str) -> Vec<TestMarker> {
    let mut out = Vec::new();
    let mut offset = 0usize;
    for line in text.split_inclusive('\n') {
        if let Some(marker) = cpp_line(line, offset) {
            out.push(marker);
        }
        offset += line.len();
    }
    out
}

fn cpp_line(line: &str, offset: usize) -> Option<TestMarker> {
    let (name, rest) = ["TEST_CASE", "TEST_F", "TEST_P", "TEST"]
        .iter()
        .find_map(|m| line.strip_prefix(m).map(|rest| (*m, rest)))?;
    let inside = rest.strip_prefix('(')?;
    let catch2 = name == "TEST_CASE";
    Some(TestMarker {
        name: if catch2 {
            quoted(inside)?
        } else {
            gtest_name(inside)?
        },
        byte_start: offset as u32,
        framework: Some(if catch2 {
            TestFramework::Catch2
        } else {
            TestFramework::GoogleTest
        }),
    })
}

fn quoted(inside: &str) -> Option<String> {
    let rest = inside.get(inside.find('"')? + 1..)?;
    let end = rest.find('"')?;
    Some(rest.get(..end)?.to_string())
}

fn gtest_name(inside: &str) -> Option<String> {
    let close = inside.find(')')?;
    let (suite, case) = inside.get(..close)?.split_once(',')?;
    let (suite, case) = (suite.trim(), case.trim());
    if suite.is_empty() || case.is_empty() {
        return None;
    }
    Some(format!("{suite}.{case}"))
}
