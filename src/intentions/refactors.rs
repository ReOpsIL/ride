use crate::ffi::{ByteRange, ExtractPlan};
use crate::highlight::BufferSession;
use crate::refactor;

use super::draft::Draft;

const DEPTH: usize = 3;

pub fn drafts(session: &BufferSession, caret: u32) -> Vec<Draft> {
    let ranges = candidates(session, caret);
    let mut out = Vec::new();
    if let Some(plan) = first(&ranges, |r| {
        refactor::extract_variable(session, r.start_byte, r.end_byte)
    }) {
        out.push(Draft::new("Extract Variable", plan.edits));
    }
    if let Some(plan) = first(&ranges, |r| {
        refactor::introduce_constant(session, r.start_byte, r.end_byte)
    }) {
        out.push(Draft::new("Introduce Constant", plan.edits));
    }
    if let Some(plan) = refactor::inline_variable(session, caret) {
        out.push(Draft::new("Inline Variable", plan.edits));
    }
    out
}

fn candidates(session: &BufferSession, caret: u32) -> Vec<ByteRange> {
    let point = ByteRange {
        start_byte: caret,
        end_byte: caret,
    };
    session
        .enclosing_ranges(point)
        .into_iter()
        .take(DEPTH)
        .collect()
}

fn first(
    ranges: &[ByteRange],
    make: impl Fn(&ByteRange) -> Option<ExtractPlan>,
) -> Option<ExtractPlan> {
    ranges.iter().find_map(make)
}
