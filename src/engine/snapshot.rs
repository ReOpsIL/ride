use std::collections::HashSet;
use std::path::Path;
use std::sync::Arc;

use tantivy::{Index, IndexReader};

use crate::discover::SystemIncludes;
use crate::ffi::{CompletionQuery, WorkspaceInfo};
use crate::highlight::{
    Lang, LiteralState, LocalHits, LocalQuery, Site, SiteAt, SourceScope, literal_state,
};
use crate::query::IndexSrc;

use super::Engine;
use super::headers::HeaderCache;

pub struct Catalog {
    pub index_dir: String,
    pub index: Option<Index>,
    pub reader: Option<IndexReader>,
    pub overlay: HashSet<String>,
}

impl Catalog {
    pub fn src(&self) -> IndexSrc<'_> {
        match (self.index.as_ref(), self.reader.as_ref()) {
            (Some(index), Some(reader)) => IndexSrc::Live(index, reader),
            _ => IndexSrc::Dir(Path::new(&self.index_dir)),
        }
    }
}

pub struct Snapshot {
    pub lang: Lang,
    pub site: Option<SiteAt>,
    pub local: Option<LocalHits>,
    pub literal: Option<LiteralState>,
    pub scope: Option<SourceScope>,
    pub imports: Vec<String>,
    pub headers: Arc<HeaderCache>,
    pub system_includes: Arc<SystemIncludes>,
    pub catalog: Catalog,
    pub workspace: Option<WorkspaceInfo>,
}

pub fn take(engine: &Engine, q: &CompletionQuery, limit: u32) -> Option<Snapshot> {
    engine
        .write(|i| {
            let prev = i.latest_query_id.get(&q.session_id).copied().unwrap_or(0);
            if prev > q.query_id {
                return None;
            }
            i.latest_query_id.insert(q.session_id, q.query_id);
            let session = i.sessions.get(&q.session_id);
            let lang = session.map(|s| s.lang()).unwrap_or(Lang::Rust);
            let site = session.map(|s| s.site_at(q.cursor_byte));
            let wants_local = matches!(
                site.as_ref().map(|s| &s.site),
                Some(Site::Identifier(_) | Site::MemberAccess | Site::StructLiteral(_))
            );
            let local = session
                .filter(|_| wants_local)
                .zip(site.as_ref())
                .map(|(s, at)| {
                    s.local_hits(&LocalQuery {
                        prefix: &at.prefix,
                        limit,
                        at: at.replace_start as u32,
                    })
                });
            let literal = session
                .zip(site.as_ref())
                .filter(|(_, at)| matches!(at.site, Site::StructLiteral(_)))
                .map(|(s, at)| {
                    literal_state(s.replica(), at.replace_start, q.cursor_byte as usize)
                });
            Some(Snapshot {
                lang,
                site,
                local,
                literal,
                scope: session.map(|s| s.scope()),
                imports: session.map(|s| s.imports()).unwrap_or_default(),
                headers: i.headers.clone(),
                system_includes: i.system_includes.clone(),
                catalog: Catalog {
                    index_dir: i.config.index_dir.clone(),
                    index: i.index.clone(),
                    reader: i.reader.clone(),
                    overlay: i.overlay.clone(),
                },
                workspace: i.workspace.clone(),
            })
        })
        .ok()
        .flatten()
}

pub fn is_latest(engine: &Engine, session_id: u64, query_id: u64) -> bool {
    engine
        .read(|i| i.latest_query_id.get(&session_id).copied())
        .ok()
        .flatten()
        == Some(query_id)
}
