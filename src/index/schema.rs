use tantivy::schema::{
    Field, IndexRecordOption, NumericOptions, STORED, STRING, Schema, TEXT, TextFieldIndexing,
    TextOptions,
};

pub const SCHEMA_VERSION: u32 = 11;
pub const PREFIX_TOKENIZER: &str = "edge_ngram";
pub const MAX_GRAM: usize = 20;
pub const PARENT_PATH: &str = "parent_path";
pub const NAME_HUMP: &str = "name_hump";
pub const REACHABLE: &str = "reachable";
pub const DEPRECATED: &str = "deprecated";

pub struct IndexFields {
    pub schema: Schema,
    pub crate_name: Field,
    pub version: Field,
    pub item_kind: Field,
    pub path: Field,
    pub path_exact: Field,
    pub parent_path: Field,
    pub name: Field,
    pub name_exact: Field,
    pub signature: Field,
    pub doc: Field,
    pub features: Field,
    pub edition: Field,
    pub visibility: Field,
    pub source_path: Field,
    pub byte_start: Field,
    pub byte_end: Field,
    pub content_hash: Field,
    pub scope: Field,
    pub name_prefix: Field,
    pub name_hump: Field,
    pub scope_rank: Field,
    pub kind_rank: Field,
    pub name_len: Field,
    pub name_hash: Field,
    pub path_len: Field,
    pub has_doc: Field,
    pub reachable: Field,
    pub deprecated: Field,
}

pub fn build_fields() -> IndexFields {
    let mut b = Schema::builder();
    let u64_stored = NumericOptions::default().set_stored();
    let u64_fast = NumericOptions::default().set_fast();
    let prefix = TextOptions::default().set_indexing_options(
        TextFieldIndexing::default()
            .set_tokenizer(PREFIX_TOKENIZER)
            .set_index_option(IndexRecordOption::WithFreqs),
    );
    IndexFields {
        crate_name: b.add_text_field("crate", STRING | STORED),
        version: b.add_text_field("version", STRING | STORED),
        item_kind: b.add_text_field("item_kind", STRING | STORED),
        path: b.add_text_field("path", TEXT | STORED),
        path_exact: b.add_text_field("path_exact", STRING | STORED),
        parent_path: b.add_text_field(PARENT_PATH, STRING | STORED),
        name: b.add_text_field("name", TEXT | STORED),
        name_exact: b.add_text_field("name_exact", STRING | STORED),
        signature: b.add_text_field("signature", TEXT | STORED),
        doc: b.add_text_field("doc_first_paragraph", TEXT | STORED),
        features: b.add_text_field("features", STRING | STORED),
        edition: b.add_text_field("edition", STRING | STORED),
        visibility: b.add_text_field("visibility", STRING | STORED),
        source_path: b.add_text_field("source_path", STRING | STORED),
        byte_start: b.add_u64_field("byte_start", u64_stored.clone()),
        byte_end: b.add_u64_field("byte_end", u64_stored),
        content_hash: b.add_text_field("content_hash", STRING | STORED),
        scope: b.add_text_field("scope", STRING | STORED),
        name_prefix: b.add_text_field("name_prefix", prefix.clone()),
        name_hump: b.add_text_field(NAME_HUMP, prefix),
        scope_rank: b.add_u64_field("scope_rank", u64_fast.clone()),
        kind_rank: b.add_u64_field("kind_rank", u64_fast.clone()),
        name_len: b.add_u64_field("name_len", u64_fast.clone()),
        name_hash: b.add_u64_field("name_hash", u64_fast.clone()),
        path_len: b.add_u64_field("path_len", u64_fast.clone()),
        has_doc: b.add_u64_field("has_doc", u64_fast.clone()),
        reachable: b.add_u64_field(REACHABLE, u64_fast.clone()),
        deprecated: b.add_u64_field(DEPRECATED, u64_fast),
        schema: b.build(),
    }
}

pub fn parent_path_of(path: &str) -> String {
    path.rsplit_once("::")
        .map(|(parent, _)| parent.to_ascii_lowercase())
        .unwrap_or_default()
}
