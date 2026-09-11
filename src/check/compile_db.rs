use std::collections::HashSet;
use std::path::{Path, PathBuf};

use serde::Deserialize;

use crate::highlight::Lang;

const DB_NAME: &str = "compile_commands.json";
const DB_DIRS: &[&str] = &[
    "",
    "build/Debug",
    "build/Release",
    "build/RelWithDebInfo",
    "build",
    "out",
    "cmake-build-debug",
];
const SKIP_WITH_VALUE: &[&str] = &["-o", "-MF", "-MT", "-MQ"];
const SKIP_ALONE: &[&str] = &["-c", "-M", "-MD", "-MM", "-MMD"];

#[derive(Deserialize)]
struct Entry {
    directory: String,
    file: String,
    command: Option<String>,
    arguments: Option<Vec<String>>,
}

pub struct CompileCommand {
    pub directory: PathBuf,
    pub args: Vec<String>,
}

pub fn lookup(file: &Path, lang: Lang) -> Option<CompileCommand> {
    let file = file.canonicalize().ok()?;
    databases(&file).find_map(|(_, db)| best_entry(&db, &file, lang))
}

pub fn sources_near(file: &Path) -> Vec<PathBuf> {
    databases(file)
        .find_map(|(root, db)| under(&root, listed(&db)?))
        .unwrap_or_default()
}

pub fn sources_in(root: &Path) -> Vec<PathBuf> {
    let root = root.canonicalize().unwrap_or_else(|_| root.to_path_buf());
    DB_DIRS
        .iter()
        .map(|d| {
            if d.is_empty() {
                root.join(DB_NAME)
            } else {
                root.join(d).join(DB_NAME)
            }
        })
        .filter(|p| p.is_file())
        .find_map(|db| under(&root, listed(&db)?))
        .unwrap_or_default()
}

fn under(root: &Path, files: Vec<PathBuf>) -> Option<Vec<PathBuf>> {
    let root = root.canonicalize().unwrap_or_else(|_| root.to_path_buf());
    let kept: Vec<PathBuf> = files.into_iter().filter(|f| f.starts_with(&root)).collect();
    (!kept.is_empty()).then_some(kept)
}

fn listed(db: &Path) -> Option<Vec<PathBuf>> {
    let text = std::fs::read_to_string(db).ok()?;
    let entries: Vec<Entry> = serde_json::from_str(&text).ok()?;
    let base = db.parent().unwrap_or(Path::new("."));
    let mut seen = HashSet::new();
    let mut files = Vec::new();
    for entry in &entries {
        let dir = base.join(&entry.directory);
        let dir = dir.canonicalize().unwrap_or(dir);
        let src = dir.join(&entry.file);
        let key = src.canonicalize().unwrap_or(src);
        if Lang::for_path(key.to_str()).clang_name().is_none() {
            continue;
        }
        if seen.insert(key.clone()) {
            files.push(key);
        }
    }
    Some(files)
}

fn databases(file: &Path) -> impl Iterator<Item = (PathBuf, PathBuf)> + '_ {
    file.ancestors()
        .skip(1)
        .flat_map(|dir| {
            DB_DIRS
                .iter()
                .map(move |d| (dir.to_path_buf(), dir.join(d).join(DB_NAME)))
        })
        .filter(|(_, db)| db.is_file())
}

fn best_entry(db: &Path, file: &Path, lang: Lang) -> Option<CompileCommand> {
    let text = std::fs::read_to_string(db).ok()?;
    let entries: Vec<Entry> = serde_json::from_str(&text).ok()?;
    let base = db.parent().unwrap_or(Path::new("."));
    let sources: Vec<(PathBuf, PathBuf, &Entry)> = entries
        .iter()
        .map(|e| {
            let dir = base.join(&e.directory);
            let dir = dir.canonicalize().unwrap_or(dir);
            (dir.join(&e.file), dir, e)
        })
        .collect();
    let exact = sources
        .iter()
        .find(|(src, _, _)| src.canonicalize().ok().as_deref() == Some(file));
    let siblings = || {
        sources.iter().filter(|(src, _, _)| {
            src.parent().and_then(|p| p.canonicalize().ok()).as_deref() == file.parent()
        })
    };
    let same_lang = || siblings().find(|(src, _, _)| Lang::for_path(src.to_str()) == lang);
    let (src, dir, entry, keep_std) = match exact.or_else(same_lang) {
        Some((src, dir, entry)) => (src, dir, *entry, true),
        None => siblings()
            .next()
            .map(|(src, dir, entry)| (src, dir, *entry, false))?,
    };
    Some(CompileCommand {
        directory: dir.clone(),
        args: strip(argv(entry)?, src, keep_std),
    })
}

pub fn raw_argv(file: &Path) -> Option<Vec<String>> {
    let file = file.canonicalize().ok()?;
    databases(&file).find_map(|(_, db)| exact_argv(&db, &file))
}

fn exact_argv(db: &Path, file: &Path) -> Option<Vec<String>> {
    let text = std::fs::read_to_string(db).ok()?;
    let entries: Vec<Entry> = serde_json::from_str(&text).ok()?;
    let base = db.parent().unwrap_or(Path::new("."));
    entries.iter().find_map(|entry| {
        let dir = base.join(&entry.directory);
        let dir = dir.canonicalize().unwrap_or(dir);
        let src = dir.join(&entry.file);
        if src.canonicalize().ok().as_deref() == Some(file) {
            argv(entry)
        } else {
            None
        }
    })
}

fn argv(entry: &Entry) -> Option<Vec<String>> {
    match (&entry.arguments, &entry.command) {
        (Some(args), _) => Some(args.clone()),
        (None, Some(cmd)) => shlex::split(cmd),
        (None, None) => None,
    }
}

fn strip(args: Vec<String>, source: &Path, keep_std: bool) -> Vec<String> {
    let name = source.file_name();
    let mut out = Vec::new();
    let mut it = args.into_iter().skip(1);
    while let Some(arg) = it.next() {
        if SKIP_WITH_VALUE.contains(&arg.as_str()) {
            it.next();
        } else if SKIP_ALONE.contains(&arg.as_str())
            || Path::new(&arg).file_name() == name
            || (!keep_std && arg.starts_with("-std="))
        {
            continue;
        } else {
            out.push(arg);
        }
    }
    out
}
