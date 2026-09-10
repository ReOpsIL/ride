use std::path::{Path, PathBuf};

use serde::Deserialize;

use crate::highlight::Lang;

const DB_NAME: &str = "compile_commands.json";
const DB_DIRS: &[&str] = &["", "build", "out", "cmake-build-debug"];
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
    databases(&file).find_map(|db| best_entry(&db, &file, lang))
}

fn databases(file: &Path) -> impl Iterator<Item = PathBuf> + '_ {
    file.ancestors()
        .skip(1)
        .flat_map(|dir| DB_DIRS.iter().map(move |d| dir.join(d).join(DB_NAME)))
        .filter(|p| p.is_file())
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
