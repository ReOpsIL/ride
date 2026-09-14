use std::fs;
use std::path::{Path, PathBuf};

use sha2::{Digest, Sha256};
use tantivy::collector::TopDocs;
use tantivy::query::TermQuery;
use tantivy::schema::IndexRecordOption;
use tantivy::schema::{Field, STORED, STRING, Schema, Value};
use tantivy::{Index, IndexWriter, TantivyDocument, Term};

use crate::error::EngineError;
use crate::index::{item_kind_from_label, item_kind_label};

use super::record::RefRecord;

const WRITER_MEMORY: usize = 15_000_000;
const MAX_HITS: usize = 20_000;

#[derive(Clone, Copy)]
struct RefFields {
    name_exact: Field,
    kind: Field,
    path: Field,
    line: Field,
    byte_start: Field,
    byte_end: Field,
    enclosing_item: Field,
    enclosing_kind: Field,
}

pub struct UsageRow {
    pub path: String,
    pub line: u32,
    pub byte_start: u32,
    pub byte_end: u32,
    pub enclosing_item: String,
    pub enclosing_kind: crate::ffi::ItemKind,
}

pub struct RefIndex {
    index: Index,
    fields: RefFields,
    writes: std::sync::Mutex<()>,
}

fn build_schema() -> (Schema, RefFields) {
    let mut b = Schema::builder();
    let fields = RefFields {
        name_exact: b.add_text_field("name_exact", STRING),
        kind: b.add_text_field("kind", STRING | STORED),
        path: b.add_text_field("path", STRING | STORED),
        line: b.add_u64_field("line", STORED),
        byte_start: b.add_u64_field("byte_start", STORED),
        byte_end: b.add_u64_field("byte_end", STORED),
        enclosing_item: b.add_text_field("enclosing_item", STRING | STORED),
        enclosing_kind: b.add_text_field("enclosing_kind", STRING | STORED),
    };
    (b.build(), fields)
}

pub fn ref_index_dir(index_dir: &Path, root: &Path) -> PathBuf {
    let support = index_dir.parent().unwrap_or(index_dir);
    let canonical = fs::canonicalize(root).unwrap_or_else(|_| root.to_path_buf());
    let mut hasher = Sha256::new();
    hasher.update(canonical.to_string_lossy().as_bytes());
    let digest = hasher.finalize().iter().fold(String::new(), |mut out, b| {
        use std::fmt::Write;
        let _ = write!(out, "{b:02x}");
        out
    });
    support.join("refs").join(digest)
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
        writer.delete_term(Term::from_field_text(self.fields.path, path));
        for r in records {
            writer.add_document(self.document(path, r)).map_err(tv)?;
        }
        writer.commit().map_err(tv)?;
        Ok(())
    }

    pub fn usages(&self, name: &str) -> Result<Vec<UsageRow>, EngineError> {
        let reader = self.index.reader().map_err(tv)?;
        let searcher = reader.searcher();
        let query = TermQuery::new(
            Term::from_field_text(self.fields.name_exact, name),
            IndexRecordOption::Basic,
        );
        let top = searcher
            .search(&query, &TopDocs::with_limit(MAX_HITS))
            .map_err(tv)?;
        let mut rows = Vec::with_capacity(top.len());
        for (_, addr) in top {
            let doc: TantivyDocument = searcher.doc(addr).map_err(tv)?;
            rows.push(self.row(&doc));
        }
        Ok(rows)
    }

    fn document(&self, path: &str, r: &RefRecord) -> TantivyDocument {
        let mut doc = TantivyDocument::default();
        doc.add_text(self.fields.name_exact, &r.name);
        doc.add_text(self.fields.kind, r.kind.label());
        doc.add_text(self.fields.path, path);
        doc.add_u64(self.fields.line, r.line as u64);
        doc.add_u64(self.fields.byte_start, r.byte_start as u64);
        doc.add_u64(self.fields.byte_end, r.byte_end as u64);
        doc.add_text(self.fields.enclosing_item, &r.enclosing_item);
        doc.add_text(
            self.fields.enclosing_kind,
            item_kind_label(r.enclosing_kind),
        );
        doc
    }

    fn row(&self, doc: &TantivyDocument) -> UsageRow {
        let text = |f: Field| {
            doc.get_first(f)
                .and_then(|v| v.as_str())
                .unwrap_or_default()
                .to_string()
        };
        let num = |f: Field| doc.get_first(f).and_then(|v| v.as_u64()).unwrap_or(0) as u32;
        UsageRow {
            path: text(self.fields.path),
            line: num(self.fields.line),
            byte_start: num(self.fields.byte_start),
            byte_end: num(self.fields.byte_end),
            enclosing_item: text(self.fields.enclosing_item),
            enclosing_kind: item_kind_from_label(&text(self.fields.enclosing_kind)),
        }
    }
}

fn tv(err: tantivy::TantivyError) -> EngineError {
    EngineError::Index {
        message: err.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::ref_index_dir;
    use std::path::Path;

    #[test]
    fn a_symlinked_root_hashes_to_the_canonical_dir() {
        let tmp = std::env::temp_dir().join("ride-refs-canon");
        let real = tmp.join("real");
        let link = tmp.join("link");
        std::fs::create_dir_all(&real).unwrap();
        let _ = std::fs::remove_file(&link);
        std::os::unix::fs::symlink(&real, &link).unwrap();
        let index_dir = tmp.join("support").join("index");
        let a = ref_index_dir(&index_dir, &real);
        let b = ref_index_dir(&index_dir, &link);
        assert_eq!(a, b);
        let c = ref_index_dir(&index_dir, Path::new(&format!("{}/", real.display())));
        assert_eq!(a, c);
    }
}
