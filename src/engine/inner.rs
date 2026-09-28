use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};
use std::sync::Arc;

use tantivy::{Index, IndexReader};

use crate::ffi::{EngineConfig, IndexStatus, IndexStatusListener, ProjectModel};
use crate::highlight::BufferSession;
use crate::oracle::Oracle;

use super::bound_refs::BoundRefs;
use super::headers::HeaderCache;
use super::index_watch::IndexWatch;
use super::open_workspace::OpenWorkspace;
use super::reach::ScopeCache;

pub(crate) struct Inner {
    pub(crate) config: EngineConfig,
    pub(crate) workspace: Option<OpenWorkspace>,
    pub(crate) sessions: HashMap<u64, BufferSession>,
    pub(crate) next_session_id: u64,
    pub(crate) overlay: HashSet<String>,
    pub(crate) latest_query_id: HashMap<u64, u64>,
    pub(crate) listener: Option<Arc<dyn IndexStatusListener>>,
    pub(crate) last_status: IndexStatus,
    pub(crate) watch: IndexWatch,
    pub(crate) index: Option<Index>,
    pub(crate) reader: Option<IndexReader>,
    pub(crate) headers: Arc<HeaderCache>,
    pub(crate) scopes: ScopeCache,
    pub(crate) system_includes: Arc<crate::discover::SystemIncludes>,
    pub(crate) projects: HashMap<String, ProjectModel>,
    pub(crate) cargo_roots: HashMap<PathBuf, PathBuf>,
    pub(crate) debug_sessions: Arc<crate::debug::registry::DebugRegistry>,
    pub(crate) sysroot: Option<PathBuf>,
    pub(crate) refs: Option<BoundRefs>,
    pub(crate) oracle: Arc<Oracle>,
}

impl Inner {
    pub(crate) fn new(config: EngineConfig) -> Self {
        let sysroot = crate::discover::sysroot_path(&config).ok().flatten();
        let rust_src = crate::discover::rust_src_available(sysroot.as_deref());
        let header_store = Path::new(&config.index_dir).join("headers");
        Self {
            config,
            workspace: None,
            sessions: HashMap::new(),
            next_session_id: 1,
            overlay: HashSet::new(),
            latest_query_id: HashMap::new(),
            listener: None,
            last_status: IndexStatus::idle(rust_src),
            watch: IndexWatch::default(),
            index: None,
            reader: None,
            headers: Arc::new(HeaderCache::new(Some(header_store))),
            scopes: ScopeCache::default(),
            system_includes: Arc::default(),
            projects: HashMap::new(),
            cargo_roots: HashMap::new(),
            debug_sessions: Arc::default(),
            sysroot,
            refs: None,
            oracle: Arc::default(),
        }
    }

    pub(crate) fn workspace_root(&self) -> Option<PathBuf> {
        self.workspace.as_ref().map(|w| PathBuf::from(&w.info.root))
    }
}
