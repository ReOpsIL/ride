use crate::ffi::{BracketPair, ByteRange, CalleeHit, FoldRange, SymbolAt, TextEdit};
use crate::intentions::MatchSite;
use crate::refactor::{ConstantSpans, ExtractSpans, InlineSpans};

use super::call_site::CallSite;
use super::context::Context;
use super::session::BufferSession;
use super::site::SiteAt;
use super::syntax::{Lang, LocalHits, LocalQuery};

impl BufferSession {
    pub fn local_hits(&self, q: &LocalQuery<'_>) -> LocalHits {
        self.syntax.local_hits(&self.replica, &self.last_outline, q)
    }

    pub fn site_at(&self, byte: u32) -> SiteAt {
        self.syntax.site_at(&self.replica, byte as usize)
    }

    pub fn context_at(&self, byte: u32) -> Context {
        self.syntax.context_at(&self.replica, byte as usize)
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

    pub fn call_site(&self, byte: u32) -> Option<CallSite> {
        super::call_site::find(&self.replica, byte as usize)
    }

    pub fn postfix_receiver(&self, replace_start: usize) -> Option<(usize, usize)> {
        self.syntax.postfix_receiver(&self.replica, replace_start)
    }

    pub fn symbol_at(&self, byte: u32) -> Option<SymbolAt> {
        self.syntax.symbol_at(&self.replica, byte)
    }

    pub fn local_occurrences(&self, byte: u32) -> Vec<ByteRange> {
        self.syntax.local_occurrences(&self.replica, byte)
    }

    pub fn callees(&self, byte: u32) -> Vec<CalleeHit> {
        self.syntax.callees(&self.replica, &self.last_outline, byte)
    }

    pub fn extract_spans(&self, range: ByteRange) -> Option<ExtractSpans> {
        self.syntax.extract_spans(&self.replica, range)
    }

    pub fn constant_spans(&self, range: ByteRange) -> Option<ConstantSpans> {
        self.syntax.constant_spans(&self.replica, range)
    }

    pub fn inline_spans(&self, byte: u32) -> Option<InlineSpans> {
        self.syntax.inline_spans(&self.replica, byte)
    }

    pub fn match_site(&self, byte: u32) -> Option<MatchSite> {
        self.syntax.match_site(&self.replica, byte)
    }

    pub fn enclosing_ranges(&self, range: ByteRange) -> Vec<ByteRange> {
        self.syntax.enclosing_ranges(&self.replica, range)
    }

    pub fn fold_ranges(&self) -> Vec<FoldRange> {
        self.syntax.fold_ranges(&self.replica)
    }

    pub fn bracket_pair(&self, byte: u32) -> Option<BracketPair> {
        self.syntax.bracket_pair(&self.replica, byte as usize)
    }

    pub fn statement_range(&self, byte: u32) -> Option<ByteRange> {
        self.syntax.statement_range(&self.replica, byte)
    }

    pub fn sibling_statement(&self, byte: u32, up: bool) -> Option<ByteRange> {
        self.syntax.sibling_statement(&self.replica, byte, up)
    }

    pub fn complete_statement(&self, byte: u32) -> TextEdit {
        self.syntax.complete_statement(&self.replica, byte)
    }
}
