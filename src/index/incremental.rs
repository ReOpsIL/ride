use std::collections::BTreeMap;
use std::fs;
use std::path::Path;

use tantivy::{Index, IndexWriter, Term};

use crate::error::EngineError;
use crate::extract::{External, Scope};
use crate::ffi::IndexStatus;

use super::crates::extract_items;
use super::doc::{keep_item, to_document};
use super::fingerprint::HashedCrate;
use super::hash::crate_key;
use super::promote::tv;
use super::schema::build_fields;
use super::status::{Manifest, append_status};
use super::warnings::{append_warning, reset_warnings};

const WRITER_MEMORY: usize = 32 * 1024 * 1024;
const MAX_CHANGED: usize = 8;

pub struct Delta<'a> {
    pub changed: Vec<&'a HashedCrate>,
    pub stale_hashes: Vec<String>,
}

pub fn delta<'a>(prev: &Manifest, hashed: &'a [HashedCrate]) -> Option<Delta<'a>> {
    let mut seen = BTreeMap::new();
    let mut changed = Vec::new();
    let mut stale = Vec::new();
    for h in hashed {
        let key = key_of(h);
        seen.insert(key.clone(), ());
        match prev.crate_hashes.get(&key) {
            Some(old) if *old == h.hash => {}
            Some(old) => {
                changed.push(h);
                stale.push(old.clone());
            }
            None => changed.push(h),
        }
    }
    stale.extend(
        prev.crate_hashes
            .iter()
            .filter(|(k, _)| !seen.contains_key(*k))
            .map(|(_, v)| v.clone()),
    );
    let small = changed.len() + stale.len() <= MAX_CHANGED;
    let workspace_only = changed.iter().all(|h| h.crate_.scope == Scope::Workspace);
    (small && workspace_only && !prev.crate_hashes.is_empty()).then_some(Delta {
        changed,
        stale_hashes: stale,
    })
}

pub fn key_of(h: &HashedCrate) -> String {
    crate_key(&h.crate_.path).to_string_lossy().into_owned()
}

pub fn apply(
    index_dir: &Path,
    live: &Path,
    staging: &Path,
    d: &Delta<'_>,
    status: &mut IndexStatus,
) -> Result<u32, EngineError> {
    reset_warnings(index_dir)?;
    clone_dir(live, staging)?;
    let _ = fs::remove_file(staging.join(".tantivy-writer.lock"));
    let index = Index::open_in_dir(staging).map_err(tv)?;
    super::tokenizers::register(&index).map_err(tv)?;
    let fields = build_fields();
    let mut writer: IndexWriter = index.writer(WRITER_MEMORY).map_err(tv)?;
    for hash in &d.stale_hashes {
        writer.delete_term(Term::from_field_text(fields.content_hash, hash));
    }
    let external = External::default();
    for h in &d.changed {
        match extract_items(&h.crate_, &external) {
            Ok(items) => {
                for item in items.iter().filter(|i| keep_item(i)) {
                    writer
                        .add_document(to_document(&fields, item, &h.hash))
                        .map_err(tv)?;
                }
            }
            Err(e) => {
                append_warning(index_dir, &h.crate_.name, &e)?;
                status.warnings += 1;
            }
        }
        status.crates_done += 1;
        append_status(index_dir, status)?;
    }
    writer.commit().map_err(tv)?;
    writer.wait_merging_threads().map_err(tv)?;
    let reader = index.reader().map_err(tv)?;
    Ok(reader.searcher().num_docs() as u32)
}

fn clone_dir(from: &Path, to: &Path) -> Result<(), EngineError> {
    if to.exists() {
        fs::remove_dir_all(to).map_err(|e| EngineError::io(to, e))?;
    }
    fs::create_dir_all(to).map_err(|e| EngineError::io(to, e))?;
    let entries = fs::read_dir(from).map_err(|e| EngineError::io(from, e))?;
    for entry in entries.flatten() {
        let src = entry.path();
        let dest = to.join(entry.file_name());
        if src.is_dir() {
            clone_dir(&src, &dest)?;
        } else {
            fs::copy(&src, &dest).map_err(|e| EngineError::io(&src, e))?;
        }
    }
    Ok(())
}
