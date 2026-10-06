use crate::ffi::{GitDiffLine, GitFileDiff, GitHunk, GitLineKind};

pub fn parse_diff(path: &str, text: &str) -> GitFileDiff {
    let mut diff = GitFileDiff {
        path: path.to_string(),
        binary: false,
        hunks: Vec::new(),
    };
    let mut cursor = Cursor::default();
    for line in text.lines() {
        if let Some(hunk) = parse_header(line) {
            cursor = Cursor {
                old: hunk.old_start,
                new: hunk.new_start,
            };
            diff.hunks.push(hunk);
            continue;
        }
        match diff.hunks.last_mut() {
            Some(hunk) => cursor.push(hunk, line),
            None if line.starts_with("Binary files ") => diff.binary = true,
            None => {}
        }
    }
    diff
}

#[derive(Default)]
struct Cursor {
    old: u32,
    new: u32,
}

impl Cursor {
    fn push(&mut self, hunk: &mut GitHunk, line: &str) {
        let mut chars = line.chars();
        let entry = match chars.next() {
            Some('+') => self.added(chars.as_str()),
            Some('-') => self.removed(chars.as_str()),
            Some(' ') => self.context(chars.as_str()),
            None => self.context(""),
            _ => return,
        };
        hunk.lines.push(entry);
    }

    fn added(&mut self, text: &str) -> GitDiffLine {
        self.new += 1;
        line(GitLineKind::Added, None, Some(self.new - 1), text)
    }

    fn removed(&mut self, text: &str) -> GitDiffLine {
        self.old += 1;
        line(GitLineKind::Removed, Some(self.old - 1), None, text)
    }

    fn context(&mut self, text: &str) -> GitDiffLine {
        self.old += 1;
        self.new += 1;
        line(
            GitLineKind::Context,
            Some(self.old - 1),
            Some(self.new - 1),
            text,
        )
    }
}

fn line(kind: GitLineKind, old: Option<u32>, new: Option<u32>, text: &str) -> GitDiffLine {
    GitDiffLine {
        kind,
        old_line: old,
        new_line: new,
        text: text.to_string(),
        spans: Vec::new(),
    }
}

fn parse_header(line: &str) -> Option<GitHunk> {
    let rest = line.strip_prefix("@@ -")?;
    let (ranges, section) = rest.split_once(" @@")?;
    let (old, new) = ranges.split_once(" +")?;
    let (old_start, old_count) = range(old)?;
    let (new_start, new_count) = range(new)?;
    Some(GitHunk {
        header: section.trim().to_string(),
        old_start,
        old_count,
        new_start,
        new_count,
        lines: Vec::new(),
    })
}

fn range(text: &str) -> Option<(u32, u32)> {
    match text.split_once(',') {
        Some((start, count)) => Some((start.parse().ok()?, count.parse().ok()?)),
        None => Some((text.parse().ok()?, 1)),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const SAMPLE: &str = "diff --git a/src/a.rs b/src/a.rs
index 111..222 100644
--- a/src/a.rs
+++ b/src/a.rs
@@ -2,3 +2,4 @@ fn main() {
 keep
-old
+new
+more
 tail
\\ No newline at end of file
@@ -20 +21,0 @@
-gone
";

    #[test]
    fn numbers_lines_on_both_sides() {
        let diff = parse_diff("src/a.rs", SAMPLE);
        assert!(!diff.binary);
        assert_eq!(diff.hunks.len(), 2);
        let first = &diff.hunks[0];
        assert_eq!(first.header, "fn main() {");
        let rows: Vec<_> = first
            .lines
            .iter()
            .map(|l| (l.kind, l.old_line, l.new_line, l.text.as_str()))
            .collect();
        assert_eq!(
            rows,
            vec![
                (GitLineKind::Context, Some(2), Some(2), "keep"),
                (GitLineKind::Removed, Some(3), None, "old"),
                (GitLineKind::Added, None, Some(3), "new"),
                (GitLineKind::Added, None, Some(4), "more"),
                (GitLineKind::Context, Some(4), Some(5), "tail"),
            ]
        );
    }

    #[test]
    fn single_line_ranges_default_to_one() {
        let hunk = &parse_diff("x", SAMPLE).hunks[1];
        assert_eq!((hunk.old_start, hunk.old_count), (20, 1));
        assert_eq!((hunk.new_start, hunk.new_count), (21, 0));
        assert_eq!(hunk.lines[0].old_line, Some(20));
    }

    #[test]
    fn binary_files_have_no_hunks() {
        let diff = parse_diff(
            "i.png",
            "diff --git a/i.png b/i.png\nBinary files a/i.png and b/i.png differ\n",
        );
        assert!(diff.binary);
        assert!(diff.hunks.is_empty());
    }
}
