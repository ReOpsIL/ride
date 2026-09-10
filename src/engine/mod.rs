use std::collections::{HashMap, HashSet};
use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::Path;
use std::sync::{Arc, RwLock};

use tantivy::{Index, IndexReader};

use crate::discover::workspace_info;
use crate::error::EngineError;
use crate::ffi::{
    CompletionQuery, CompletionResponse, EngineConfig, IndexStatus, IndexStatusListener,
    WorkspaceInfo,
};
use crate::highlight::BufferSession;

mod access;
mod cheat;
mod edits;
mod header_hits;
mod header_store;
mod headers;
mod identifier;
mod include_graph;
mod includes;
mod lists;
mod merge;
mod paths;
mod postfix;
mod query;
mod reach;
mod rust_members;
mod sessions;
mod signature;
mod snapshot;
mod snippets;
mod struct_literal;
mod symbols;
mod tools;
mod watch;

pub(crate) struct Inner {
    pub(crate) config: EngineConfig,
    pub(crate) workspace: Option<WorkspaceInfo>,
    pub(crate) sessions: HashMap<u64, BufferSession>,
    pub(crate) next_session_id: u64,
    pub(crate) overlay: HashSet<String>,
    pub(crate) latest_query_id: HashMap<u64, u64>,
    pub(crate) listener: Option<Arc<dyn IndexStatusListener>>,
    pub(crate) last_status: IndexStatus,
    pub(crate) generation: u32,
    pub(crate) index: Option<Index>,
    pub(crate) reader: Option<IndexReader>,
    pub(crate) headers: Arc<headers::HeaderCache>,
    pub(crate) scopes: reach::ScopeCache,
    pub(crate) system_includes: Arc<crate::discover::SystemIncludes>,
}

#[derive(uniffi::Object)]
pub struct Engine {
    inner: RwLock<Inner>,
}

impl Engine {
    fn new(config: EngineConfig) -> Self {
        let rust_src = crate::discover::sysroot_path(&config)
            .ok()
            .flatten()
            .map(|s| s.join("lib/rustlib/src/rust/library/std").is_dir())
            .unwrap_or(false);
        let header_store = Path::new(&config.index_dir).join("headers");
        Self {
            inner: RwLock::new(Inner {
                config,
                workspace: None,
                sessions: HashMap::new(),
                next_session_id: 1,
                overlay: HashSet::new(),
                latest_query_id: HashMap::new(),
                listener: None,
                last_status: IndexStatus::idle(rust_src),
                generation: 0,
                index: None,
                reader: None,
                headers: Arc::new(headers::HeaderCache::new(Some(header_store))),
                scopes: reach::ScopeCache::default(),
                system_includes: Arc::default(),
            }),
        }
    }

    pub(crate) fn write<T>(&self, f: impl FnOnce(&mut Inner) -> T) -> Result<T, EngineError> {
        self.inner
            .write()
            .map(|mut g| f(&mut g))
            .map_err(|_| EngineError::Panic {
                message: "lock poisoned".into(),
            })
    }

    pub(crate) fn read<T>(&self, f: impl FnOnce(&Inner) -> T) -> Result<T, EngineError> {
        self.inner
            .read()
            .map(|g| f(&g))
            .map_err(|_| EngineError::Panic {
                message: "lock poisoned".into(),
            })
    }
}

#[uniffi::export]
pub fn engine_start(config: EngineConfig) -> Arc<Engine> {
    let engine = Arc::new(Engine::new(config));
    engine.poll_index();
    watch::spawn(Arc::downgrade(&engine));
    engine
}

#[uniffi::export]
impl Engine {
    pub fn open_workspace(&self, path: String) -> Result<WorkspaceInfo, EngineError> {
        match catch_unwind(AssertUnwindSafe(|| {
            let config = self.read(|i| i.config.clone())?;
            let info = workspace_info(Path::new(&path), &config)?;
            self.write(|i| {
                i.last_status.rust_src_available = info.rust_src_available;
                i.workspace = Some(info.clone());
            })?;
            Ok(info)
        })) {
            Ok(r) => r,
            Err(p) => Err(EngineError::from_panic(p)),
        }
    }

    pub fn close_workspace(&self) {
        let _ = self.write(|i| {
            i.workspace = None;
            i.overlay.clear();
        });
    }

    pub fn status(&self) -> IndexStatus {
        self.read(|i| i.last_status.clone())
            .unwrap_or_else(|_| IndexStatus::idle(false))
    }

    pub fn set_status_listener(&self, listener: Arc<dyn IndexStatusListener>) {
        let status = self.status();
        let _ = self.write(|i| {
            i.listener = Some(listener.clone());
        });
        listener.on_status(status);
    }

    pub fn query_completions(&self, q: CompletionQuery) -> CompletionResponse {
        match catch_unwind(AssertUnwindSafe(|| query::run(self, q.clone()))) {
            Ok(resp) => resp,
            Err(_) => CompletionResponse::empty(q.query_id),
        }
    }

    pub fn workspace_file_changed(&self, path: String) {
        let _ = self.write(|i| {
            i.overlay.insert(path);
        });
    }
}
