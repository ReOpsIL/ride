use std::path::Path;

use tantivy::{Index, IndexReader};

use crate::index::live_index_dir;

pub enum IndexSrc<'a> {
    Dir(&'a Path),
    Live(&'a Index, &'a IndexReader),
}

impl IndexSrc<'_> {
    pub fn with<T>(&self, missing: T, run: impl FnOnce(&Index, &IndexReader) -> T) -> T {
        match self {
            IndexSrc::Live(index, reader) => run(index, reader),
            IndexSrc::Dir(dir) => match open_dir(dir) {
                Some((index, reader)) => run(&index, &reader),
                None => missing,
            },
        }
    }
}

fn open_dir(index_dir: &Path) -> Option<(Index, IndexReader)> {
    let live = live_index_dir(index_dir)?;
    let index = Index::open_in_dir(live).ok()?;
    let reader = index.reader().ok()?;
    Some((index, reader))
}
