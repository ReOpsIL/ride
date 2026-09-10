use std::path::PathBuf;
use std::sync::{Arc, Mutex};

use super::includes::IncludeRef;
use super::types::TypeTable;

#[derive(Debug, Clone, Default)]
pub struct SourceScope {
    pub path: Option<PathBuf>,
    pub search_dirs: Vec<PathBuf>,
    pub includes: Vec<IncludeRef>,
    pub types: TypeTable,
}

impl SourceScope {
    pub fn same_includes(&self, other: &SourceScope) -> bool {
        self.path == other.path
            && self.search_dirs == other.search_dirs
            && self.includes == other.includes
    }
}

#[derive(Default)]
pub struct ScopeCache {
    slot: Mutex<Option<(u64, Arc<SourceScope>)>>,
}

impl ScopeCache {
    pub fn get_or_build(
        &self,
        generation: u64,
        build: impl FnOnce() -> SourceScope,
    ) -> Arc<SourceScope> {
        let Ok(mut slot) = self.slot.lock() else {
            return Arc::new(build());
        };
        if let Some((cached_generation, scope)) = slot.as_ref()
            && *cached_generation == generation
        {
            return scope.clone();
        }
        let scope = Arc::new(build());
        *slot = Some((generation, scope.clone()));
        scope
    }
}
