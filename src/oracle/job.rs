use std::path::PathBuf;

use crate::highlight::Lang;

use super::items::Shape;
use super::key::SiteKey;

#[derive(Debug, Clone)]
pub struct DocText {
    pub session_id: u64,
    pub lang: Lang,
    pub path: PathBuf,
    pub version: u64,
    pub text: String,
}

#[derive(Debug, Clone)]
pub struct SiteJob {
    pub key: SiteKey,
    pub shape: Shape,
    pub doc: DocText,
    pub stale: Vec<DocText>,
}
