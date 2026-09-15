use std::fs;
use std::path::Path;

use tantivy::{Index, IndexWriter};

use crate::error::EngineError;
use crate::extract::{External, Scope};
use crate::ffi::IndexStatus;

use super::crates::extract_parts;
use super::deferred::{Deferred, absorb_target};
use super::doc::{keep_item, to_document};
use super::fingerprint::HashedCrate;
use super::promote::tv;
use super::schema::build_fields;
use super::status::append_status;
use super::warnings::{append_warning, reset_warnings};

pub struct Sink<'a> {
    writer: &'a mut IndexWriter,
    fields: &'a super::schema::IndexFields,
    index_dir: &'a Path,
}

struct CrateWrite<'a> {
    items: &'a crate::extract::CrateItems,
    hash: &'a str,
    crate_name: &'a str,
}

const WRITER_MEMORY: usize = 32 * 1024 * 1024;
const RESOLVING: &str = "resolving cross-crate re-exports";
const COMMITTING: &str = "committing index";

pub fn build(
    index_dir: &Path,
    staging: &Path,
    hashed: &[HashedCrate],
    status: &mut IndexStatus,
) -> Result<u32, EngineError> {
    reset_warnings(index_dir)?;
    if staging.exists() {
        fs::remove_dir_all(staging).map_err(|e| EngineError::io(staging, e))?;
    }
    fs::create_dir_all(staging).map_err(|e| EngineError::io(staging, e))?;
    let fields = build_fields();
    let index = Index::create_in_dir(staging, fields.schema.clone()).map_err(tv)?;
    super::tokenizers::register(&index).map_err(tv)?;
    let mut writer: IndexWriter = index.writer(WRITER_MEMORY).map_err(tv)?;
    let mut sink = Sink {
        writer: &mut writer,
        fields: &fields,
        index_dir,
    };
    let docs = run(&mut sink, hashed, status)?;
    status.message = Some(COMMITTING.into());
    append_status(index_dir, status)?;
    writer.commit().map_err(tv)?;
    writer.wait_merging_threads().map_err(tv)?;
    Ok(docs)
}

fn run(
    sink: &mut Sink<'_>,
    hashed: &[HashedCrate],
    status: &mut IndexStatus,
) -> Result<u32, EngineError> {
    let mut docs = 0u32;
    let mut external = External::default();
    let mut deferred = Deferred::default();
    for h in hashed {
        let mut held = false;
        match extract_parts(&h.crate_) {
            Ok(parts) => {
                let roots = deferred.unresolved_roots(&parts, &external);
                if roots.is_empty() {
                    let items = parts.finish(&external);
                    if h.crate_.scope == Scope::Sysroot {
                        external.absorb(&items.items);
                    }
                    docs += sink.write(
                        CrateWrite {
                            items: &items,
                            hash: &h.hash,
                            crate_name: &h.crate_.name,
                        },
                        status,
                    )?;
                } else {
                    deferred.push(h, parts, roots);
                    held = true;
                }
            }
            Err(e) => {
                append_warning(sink.index_dir, &h.crate_.name, &e)?;
                status.warnings += 1;
            }
        }
        if !held {
            status.crates_done += 1;
        }
        status.docs = docs;
        append_status(sink.index_dir, status)?;
    }
    flush_deferred(sink, hashed, deferred, &mut external, status, &mut docs)?;
    status.docs = docs;
    append_status(sink.index_dir, status)?;
    Ok(docs)
}

fn flush_deferred(
    sink: &mut Sink<'_>,
    hashed: &[HashedCrate],
    deferred: Deferred,
    external: &mut External,
    status: &mut IndexStatus,
    docs: &mut u32,
) -> Result<(), EngineError> {
    if deferred.is_empty() {
        return Ok(());
    }
    status.message = Some(RESOLVING.into());
    let targets = deferred.targets(hashed);
    status.crates_total += targets.len() as u32;
    append_status(sink.index_dir, status)?;
    for target in targets {
        absorb_target(target, external);
        status.crates_done += 1;
        append_status(sink.index_dir, status)?;
    }
    for entry in deferred.into_entries() {
        let items = entry.parts.finish(external);
        *docs += sink.write(
            CrateWrite {
                items: &items,
                hash: &entry.hash,
                crate_name: &entry.crate_name,
            },
            status,
        )?;
        status.crates_done += 1;
        status.docs = *docs;
        append_status(sink.index_dir, status)?;
    }
    Ok(())
}

impl Sink<'_> {
    fn write(
        &mut self,
        write: CrateWrite<'_>,
        status: &mut IndexStatus,
    ) -> Result<u32, EngineError> {
        for glob in &write.items.oversized_globs {
            let message = format!(
                "glob re-export of {} in {} exceeds the mirror limit",
                glob.target, glob.module
            );
            append_warning(self.index_dir, write.crate_name, &message)?;
            status.warnings += 1;
        }
        let mut docs = 0u32;
        for item in write.items.items.iter().filter(|i| keep_item(i)) {
            self.writer
                .add_document(to_document(self.fields, item, write.hash))
                .map_err(tv)?;
            docs += 1;
        }
        Ok(docs)
    }
}
