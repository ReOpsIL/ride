use tree_sitter::{Parser, Query, Tree};

use crate::error::EngineError;
use crate::ffi::{ByteRange, CompletionHit, InputEditFfi, OutlineItem, SessionUpdate};

use super::edit::{apply_replica, rust_parser, to_ts_edit};
use super::errors;
use super::locals;
use super::outline;
use super::paint::{HUGE, clip_changed, expand, paint_range};
use super::ranges::{from_ts, subtract, union_into};
use super::spans;

pub struct BufferSession {
    pub generation: u64,
    replica: String,
    tree: Tree,
    parser: Parser,
    query: Query,
    already_covered: Vec<ByteRange>,
    last_outline: Vec<OutlineItem>,
}

impl BufferSession {
    pub fn replica(&self) -> &str {
        &self.replica
    }

    pub fn outline(&self) -> &[OutlineItem] {
        &self.last_outline
    }

    pub fn local_hits(&self, prefix: &str, limit: u32) -> Vec<CompletionHit> {
        locals::hits(&self.tree, &self.replica, &self.last_outline, prefix, limit)
    }

    pub fn open(
        text: String,
        visible: Option<ByteRange>,
    ) -> Result<(Self, SessionUpdate), EngineError> {
        let mut parser = rust_parser()?;
        let tree = parser
            .parse(&text, None)
            .ok_or_else(|| EngineError::InvalidEdit {
                message: "parse returned none".into(),
            })?;
        let query = spans::query().map_err(|message| EngineError::InvalidEdit { message })?;
        let painted = paint_range(text.len(), visible);
        let highlights = spans::highlights(&query, &tree, &text, &painted);
        let outline = outline::from_source(&text).unwrap_or_default();
        let errs = errors::collect(tree.root_node());
        let session = Self {
            generation: 1,
            replica: text,
            tree,
            parser,
            query,
            already_covered: painted.clone(),
            last_outline: outline.clone(),
        };
        Ok((
            session,
            SessionUpdate {
                session_generation: 1,
                changed: painted,
                highlights,
                outline: Some(outline),
                errors: errs,
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
        self.tree.edit(&to_ts_edit(&edit));
        let new_tree = self
            .parser
            .parse(&self.replica, Some(&self.tree))
            .ok_or_else(|| EngineError::InvalidEdit {
                message: "parse returned none".into(),
            })?;
        let changed: Vec<ByteRange> = self
            .tree
            .changed_ranges(&new_tree)
            .map(|r| from_ts(r.start_byte, r.end_byte))
            .collect();
        self.tree = new_tree;
        self.generation += 1;
        self.already_covered = subtract(&self.already_covered, &changed);
        let to_style = clip_changed(&changed, visible, self.replica.len());
        union_into(&mut self.already_covered, &to_style);
        let highlights = spans::highlights(&self.query, &self.tree, &self.replica, &to_style);
        let new_outline = outline::from_source(&self.replica).unwrap_or_default();
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
            errors: errors::collect(self.tree.root_node()),
        })
    }

    pub fn set_text(
        &mut self,
        text: String,
        visible: Option<ByteRange>,
    ) -> Result<SessionUpdate, EngineError> {
        self.replica = text;
        self.tree =
            self.parser
                .parse(&self.replica, None)
                .ok_or_else(|| EngineError::InvalidEdit {
                    message: "parse returned none".into(),
                })?;
        self.generation += 1;
        self.already_covered.clear();
        let painted = paint_range(self.replica.len(), visible);
        union_into(&mut self.already_covered, &painted);
        let outline = outline::from_source(&self.replica).unwrap_or_default();
        self.last_outline = outline.clone();
        Ok(SessionUpdate {
            session_generation: self.generation,
            changed: painted.clone(),
            highlights: spans::highlights(&self.query, &self.tree, &self.replica, &painted),
            outline: Some(outline),
            errors: errors::collect(self.tree.root_node()),
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
            highlights: spans::highlights(&self.query, &self.tree, &self.replica, &fresh),
            outline: None,
            errors: errors::collect(self.tree.root_node()),
        })
    }
}
