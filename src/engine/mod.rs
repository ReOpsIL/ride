use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::Path;
use std::sync::{Arc, PoisonError, RwLock};

use crate::error::EngineError;
use crate::ffi::{CompletionQuery, CompletionResponse, EngineConfig};

pub(crate) use inner::Inner;

mod access;
mod bound_refs;
mod build_output;
mod catalog;
mod cheat;
mod debug;
mod def_rank;
mod definition;
mod delete_span;
mod doc_block;
mod doc_comment;
mod doc_html;
mod doc_links;
mod docs;
mod doxygen;
mod editing;
mod edits;
mod excerpt;
mod generate;
mod header_hits;
mod header_store;
mod header_sweep;
pub(crate) mod headers;
mod hierarchy;
mod hit_source;
mod identifier;
mod include_def;
pub(crate) mod include_graph;
mod include_intentions;
mod includes;
mod index_watch;
mod inner;
mod intentions;
mod lists;
mod live_refs;
mod local_defs;
mod merge;
mod open_workspace;
mod paths;
mod postfix;
mod project;
mod query;
mod reach;
mod refactor;
mod refs;
mod rel_path;
mod rename;
mod run;
mod rust_members;
mod safe_delete;
mod sessions;
mod signature;
mod snapshot;
mod snippets;
mod struct_literal;
mod symbols;
mod system_paths;
mod test_runner;
mod tools;
mod usages;
mod variant_hits;
mod watch;
mod workspace;

#[derive(uniffi::Object)]
pub struct Engine {
    inner: RwLock<Inner>,
}

impl Engine {
    fn new(config: EngineConfig) -> Self {
        Self {
            inner: RwLock::new(Inner::new(config)),
        }
    }

    pub(crate) fn write<T>(&self, f: impl FnOnce(&mut Inner) -> T) -> Result<T, EngineError> {
        let mut inner = self.inner.write().unwrap_or_else(PoisonError::into_inner);
        Ok(f(&mut inner))
    }

    pub(crate) fn read<T>(&self, f: impl FnOnce(&Inner) -> T) -> Result<T, EngineError> {
        let inner = self.inner.read().unwrap_or_else(PoisonError::into_inner);
        Ok(f(&inner))
    }

    pub(crate) fn guard<T>(
        &self,
        f: impl FnOnce() -> Result<T, EngineError>,
    ) -> Result<T, EngineError> {
        match catch_unwind(AssertUnwindSafe(f)) {
            Ok(result) => result,
            Err(payload) => Err(EngineError::from_panic(payload)),
        }
    }
}

#[uniffi::export]
pub fn engine_start(config: EngineConfig) -> Arc<Engine> {
    crate::process::ignore_sigpipe();
    if let Some(dir) = config.report_dir.as_deref() {
        crate::report::install_panic_hook(Path::new(dir));
    }
    let engine = Arc::new(Engine::new(config));
    engine.poll_index();
    watch::spawn(Arc::downgrade(&engine));
    engine.sweep_header_store();
    engine
}

#[uniffi::export]
impl Engine {
    pub fn query_completions(&self, q: CompletionQuery) -> CompletionResponse {
        match catch_unwind(AssertUnwindSafe(|| query::run(self, q.clone()))) {
            Ok(resp) => resp,
            Err(_) => CompletionResponse::empty(q.query_id),
        }
    }
}
