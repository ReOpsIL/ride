use serde::Deserialize;
use thiserror::Error;

use crate::highlight::Context;

#[derive(Debug, Error)]
pub enum SheetError {
    #[error("{file}: {message}")]
    Parse { file: String, message: String },
    #[error("{file}: unknown context `{context}`")]
    Context { file: String, context: String },
    #[error("{file}: entry `{entry}` {message}")]
    Entry {
        file: String,
        entry: String,
        message: String,
    },
}

#[derive(Debug, Deserialize)]
struct SectionDef {
    title: String,
    #[serde(default)]
    contexts: Vec<String>,
    #[serde(default)]
    entries: Vec<EntryDef>,
}

#[derive(Debug, Deserialize)]
struct EntryDef {
    name: String,
    #[serde(default)]
    keys: Vec<String>,
    #[serde(default)]
    doc: String,
    snippet: String,
}

#[derive(Debug, Clone)]
pub struct Entry {
    pub name: String,
    pub keys: Vec<String>,
    pub doc: String,
    pub lines: Vec<String>,
}

#[derive(Debug, Clone)]
pub struct Section {
    pub file: String,
    pub title: String,
    pub contexts: Vec<Context>,
    pub entries: Vec<Entry>,
}

#[derive(Debug, Clone, Default)]
pub struct Sheet {
    pub sections: Vec<Section>,
}

impl Section {
    pub fn parse(file: &str, toml_text: &str) -> Result<Section, SheetError> {
        let def: SectionDef = toml::from_str(toml_text).map_err(|e| SheetError::Parse {
            file: file.into(),
            message: e.to_string(),
        })?;
        let contexts = def
            .contexts
            .iter()
            .map(|c| {
                Context::parse(c).ok_or_else(|| SheetError::Context {
                    file: file.into(),
                    context: c.clone(),
                })
            })
            .collect::<Result<Vec<_>, _>>()?;
        let entries = def
            .entries
            .into_iter()
            .map(|e| Entry::from_def(file, e))
            .collect::<Result<Vec<_>, _>>()?;
        Ok(Section {
            file: file.into(),
            title: def.title,
            contexts,
            entries,
        })
    }

    pub fn applies(&self, ctx: Context) -> bool {
        self.contexts.is_empty() || self.contexts.contains(&ctx)
    }
}

impl Entry {
    fn from_def(file: &str, def: EntryDef) -> Result<Entry, SheetError> {
        let err = |message: &str| SheetError::Entry {
            file: file.into(),
            entry: def.name.clone(),
            message: message.into(),
        };
        if def.name.trim().is_empty() {
            return Err(err("has an empty name"));
        }
        if def.doc.trim().is_empty() {
            return Err(err("has no doc"));
        }
        let snippet = def.snippet.trim_end_matches('\n');
        if snippet.trim().is_empty() {
            return Err(err("has an empty snippet"));
        }
        if !balanced_stops(snippet) {
            return Err(err("has an unbalanced tab stop"));
        }
        Ok(Entry {
            keys: def.keys.iter().map(|k| k.to_lowercase()).collect(),
            name: def.name,
            doc: def.doc,
            lines: snippet.lines().map(str::to_string).collect(),
        })
    }

    pub fn matches(&self, prefix: &str) -> bool {
        prefix.is_empty()
            || self.name_matches(prefix)
            || self.keys.iter().any(|k| k.starts_with(prefix))
    }

    pub fn name_matches(&self, prefix: &str) -> bool {
        let name = self.name.to_lowercase();
        name.starts_with(prefix)
            || name
                .split(|c: char| !c.is_alphanumeric())
                .any(|w| w.starts_with(prefix))
    }
}

fn balanced_stops(snippet: &str) -> bool {
    let mut depth = 0i32;
    let mut chars = snippet.chars().peekable();
    while let Some(c) = chars.next() {
        match c {
            '\\' => {
                chars.next();
            }
            '$' if chars.peek() == Some(&'{') => {
                chars.next();
                depth += 1;
            }
            '}' if depth > 0 => depth -= 1,
            _ => {}
        }
    }
    depth == 0
}
