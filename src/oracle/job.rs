use std::path::PathBuf;

use super::key::MemberKey;

#[derive(Debug, Clone)]
pub struct DocText {
    pub session_id: u64,
    pub path: PathBuf,
    pub version: u64,
    pub text: String,
}

#[derive(Debug, Clone)]
pub struct MemberJob {
    pub key: MemberKey,
    pub doc: DocText,
    pub stale: Vec<DocText>,
}
