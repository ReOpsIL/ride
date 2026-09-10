use std::collections::HashMap;
use std::path::{Path, PathBuf};

struct FileLines {
    starts: Vec<u32>,
    len: u32,
}

#[derive(Default)]
pub struct LineOffsets {
    files: HashMap<PathBuf, FileLines>,
}

impl LineOffsets {
    pub fn byte_at(&mut self, path: &Path, line: u32, column: u32) -> u32 {
        let lines = self
            .files
            .entry(path.to_path_buf())
            .or_insert_with(|| read_lines(path));
        let base = lines
            .starts
            .get(line.saturating_sub(1) as usize)
            .copied()
            .unwrap_or(lines.len);
        (base + column.saturating_sub(1)).min(lines.len)
    }
}

fn read_lines(path: &Path) -> FileLines {
    let bytes = std::fs::read(path).unwrap_or_default();
    let starts = std::iter::once(0)
        .chain(
            bytes
                .iter()
                .enumerate()
                .filter(|(_, b)| **b == b'\n')
                .map(|(i, _)| i as u32 + 1),
        )
        .collect();
    FileLines {
        starts,
        len: bytes.len() as u32,
    }
}
