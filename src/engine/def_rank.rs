use std::collections::HashSet;
use std::path::{Path, PathBuf};

pub const BUFFER: u8 = 0;
pub const WORKSPACE: u8 = 1;
pub const HEADER: u8 = 2;
pub const IMPORTED: u8 = 3;
pub const OTHER: u8 = 4;

#[derive(Default)]
pub struct RankContext {
    pub session_path: Option<PathBuf>,
    pub workspace_root: Option<PathBuf>,
    pub headers: HashSet<PathBuf>,
    pub crates: HashSet<String>,
}

impl RankContext {
    pub fn tier(&self, source_path: Option<&str>, crate_name: &str) -> u8 {
        let Some(raw) = source_path else {
            return BUFFER;
        };
        let path = Path::new(raw);
        if self.session_path.as_deref() == Some(path) {
            return BUFFER;
        }
        if self
            .workspace_root
            .as_ref()
            .is_some_and(|root| path.starts_with(root))
        {
            return WORKSPACE;
        }
        if self.headers.contains(path) {
            return HEADER;
        }
        if !crate_name.is_empty() && self.crates.contains(crate_name) {
            return IMPORTED;
        }
        OTHER
    }
}

pub fn imported_crates(text: &str) -> HashSet<String> {
    let mut out = HashSet::new();
    for line in text.lines() {
        let trimmed = line.trim_start();
        let rest = trimmed
            .strip_prefix("pub use ")
            .or_else(|| trimmed.strip_prefix("use "))
            .or_else(|| trimmed.strip_prefix("extern crate "));
        let Some(rest) = rest else {
            continue;
        };
        if let Some(name) = root_segment(rest) {
            out.insert(name);
        }
    }
    out
}

fn root_segment(rest: &str) -> Option<String> {
    let head = rest
        .split(&[':', ';', ' ', '{', '}', ','][..])
        .find(|s| !s.is_empty())?;
    let name = head.trim().replace('-', "_");
    let keyword = matches!(name.as_str(), "crate" | "self" | "super");
    let plain = name
        .chars()
        .all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-');
    (!keyword && plain && !name.is_empty()).then_some(name)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn context() -> RankContext {
        RankContext {
            session_path: Some(PathBuf::from("/w/src/main.rs")),
            workspace_root: Some(PathBuf::from("/w")),
            headers: HashSet::from([PathBuf::from("/usr/include/geo.h")]),
            crates: HashSet::from(["serde".to_string()]),
        }
    }

    #[test]
    fn buffer_beats_workspace_beats_header_beats_imported() {
        let ctx = context();
        assert_eq!(ctx.tier(None, ""), BUFFER);
        assert_eq!(ctx.tier(Some("/w/src/main.rs"), ""), BUFFER);
        assert_eq!(ctx.tier(Some("/w/src/util.rs"), "ride-demo"), WORKSPACE);
        assert_eq!(ctx.tier(Some("/usr/include/geo.h"), ""), HEADER);
        assert_eq!(ctx.tier(Some("/reg/serde/lib.rs"), "serde"), IMPORTED);
        assert_eq!(ctx.tier(Some("/reg/ctr/lib.rs"), "ctr"), OTHER);
    }

    #[test]
    fn empty_context_keeps_catalog_hits_last() {
        let ctx = RankContext::default();
        assert_eq!(ctx.tier(Some("/reg/ctr/lib.rs"), "ctr"), OTHER);
        assert_eq!(ctx.tier(None, "ctr"), BUFFER);
    }

    #[test]
    fn use_lines_name_their_root_crate() {
        let text = "use std::collections::HashMap;\nuse util::{Counter, Recorder};\npub use serde::Serialize;\nextern crate libc;\nuse crate::inner::Thing;\nlet x = 1;\n";
        let got = imported_crates(text);
        assert!(got.contains("std"));
        assert!(got.contains("util"));
        assert!(got.contains("serde"));
        assert!(got.contains("libc"));
        assert!(!got.contains("crate"));
        assert_eq!(got.len(), 4, "{got:?}");
    }
}
