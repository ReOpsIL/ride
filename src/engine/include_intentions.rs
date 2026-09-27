use std::path::PathBuf;
use std::sync::Arc;

use crate::discover::SystemIncludes;
use crate::ffi::CompletionHit;
use crate::highlight::BufferSession;
use crate::intentions::{self, Draft};

use super::reach::Reach;
use super::{Engine, Inner};

const MAX_HITS: usize = 5;

pub struct IncludeJob {
    clang: &'static str,
    text: String,
    reach: Reach,
    system: Arc<SystemIncludes>,
}

impl IncludeJob {
    pub fn take(inner: &Inner, session_id: u64, session: &BufferSession) -> Option<Self> {
        Some(Self {
            clang: session.lang().clang_name()?,
            text: session.replica().to_string(),
            reach: Reach::take(inner, session_id, session),
            system: inner.system_includes.clone(),
        })
    }

    pub fn drafts(self, engine: &Engine, hits: &[CompletionHit]) -> Vec<Draft> {
        let out = self.build(hits);
        self.reach.remember(engine);
        out
    }

    fn build(&self, hits: &[CompletionHit]) -> Vec<Draft> {
        let scope = self.reach.scope();
        let headers = self.reach.headers();
        let mut system_dirs: Option<Vec<PathBuf>> = None;
        let mut out = Vec::new();
        for path in candidate_paths(hits) {
            let Some(header) = headers.iter().find(|h| h.path == path) else {
                continue;
            };
            let dirs = if header.system {
                system_dirs.get_or_insert_with(|| self.system.dirs(self.clang, &[]))
            } else {
                &scope.search_dirs
            };
            out.extend(intentions::include_draft(
                &self.text,
                &path,
                header.system,
                dirs,
                &scope.includes,
            ));
        }
        out
    }
}

fn candidate_paths(hits: &[CompletionHit]) -> Vec<PathBuf> {
    let mut seen: Vec<PathBuf> = Vec::new();
    for path in hits
        .iter()
        .take(MAX_HITS)
        .filter_map(|h| h.source_path.as_ref().map(PathBuf::from))
    {
        if !seen.contains(&path) {
            seen.push(path);
        }
    }
    seen
}
