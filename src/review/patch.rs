use super::model::{Hunks, LineRange};

#[derive(Debug, Clone)]
pub struct PatchFile {
    pub path: String,
    pub old_path: Option<String>,
    pub binary: bool,
    pub deleted: bool,
    pub added: bool,
    pub hunks: Hunks,
}

pub fn parse(diff: &str) -> Vec<PatchFile> {
    let mut files = Vec::new();
    let mut current: Option<PatchFile> = None;
    for line in diff.split_inclusive('\n') {
        let line = line.trim_end_matches(['\n', '\r']);
        if let Some(paths) = line.strip_prefix("diff --git ") {
            if let Some(file) = current.take() {
                files.push(file);
            }
            current = Some(start(paths));
            continue;
        }
        let Some(file) = current.as_mut() else {
            continue;
        };
        if line.starts_with("deleted file") {
            file.deleted = true;
        } else if line.starts_with("new file") {
            file.added = true;
        } else if let Some(path) = line.strip_prefix("rename from ") {
            file.old_path = Some(path.to_string());
        } else if let Some(path) = line.strip_prefix("rename to ") {
            file.path = path.to_string();
        } else if line.starts_with("Binary files") {
            file.binary = true;
        } else if let Some((old, new)) = hunk(line) {
            file.hunks.old.push(old);
            file.hunks.new.push(new);
        }
    }
    if let Some(file) = current {
        files.push(file);
    }
    files
}

fn start(header: &str) -> PatchFile {
    let (old, new) = header
        .split_once(" b/")
        .map(|(old, new)| (strip(old), new.to_string()))
        .unwrap_or_else(|| (String::new(), strip(header)));
    let old_path = (old != new && !old.is_empty()).then_some(old);
    PatchFile {
        path: new,
        old_path,
        binary: false,
        deleted: false,
        added: false,
        hunks: Hunks::default(),
    }
}

fn strip(path: &str) -> String {
    path.strip_prefix("a/")
        .or_else(|| path.strip_prefix("b/"))
        .unwrap_or(path)
        .to_string()
}

fn hunk(line: &str) -> Option<(LineRange, LineRange)> {
    let rest = line.strip_prefix("@@ ")?;
    let (old, rest) = rest.split_once(' ')?;
    let new = rest
        .split_once(" @@")
        .map(|(value, _)| value)
        .unwrap_or(rest);
    Some((range(old)?, range(new)?))
}

fn range(text: &str) -> Option<LineRange> {
    let text = text.trim_start_matches(['-', '+']);
    let (start, count) = match text.split_once(',') {
        Some((start, count)) => (start.parse().ok()?, count.parse().ok()?),
        None => (text.parse().ok()?, 1u32),
    };
    if count == 0 {
        Some(LineRange {
            start,
            end: start.saturating_sub(1),
        })
    } else {
        Some(LineRange {
            start,
            end: start + count - 1,
        })
    }
}
