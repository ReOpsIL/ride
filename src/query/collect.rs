use std::collections::HashMap;

use tantivy::collector::{Collector, SegmentCollector};
use tantivy::{DocAddress, DocId, Score, SegmentOrdinal, SegmentReader};

use super::rank::{Columns, Ranking};

pub struct BestPerName {
    pub limit: usize,
    pub ranking: Ranking,
}

pub struct BestPerNameSegment {
    ordinal: SegmentOrdinal,
    columns: Columns,
    ranking: Ranking,
    best: HashMap<u64, (f32, DocId)>,
}

impl Collector for BestPerName {
    type Fruit = Vec<(f32, DocAddress)>;
    type Child = BestPerNameSegment;

    fn for_segment(
        &self,
        ordinal: SegmentOrdinal,
        reader: &SegmentReader,
    ) -> tantivy::Result<Self::Child> {
        Ok(BestPerNameSegment {
            ordinal,
            columns: Columns::open(reader),
            ranking: self.ranking,
            best: HashMap::new(),
        })
    }

    fn requires_scoring(&self) -> bool {
        true
    }

    fn merge_fruits(
        &self,
        fruits: Vec<HashMap<u64, (f32, DocAddress)>>,
    ) -> tantivy::Result<Self::Fruit> {
        let mut merged: HashMap<u64, (f32, DocAddress)> = HashMap::new();
        for fruit in fruits {
            for (key, (score, addr)) in fruit {
                match merged.get(&key) {
                    Some((prev, _)) if *prev >= score => {}
                    _ => {
                        merged.insert(key, (score, addr));
                    }
                }
            }
        }
        let mut out: Vec<(f32, DocAddress)> = merged.into_values().collect();
        out.sort_by(|a, b| b.0.total_cmp(&a.0).then(a.1.cmp(&b.1)));
        out.truncate(self.limit);
        Ok(out)
    }
}

impl SegmentCollector for BestPerNameSegment {
    type Fruit = HashMap<u64, (f32, DocAddress)>;

    fn collect(&mut self, doc: DocId, bm25: Score) {
        let score = self.columns.score(doc, bm25, self.ranking);
        let key = self.columns.name_key(doc);
        match self.best.get(&key) {
            Some((prev, _)) if *prev >= score => {}
            _ => {
                self.best.insert(key, (score, doc));
            }
        }
    }

    fn harvest(self) -> Self::Fruit {
        let ordinal = self.ordinal;
        self.best
            .into_iter()
            .map(|(k, (score, doc))| (k, (score, DocAddress::new(ordinal, doc))))
            .collect()
    }
}
