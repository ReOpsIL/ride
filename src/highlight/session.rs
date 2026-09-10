use std::path::{Path, PathBuf};
use std::sync::Arc;

use crate::error::EngineError;
use crate::ffi::{ByteRange, InputEditFfi, OutlineItem, SessionUpdate, SymbolAt, TextEdit};

use super::edit::{apply_replica, to_ts_edit};
use super::paint::{HUGE, clip_changed, expand, paint_range};
use super::ranges::{subtract, union_into};
use super::scope::{ScopeCache, SourceScope};
use super::site::SiteAt;
use super::syntax::{Lang, LocalHits, LocalQuery, Syntax};

pub struct BufferSession {
    pub generation: u64,
    edits: u64,
    lang: Lang,
    path: Option<PathBuf>,
    search_dirs: Vec<PathBuf>,
    replica: String,
    syntax: Box<dyn Syntax>,
    already_covered: Vec<ByteRange>,
    last_outline: Vec<OutlineItem>,
    scope_cache: ScopeCache,
}

impl BufferSession {
    pub fn replica(&self) -> &str {
        &self.replica
    }

    pub fn lang(&self) -> Lang {
        self.lang
    }

    pub fn outline(&self) -> &[OutlineItem] {
        &self.last_outline
    }

    pub fn locate(&mut self, path: &Path, search_dirs: Vec<PathBuf>) {
        self.path = Some(path.to_path_buf());
        self.search_dirs = search_dirs;
        self.edits += 1;
    }

    pub fn scope(&self) -> Arc<SourceScope> {
        self.scope_cache.get_or_build(self.edits, || SourceScope {
            path: self.path.clone(),
            search_dirs: self.search_dirs.clone(),
            includes: self.syntax.includes(&self.replica),
            types: self.syntax.type_table(&self.replica),
        })
    }

    pub fn local_hits(&self, q: &LocalQuery<'_>) -> LocalHits {
        self.syntax.local_hits(&self.replica, &self.last_outline, q)
    }

    pub fn site_at(&self, byte: u32) -> SiteAt {
        self.syntax.site_at(&self.replica, byte as usize)
    }

    pub fn imports(&self) -> Vec<String> {
        self.syntax.imports(&self.replica)
    }

    pub fn import_edit(&self, import_path: &str) -> Option<TextEdit> {
        if self.lang != Lang::Rust {
            return None;
        }
        super::rust_import::edit(&self.replica, import_path)
    }

    pub fn call_site(&self, byte: u32) -> Option<super::call_site::CallSite> {
        super::call_site::find(&self.replica, byte as usize)
    }

    pub fn postfix_receiver(&self, replace_start: usize) -> Option<(usize, usize)> {
        self.syntax.postfix_receiver(&self.replica, replace_start)
    }

    pub fn symbol_at(&self, byte: u32) -> Option<SymbolAt> {
        self.syntax.symbol_at(&self.replica, byte)
    }

    pub fn open(
        text: String,
        visible: Option<ByteRange>,
    ) -> Result<(Self, SessionUpdate), EngineError> {
        Self::open_lang(Lang::Rust, text, visible)
    }

    pub fn open_lang(
        lang: Lang,
        text: String,
        visible: Option<ByteRange>,
    ) -> Result<(Self, SessionUpdate), EngineError> {
        let mut syntax = super::syntax::make(lang)?;
        syntax.parse_full(&text)?;
        let painted = paint_range(text.len(), visible);
        let highlights = syntax.highlights(&text, &painted);
        let outline = syntax.outline(&text);
        let errors = syntax.errors();
        let session = Self {
            generation: 1,
            edits: 1,
            lang,
            path: None,
            search_dirs: Vec::new(),
            replica: text,
            syntax,
            already_covered: painted.clone(),
            last_outline: outline.clone(),
            scope_cache: ScopeCache::default(),
        };
        Ok((
            session,
            SessionUpdate {
                session_generation: 1,
                changed: painted,
                highlights,
                outline: Some(outline),
                errors,
            },
        ))
    }

    pub fn apply_edit(
        &mut self,
        edit: InputEditFfi,
        inserted: &str,
        visible: Option<ByteRange>,
    ) -> Result<SessionUpdate, EngineError> {
        apply_replica(&mut self.replica, &edit, inserted)?;
        let changed = self.syntax.edit(&to_ts_edit(&edit), &self.replica)?;
        self.generation += 1;
        self.edits += 1;
        self.already_covered = subtract(&self.already_covered, &changed);
        let to_style = clip_changed(&changed, visible, self.replica.len());
        union_into(&mut self.already_covered, &to_style);
        let highlights = self.syntax.highlights(&self.replica, &to_style);
        let new_outline = self.syntax.outline(&self.replica);
        let outline = if new_outline != self.last_outline {
            self.last_outline = new_outline.clone();
            Some(new_outline)
        } else {
            None
        };
        Ok(SessionUpdate {
            session_generation: self.generation,
            changed,
            highlights,
            outline,
            errors: self.syntax.errors(),
        })
    }

    pub fn set_text(
        &mut self,
        text: String,
        visible: Option<ByteRange>,
    ) -> Result<SessionUpdate, EngineError> {
        self.replica = text;
        self.syntax.parse_full(&self.replica)?;
        self.generation += 1;
        self.edits += 1;
        self.already_covered.clear();
        let painted = paint_range(self.replica.len(), visible);
        union_into(&mut self.already_covered, &painted);
        let outline = self.syntax.outline(&self.replica);
        self.last_outline = outline.clone();
        Ok(SessionUpdate {
            session_generation: self.generation,
            changed: painted.clone(),
            highlights: self.syntax.highlights(&self.replica, &painted),
            outline: Some(outline),
            errors: self.syntax.errors(),
        })
    }

    pub fn set_visible(&mut self, visible: ByteRange) -> Result<SessionUpdate, EngineError> {
        self.generation += 1;
        let fresh = if self.replica.len() < HUGE {
            Vec::new()
        } else {
            subtract(
                &[expand(visible, self.replica.len())],
                &self.already_covered,
            )
        };
        union_into(&mut self.already_covered, &fresh);
        Ok(SessionUpdate {
            session_generation: self.generation,
            changed: fresh.clone(),
            highlights: self.syntax.highlights(&self.replica, &fresh),
            outline: None,
            errors: self.syntax.errors(),
        })
    }
}
