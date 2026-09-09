use tantivy::collector::{Collector, TopDocs};
use tantivy::fastfield::Column;
use tantivy::{DocAddress, DocId, Score, SegmentReader};

pub const EXACT: f32 = 1000.0;
pub const KEYWORD: f32 = 500.0;
const SCOPE_BONUS: [f32; 5] = [400.0, 300.0, 300.0, 150.0, 0.0];
const LEN_CAP: u64 = 40;

pub fn length_bonus(len: u64) -> f32 {
    LEN_CAP.saturating_sub(len) as f32
}

pub fn collector(fetch: usize, prefix_len: u64) -> impl Collector<Fruit = Vec<(f32, DocAddress)>> {
    TopDocs::with_limit(fetch).tweak_score(move |seg: &SegmentReader| {
        let cols = Columns::open(seg);
        move |doc: DocId, bm25: Score| cols.score(doc, bm25, prefix_len)
    })
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
            kind: ff.u64("kind_weight").ok(),
            len: ff.u64("name_len").ok(),
        }
    }

    fn score(&self, doc: DocId, bm25: Score, prefix_len: u64) -> f32 {
        let scope = first(&self.scope, doc).unwrap_or(4) as usize;
        let kind = first(&self.kind, doc).unwrap_or(0) as f32;
        let len = first(&self.len, doc).unwrap_or(LEN_CAP);
        let exact = if len == prefix_len { EXACT } else { 0.0 };
        exact + SCOPE_BONUS[scope.min(4)] + kind + length_bonus(len) + bm25
    }
}

fn first(col: &Option<Column<u64>>, doc: DocId) -> Option<u64> {
    col.as_ref().and_then(|c| c.first(doc))
}
