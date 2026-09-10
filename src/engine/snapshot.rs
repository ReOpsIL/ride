use std::collections::HashSet;
use std::path::Path;
use std::sync::Arc;

use tantivy::{Index, IndexReader};

use crate::discover::SystemIncludes;
use crate::ffi::{CompletionQuery, WorkspaceInfo};
use crate::highlight::{Lang, LocalHits, LocalQuery, Site, SiteAt, SourceScope};
use crate::query::IndexSrc;

use super::Engine;
use super::headers::Header;
use super::reach::Reach;

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
    pub reach: Option<Reach>,
    pub imports: Vec<String>,
    pub system_includes: Arc<SystemIncludes>,
    pub catalog: Catalog,
    pub workspace: Option<WorkspaceInfo>,
}

impl Snapshot {
    pub fn scope(&self) -> Option<&Arc<SourceScope>> {
        self.reach.as_ref().map(Reach::scope)
    }

    pub fn headers(&self) -> &[Arc<Header>] {
        self.reach.as_ref().map(Reach::headers).unwrap_or(&[])
    }

    pub fn remember(&self, engine: &Engine) {
        if let Some(reach) = &self.reach {
            reach.remember(engine);
        }
    }
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
            Some(Snapshot {
                lang,
                site,
                local,
                reach: session.map(|s| Reach::take(i, q.session_id, s)),
                imports: session.map(|s| s.imports()).unwrap_or_default(),
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
