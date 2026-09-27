use std::path::{Path, PathBuf};

use crate::ffi::{UsageHit, UsagesResponse};
use crate::highlight::{BufferSession, Lang};
use crate::refs::{DefContext, RefKind, RefRecord, extractor_for};

use super::rel_path::relative;

pub struct LiveFile {
    pub rel: String,
    path: PathBuf,
    lang: Lang,
    text: String,
}

impl LiveFile {
    pub fn snapshot(session: &BufferSession, root: Option<&Path>) -> Option<Self> {
        let root = root?;
        let path = session.path()?.to_path_buf();
        Some(Self {
            rel: relative(Some(root), &path),
            path,
            lang: session.lang(),
            text: session.replica().to_string(),
        })
    }

    pub fn merge(
        self,
        mut resp: UsagesResponse,
        kind: Option<RefKind>,
        ctx: &DefContext,
    ) -> UsagesResponse {
        let in_scope = ctx.has_definition && ctx.def_paths.iter().any(|d| same_file(d, &self.path));
        let records = extractor_for(self.lang).extract(self.lang, &self.text);
        resp.hits.extend(
            records
                .into_iter()
                .filter(|r| r.name == resp.name && kind.is_none_or(|k| r.kind == k))
                .map(|r| hit(&self.rel, r, in_scope)),
        );
        resp.hits.sort_by(|a, b| {
            b.in_definition_scope
                .cmp(&a.in_definition_scope)
                .then_with(|| a.path.cmp(&b.path))
                .then_with(|| a.byte_start.cmp(&b.byte_start))
        });
        resp
    }
}

fn hit(rel: &str, record: RefRecord, in_scope: bool) -> UsageHit {
    UsageHit {
        path: rel.to_string(),
        line: record.line,
        byte_start: record.byte_start,
        byte_end: record.byte_end,
        enclosing_item: record.enclosing_item,
        enclosing_kind: record.enclosing_kind,
        ref_kind: record.kind.label().to_string(),
        in_definition_scope: in_scope,
    }
}

fn same_file(a: &Path, b: &Path) -> bool {
    let ca = a.canonicalize().unwrap_or_else(|_| a.to_path_buf());
    let cb = b.canonicalize().unwrap_or_else(|_| b.to_path_buf());
    ca == cb
}
