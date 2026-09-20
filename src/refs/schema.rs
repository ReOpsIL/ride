use tantivy::query::{BooleanQuery, Occur, Query, TermQuery};
use tantivy::schema::IndexRecordOption;
use tantivy::schema::{Field, STORED, STRING, Schema, Value};
use tantivy::{TantivyDocument, Term};

use crate::ffi::ItemKind;
use crate::index::{item_kind_from_label, item_kind_label};

use super::record::{RefKind, RefRecord};

#[derive(Clone, Copy)]
pub struct RefFields {
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
    pub kind: RefKind,
    pub path: String,
    pub line: u32,
    pub byte_start: u32,
    pub byte_end: u32,
    pub enclosing_item: String,
    pub enclosing_kind: ItemKind,
}

pub fn build_schema() -> (Schema, RefFields) {
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

impl RefFields {
    pub fn path_term(&self, path: &str) -> Term {
        Term::from_field_text(self.path, path)
    }

    pub fn name_query(&self, name: &str) -> Box<dyn Query> {
        Box::new(TermQuery::new(
            Term::from_field_text(self.name_exact, name),
            IndexRecordOption::Basic,
        ))
    }

    pub fn name_kind_query(&self, name: &str, kind: RefKind) -> Box<dyn Query> {
        let kind = TermQuery::new(
            Term::from_field_text(self.kind, kind.label()),
            IndexRecordOption::Basic,
        );
        Box::new(BooleanQuery::new(vec![
            (Occur::Must, self.name_query(name)),
            (Occur::Must, Box::new(kind) as Box<dyn Query>),
        ]))
    }

    pub fn document(&self, path: &str, r: &RefRecord) -> TantivyDocument {
        let mut doc = TantivyDocument::default();
        doc.add_text(self.name_exact, &r.name);
        doc.add_text(self.kind, r.kind.label());
        doc.add_text(self.path, path);
        doc.add_u64(self.line, r.line as u64);
        doc.add_u64(self.byte_start, r.byte_start as u64);
        doc.add_u64(self.byte_end, r.byte_end as u64);
        doc.add_text(self.enclosing_item, &r.enclosing_item);
        doc.add_text(self.enclosing_kind, item_kind_label(r.enclosing_kind));
        doc
    }

    pub fn row(&self, doc: &TantivyDocument) -> UsageRow {
        let text = |f: Field| {
            doc.get_first(f)
                .and_then(|v| v.as_str())
                .unwrap_or_default()
                .to_string()
        };
        let num = |f: Field| doc.get_first(f).and_then(|v| v.as_u64()).unwrap_or(0) as u32;
        UsageRow {
            kind: RefKind::from_label(&text(self.kind)),
            path: text(self.path),
            line: num(self.line),
            byte_start: num(self.byte_start),
            byte_end: num(self.byte_end),
            enclosing_item: text(self.enclosing_item),
            enclosing_kind: item_kind_from_label(&text(self.enclosing_kind)),
        }
    }
}
