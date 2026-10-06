use crate::ffi::{GitChangeKind, GitFileChange, GitRepoStatus};

pub fn parse_status(root: &str, porcelain: &str) -> GitRepoStatus {
    let mut status = GitRepoStatus {
        root: root.to_string(),
        branch: None,
        head: None,
        upstream: None,
        ahead: 0,
        behind: 0,
        changes: Vec::new(),
    };
    let mut records = porcelain.split('\0').filter(|r| !r.is_empty());
    while let Some(record) = records.next() {
        match record.split_once(' ') {
            Some(("#", header)) => apply_header(&mut status, header),
            Some(("1", rest)) => status.changes.extend(ordinary(rest, 8, None)),
            Some(("2", rest)) => {
                let orig = records.next().map(str::to_string);
                status.changes.extend(ordinary(rest, 9, orig));
            }
            Some(("u", rest)) => status.changes.extend(unmerged(rest)),
            Some(("?", path)) => status.changes.push(untracked(path)),
            _ => {}
        }
    }
    status
}

fn apply_header(status: &mut GitRepoStatus, header: &str) {
    let Some((key, value)) = header.split_once(' ') else {
        return;
    };
    match key {
        "branch.oid" if value != "(initial)" => status.head = Some(short(value)),
        "branch.head" if value != "(detached)" => status.branch = Some(value.to_string()),
        "branch.upstream" => status.upstream = Some(value.to_string()),
        "branch.ab" => {
            let mut counts = value
                .split(' ')
                .map(|c| c.get(1..).and_then(|n| n.parse().ok()).unwrap_or(0));
            status.ahead = counts.next().unwrap_or(0);
            status.behind = counts.next().unwrap_or(0);
        }
        _ => {}
    }
}

fn short(oid: &str) -> String {
    oid.chars().take(8).collect()
}

fn ordinary(rest: &str, fields: usize, orig_path: Option<String>) -> Option<GitFileChange> {
    let parts: Vec<&str> = rest.splitn(fields, ' ').collect();
    let (xy, path) = (parts.first()?, parts.get(fields - 1)?);
    let mut codes = xy.chars();
    Some(GitFileChange {
        path: path.to_string(),
        orig_path,
        staged: codes.next().and_then(kind),
        unstaged: codes.next().and_then(kind),
    })
}

fn unmerged(rest: &str) -> Option<GitFileChange> {
    let path = rest.splitn(10, ' ').nth(9)?;
    Some(GitFileChange {
        path: path.to_string(),
        orig_path: None,
        staged: None,
        unstaged: Some(GitChangeKind::Conflicted),
    })
}

fn untracked(path: &str) -> GitFileChange {
    GitFileChange {
        path: path.to_string(),
        orig_path: None,
        staged: None,
        unstaged: Some(GitChangeKind::Untracked),
    }
}

fn kind(code: char) -> Option<GitChangeKind> {
    match code {
        'M' => Some(GitChangeKind::Modified),
        'T' => Some(GitChangeKind::TypeChanged),
        'A' => Some(GitChangeKind::Added),
        'D' => Some(GitChangeKind::Deleted),
        'R' => Some(GitChangeKind::Renamed),
        'C' => Some(GitChangeKind::Copied),
        'U' => Some(GitChangeKind::Conflicted),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const SAMPLE: &str = "# branch.oid 0123456789abcdef\0# branch.head main\0# branch.upstream origin/main\0# branch.ab +2 -1\0\
1 .M N... 100644 100644 100644 aaa bbb src/main.rs\0\
1 A. N... 000000 100644 100644 000 ccc new file.rs\0\
2 R. N... 100644 100644 100644 ddd ddd R100 src/b.rs\0src/a.rs\0\
u UU N... 100644 100644 100644 100644 e1 e2 e3 both.rs\0\
? notes.txt\0";

    #[test]
    fn reads_branch_headers() {
        let status = parse_status("/r", SAMPLE);
        assert_eq!(status.branch.as_deref(), Some("main"));
        assert_eq!(status.head.as_deref(), Some("01234567"));
        assert_eq!(status.upstream.as_deref(), Some("origin/main"));
        assert_eq!((status.ahead, status.behind), (2, 1));
    }

    #[test]
    fn reads_every_entry_kind() {
        let status = parse_status("/r", SAMPLE);
        let rows: Vec<_> = status
            .changes
            .iter()
            .map(|c| {
                (
                    c.path.as_str(),
                    c.orig_path.as_deref(),
                    c.staged,
                    c.unstaged,
                )
            })
            .collect();
        assert_eq!(
            rows,
            vec![
                ("src/main.rs", None, None, Some(GitChangeKind::Modified)),
                ("new file.rs", None, Some(GitChangeKind::Added), None),
                (
                    "src/b.rs",
                    Some("src/a.rs"),
                    Some(GitChangeKind::Renamed),
                    None
                ),
                ("both.rs", None, None, Some(GitChangeKind::Conflicted)),
                ("notes.txt", None, None, Some(GitChangeKind::Untracked)),
            ]
        );
    }

    #[test]
    fn detached_and_unborn_heads_have_no_name() {
        let status = parse_status("/r", "# branch.oid (initial)\0# branch.head (detached)\0");
        assert_eq!(status.branch, None);
        assert_eq!(status.head, None);
    }
}
