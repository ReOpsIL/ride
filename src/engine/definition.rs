use std::collections::{HashMap, HashSet};
use std::panic::{AssertUnwindSafe, catch_unwind};

use crate::ffi::DefinitionExcerpt;

use super::excerpt::{self, Parsed};
use super::hit_source::{self, Buffer};
use super::{Engine, symbols};

#[uniffi::export]
impl Engine {
    pub fn quick_definition(&self, session_id: u64, cursor_byte: u32) -> Vec<DefinitionExcerpt> {
        catch_unwind(AssertUnwindSafe(|| build(self, session_id, cursor_byte))).unwrap_or_default()
    }
}

fn build(engine: &Engine, session_id: u64, cursor_byte: u32) -> Vec<DefinitionExcerpt> {
    let buffer = engine
        .read(|i| i.sessions.get(&session_id).map(Buffer::of))
        .ok()
        .flatten();
    let ranking = symbols::context(engine, session_id);
    let hits = engine.find_definitions(session_id, cursor_byte).hits;
    let mut sources: HashMap<Option<String>, Parsed> = HashMap::new();
    let mut seen = HashSet::new();
    let mut out = Vec::new();
    for hit in hits {
        let file = hit_source::file_of(&hit, buffer.as_ref()).map(str::to_string);
        let parsed = sources.entry(file).or_insert_with_key(|file| {
            Parsed::new(hit_source::load(file.as_deref(), buffer.as_ref()))
        });
        if !seen.insert((parsed.loaded.path.clone(), hit.byte_start.unwrap_or(0))) {
            continue;
        }
        let tier = ranking.tier(hit.source_path.as_deref(), &hit.crate_name);
        if let Some(excerpt) = excerpt::of(&hit, parsed) {
            out.push((tier, excerpt));
        }
    }
    out.sort_by_key(|(tier, e)| (*tier, rank(&e.label)));
    out.into_iter().map(|(_, e)| e).collect()
}

fn rank(label: &str) -> u8 {
    match label {
        "declaration" | "trait" => 0,
        "definition" => 1,
        s if s.starts_with("impl ") => 1,
        _ => 2,
    }
}
