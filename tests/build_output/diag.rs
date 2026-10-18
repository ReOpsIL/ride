use std::path::Path;

use ride_engine::Diagnostic;

pub fn src(diag: &Diagnostic) -> &str {
    &diag.primary.path
}

pub fn loc(diag: &Diagnostic) -> (u32, u32) {
    (diag.primary.line_start, diag.primary.column)
}

pub fn byte_of(path: &Path, line: u32, column: u32) -> u32 {
    let text = std::fs::read_to_string(path).unwrap();
    let start: u32 = text
        .split_inclusive('\n')
        .take(line as usize - 1)
        .map(|row| row.len() as u32)
        .sum();
    start + column - 1
}
