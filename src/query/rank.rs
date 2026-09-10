use tantivy::fastfield::Column;
use tantivy::{DocId, Score, SegmentReader};

use crate::ffi::{CompletionContext, ItemKind};
use crate::index::kind_from_rank;
use crate::score::DEPRECATED_PENALTY;

pub use crate::score::{EXACT, KEYWORD, kind_weight, length_bonus};

const SCOPE_BONUS: [f32; 5] = [400.0, 300.0, 300.0, 150.0, 0.0];
const EXACT_SCALE: [f32; 5] = [1.0, 0.8, 0.8, 0.15, 0.05];
const LEN_CAP: u64 = 40;
const PATH_PENALTY: f32 = 0.1;
const DOC_BONUS: f32 = 5.0;

#[derive(Clone, Copy)]
pub struct Ranking {
    pub prefix_len: u64,
    pub context: CompletionContext,
}

pub fn context_bonus(context: CompletionContext, kind: ItemKind) -> f32 {
    use ItemKind::*;
    match (context, kind) {
        (CompletionContext::TypePosition, Struct | Enum | Trait | Union | Type) => 60.0,
        (CompletionContext::TypePosition, Mod | Crate) => 20.0,
        (CompletionContext::ValuePosition, Fn | Const | Static | Macro) => 40.0,
        (CompletionContext::ValuePosition, Struct | Enum | Variant) => 20.0,
        (CompletionContext::MemberAccess, Method | Field) => 80.0,
        _ => 0.0,
    }
}

pub struct Columns {
    scope: Option<Column<u64>>,
    kind: Option<Column<u64>>,
    len: Option<Column<u64>>,
    name: Option<Column<u64>>,
    path: Option<Column<u64>>,
    doc: Option<Column<u64>>,
    reachable: Option<Column<u64>>,
    deprecated: Option<Column<u64>>,
}

impl Columns {
    pub fn open(seg: &SegmentReader) -> Self {
        let ff = seg.fast_fields();
        Self {
            scope: ff.u64("scope_rank").ok(),
            kind: ff.u64("kind_rank").ok(),
            len: ff.u64("name_len").ok(),
            name: ff.u64("name_hash").ok(),
            path: ff.u64("path_len").ok(),
            doc: ff.u64("has_doc").ok(),
            reachable: ff.u64("reachable").ok(),
            deprecated: ff.u64("deprecated").ok(),
        }
    }

    pub fn name_key(&self, doc: DocId) -> u64 {
        first(&self.name, doc).unwrap_or(u64::from(doc))
    }

    pub fn reachable(&self, doc: DocId) -> bool {
        first(&self.reachable, doc).unwrap_or(1) == 1
    }

    pub fn score(&self, doc: DocId, bm25: Score, ranking: Ranking) -> f32 {
        let scope = (first(&self.scope, doc).unwrap_or(4) as usize).min(4);
        let kind = kind_from_rank(first(&self.kind, doc).unwrap_or(12));
        let len = first(&self.len, doc).unwrap_or(LEN_CAP);
        let path = first(&self.path, doc).unwrap_or(0) as f32;
        let documented = first(&self.doc, doc).unwrap_or(0) as f32;
        let deprecated = first(&self.deprecated, doc).unwrap_or(0) as f32;
        let exact = if len == ranking.prefix_len {
            EXACT * EXACT_SCALE[scope]
        } else {
            0.0
        };
        exact
            + SCOPE_BONUS[scope]
            + kind_weight(kind)
            + context_bonus(ranking.context, kind)
            + length_bonus(len)
            - PATH_PENALTY * path
            + DOC_BONUS * documented
            - DEPRECATED_PENALTY * deprecated
            + bm25
    }
}

fn first(col: &Option<Column<u64>>, doc: DocId) -> Option<u64> {
    col.as_ref().and_then(|c| c.first(doc))
}
