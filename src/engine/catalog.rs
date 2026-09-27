use std::collections::HashSet;
use std::path::Path;

use tantivy::{Index, IndexReader};

use crate::ffi::{CompletionContext, CompletionHit, CompletionQuery, CompletionResponse};
use crate::highlight::Lang;
use crate::query::{self, Filter, IndexSrc};

use super::Inner;
use super::open_workspace::{OpenWorkspace, WorkspaceTree};

pub struct Catalog {
    index_dir: String,
    index: Option<Index>,
    reader: Option<IndexReader>,
    pub overlay: HashSet<String>,
    workspace: Option<WorkspaceScope>,
}

struct WorkspaceScope {
    tree: WorkspaceTree,
    members: HashSet<String>,
}

impl Catalog {
    pub fn of(inner: &Inner) -> Self {
        Self {
            index_dir: inner.config.index_dir.clone(),
            index: inner.index.clone(),
            reader: inner.reader.clone(),
            overlay: inner.overlay.clone(),
            workspace: inner.workspace.as_ref().map(WorkspaceScope::of),
        }
    }

    pub fn exact(&self, name: &str, qualifier: Option<&str>, limit: usize) -> Vec<CompletionHit> {
        self.current(query::exact_search(self.src(), name, qualifier, limit))
    }

    pub fn children(
        &self,
        parent: &str,
        prefix: &str,
        limit: usize,
        context: CompletionContext,
    ) -> Vec<CompletionHit> {
        self.current(query::children(self.src(), parent, prefix, limit, context))
    }

    pub fn listed(
        &self,
        filter: Filter,
        prefix: &str,
        limit: usize,
        context: CompletionContext,
    ) -> Vec<CompletionHit> {
        self.current(query::listed(self.src(), filter, prefix, limit, context))
    }

    pub fn search(&self, q: &CompletionQuery) -> CompletionResponse {
        let mut resp = query::search(self.src(), q, &self.overlay);
        resp.hits = self.current(resp.hits);
        resp
    }

    pub fn run_query(&self, q: CompletionQuery, lang: Lang) -> CompletionResponse {
        let mut resp = query::run_query(self.src(), q, lang, Vec::new(), &self.overlay);
        resp.hits = self.current(resp.hits);
        resp
    }

    fn current(&self, mut hits: Vec<CompletionHit>) -> Vec<CompletionHit> {
        if let Some(workspace) = &self.workspace {
            hits.retain(|h| !workspace.foreign(h));
        }
        hits
    }

    fn src(&self) -> IndexSrc<'_> {
        match (self.index.as_ref(), self.reader.as_ref()) {
            (Some(index), Some(reader)) => IndexSrc::Live(index, reader),
            _ => IndexSrc::Dir(Path::new(&self.index_dir)),
        }
    }
}

impl WorkspaceScope {
    fn of(open: &OpenWorkspace) -> Self {
        let info = &open.info;
        let members = info
            .members
            .iter()
            .chain(info.package_name.iter())
            .map(|m| crate_key(m))
            .collect();
        Self {
            tree: open.tree.clone(),
            members,
        }
    }

    fn foreign(&self, hit: &CompletionHit) -> bool {
        let Some(path) = hit.source_path.as_deref() else {
            return false;
        };
        self.members.contains(&crate_key(&hit.crate_name)) && !self.tree.contains(Path::new(path))
    }
}

fn crate_key(name: &str) -> String {
    name.replace('-', "_")
}
