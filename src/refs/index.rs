use std::fs;
use std::path::Path;

use tantivy::collector::{Count, TopDocs};
use tantivy::query::Query;
use tantivy::{Index, IndexWriter, TantivyDocument};

use crate::error::EngineError;

use super::record::{RefKind, RefRecord};
use super::schema::{RefFields, UsageRow, build_schema};

const WRITER_MEMORY: usize = 15_000_000;
const MAX_HITS: usize = 20_000;

pub struct RefIndex {
    index: Index,
    fields: RefFields,
    writes: std::sync::Mutex<()>,
}

impl RefIndex {
    pub fn open(dir: &Path) -> Result<Self, EngineError> {
        fs::create_dir_all(dir).map_err(|e| EngineError::io(dir, e))?;
        let (schema, fields) = build_schema();
        let index = match Index::open_in_dir(dir) {
            Ok(index) => index,
            Err(_) => Index::create_in_dir(dir, schema).map_err(tv)?,
        };
        Ok(Self {
            index,
            fields,
            writes: std::sync::Mutex::new(()),
        })
    }

    pub fn update_file(&self, path: &str, records: &[RefRecord]) -> Result<(), EngineError> {
        let _guard = self.writes.lock().map_err(|_| EngineError::Index {
            message: "refs write lock poisoned".into(),
        })?;
        let mut writer: IndexWriter = self
            .index
            .writer_with_num_threads(1, WRITER_MEMORY)
            .map_err(tv)?;
        writer.delete_term(self.fields.path_term(path));
        for r in records {
            writer
                .add_document(self.fields.document(path, r))
                .map_err(tv)?;
        }
        writer.commit().map_err(tv)?;
        Ok(())
    }

    pub fn usages(&self, name: &str) -> Result<Vec<UsageRow>, EngineError> {
        self.rows(self.fields.name_query(name))
    }

    pub fn usages_of_kind(&self, name: &str, kind: RefKind) -> Result<Vec<UsageRow>, EngineError> {
        self.rows(self.fields.name_kind_query(name, kind))
    }

    pub fn count(&self, name: &str) -> Result<u32, EngineError> {
        let reader = self.index.reader().map_err(tv)?;
        let query = self.fields.name_query(name);
        let n = reader
            .searcher()
            .search(query.as_ref(), &Count)
            .map_err(tv)?;
        Ok(n as u32)
    }

    fn rows(&self, query: Box<dyn Query>) -> Result<Vec<UsageRow>, EngineError> {
        let reader = self.index.reader().map_err(tv)?;
        let searcher = reader.searcher();
        let top = searcher
            .search(query.as_ref(), &TopDocs::with_limit(MAX_HITS))
            .map_err(tv)?;
        let mut rows = Vec::with_capacity(top.len());
        for (_, addr) in top {
            let doc: TantivyDocument = searcher.doc(addr).map_err(tv)?;
            rows.push(self.fields.row(&doc));
        }
        Ok(rows)
    }
}

fn tv(err: tantivy::TantivyError) -> EngineError {
    EngineError::Index {
        message: err.to_string(),
    }
}
