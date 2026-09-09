use tantivy::collector::{Collector, TopDocs};
use tantivy::fastfield::Column;
use tantivy::{DocAddress, DocId, Score, SegmentReader};

use crate::ffi::{CompletionContext, ItemKind};
use crate::index::kind_from_rank;

pub const EXACT: f32 = 1000.0;
pub const KEYWORD: f32 = 500.0;
const SCOPE_BONUS: [f32; 5] = [400.0, 300.0, 300.0, 150.0, 0.0];
const LEN_CAP: u64 = 40;

#[derive(Clone, Copy)]
pub struct Ranking {
    pub prefix_len: u64,
    pub context: CompletionContext,
}

pub fn length_bonus(len: u64) -> f32 {
    LEN_CAP.saturating_sub(len) as f32
}

pub fn collector(fetch: usize, ranking: Ranking) -> impl Collector<Fruit = Vec<(f32, DocAddress)>> {
    TopDocs::with_limit(fetch).tweak_score(move |seg: &SegmentReader| {
        let cols = Columns::open(seg);
        move |doc: DocId, bm25: Score| cols.score(doc, bm25, ranking)
    })
}

pub fn kind_weight(kind: ItemKind) -> f32 {
    match kind {
        ItemKind::Struct | ItemKind::Enum | ItemKind::Trait | ItemKind::Union | ItemKind::Type => {
            40.0
        }
        ItemKind::Fn | ItemKind::Macro => 35.0,
        ItemKind::Mod | ItemKind::Crate => 30.0,
        ItemKind::Method => 20.0,
        ItemKind::Const | ItemKind::Static => 10.0,
        ItemKind::Keyword | ItemKind::Local => 0.0,
    }
}

pub fn context_bonus(context: CompletionContext, kind: ItemKind) -> f32 {
    use ItemKind::*;
    match (context, kind) {
        (CompletionContext::TypePosition, Struct | Enum | Trait | Union | Type) => 60.0,
        (CompletionContext::TypePosition, Mod | Crate) => 20.0,
        (CompletionContext::ValuePosition, Fn | Const | Static | Macro) => 40.0,
        (CompletionContext::ValuePosition, Struct | Enum) => 20.0,
        (CompletionContext::MemberAccess, Method) => 80.0,
        _ => 0.0,
    }
}

struct Columns {
    scope: Option<Column<u64>>,
    kind: Option<Column<u64>>,
    len: Option<Column<u64>>,
}

impl Columns {
    fn open(seg: &SegmentReader) -> Self {
        let ff = seg.fast_fields();
        Self {
            scope: ff.u64("scope_rank").ok(),
            kind: ff.u64("kind_rank").ok(),
            len: ff.u64("name_len").ok(),
        }
    }

    fn score(&self, doc: DocId, bm25: Score, ranking: Ranking) -> f32 {
        let scope = first(&self.scope, doc).unwrap_or(4) as usize;
        let kind = kind_from_rank(first(&self.kind, doc).unwrap_or(12));
        let len = first(&self.len, doc).unwrap_or(LEN_CAP);
        let exact = if len == ranking.prefix_len {
            EXACT
        } else {
            0.0
        };
        exact
            + SCOPE_BONUS[scope.min(4)]
            + kind_weight(kind)
            + context_bonus(ranking.context, kind)
            + length_bonus(len)
            + bm25
    }
}

fn first(col: &Option<Column<u64>>, doc: DocId) -> Option<u64> {
    col.as_ref().and_then(|c| c.first(doc))
}
