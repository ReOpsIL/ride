use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, OnceLock};

use crate::discover::SystemIncludes;
use crate::highlight::{BufferSession, Lang, SourceScope};

use super::headers::{Header, HeaderCache};
use super::{Engine, Inner, include_graph};

type Headers = Arc<Vec<Arc<Header>>>;

#[derive(Default)]
pub struct ScopeCache {
    entries: HashMap<u64, (Arc<SourceScope>, Headers)>,
}

impl ScopeCache {
    fn get(&self, session: u64, scope: &SourceScope, cache: &HeaderCache) -> Option<Headers> {
        let (cached_scope, headers) = self.entries.get(&session)?;
        if !cached_scope.same_includes(scope) {
            return None;
        }
        let unchanged = headers
            .iter()
            .filter(|h| !h.system)
            .all(|h| cache.load(&h.path).is_some_and(|now| Arc::ptr_eq(&now, h)));
        unchanged.then(|| headers.clone())
    }

    fn put(&mut self, session: u64, scope: Arc<SourceScope>, headers: Headers) {
        self.entries.insert(session, (scope, headers));
    }

    pub fn remove(&mut self, session: u64) {
        self.entries.remove(&session);
    }
}

pub struct Reach {
    session: u64,
    lang: Lang,
    scope: Arc<SourceScope>,
    cache: Arc<HeaderCache>,
    system: Arc<SystemIncludes>,
    cached: Option<Headers>,
    fresh: OnceLock<Headers>,
}

impl Reach {
    pub fn take(inner: &Inner, session_id: u64, session: &BufferSession) -> Self {
        let scope = session.scope();
        let cached = inner.scopes.get(session_id, &scope, &inner.headers);
        Self {
            session: session_id,
            lang: session.lang(),
            scope,
            cache: inner.headers.clone(),
            system: inner.system_includes.clone(),
            cached,
            fresh: OnceLock::new(),
        }
    }

    pub fn scope(&self) -> &Arc<SourceScope> {
        &self.scope
    }

    pub fn headers(&self) -> &[Arc<Header>] {
        if let Some(cached) = &self.cached {
            return cached;
        }
        self.fresh.get_or_init(|| {
            let system = self.system_dirs();
            Arc::new(include_graph::reachable(&self.cache, &self.scope, &system))
        })
    }

    fn system_dirs(&self) -> Vec<PathBuf> {
        if self.scope.includes.is_empty() {
            return Vec::new();
        }
        self.lang
            .clang_name()
            .map(|lang| self.system.dirs(lang, &[]))
            .unwrap_or_default()
    }

    pub fn remember(&self, engine: &Engine) {
        if let Some(fresh) = self.fresh.get() {
            let _ = engine.write(|i| {
                i.scopes
                    .put(self.session, self.scope.clone(), fresh.clone())
            });
        }
    }
}
