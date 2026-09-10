use std::path::{Path, PathBuf};

use serde::Deserialize;

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

pub fn lookup(file: &Path) -> Option<CompileCommand> {
    let file = file.canonicalize().ok()?;
    databases(&file).find_map(|db| best_entry(&db, &file))
}

fn databases(file: &Path) -> impl Iterator<Item = PathBuf> + '_ {
    file.ancestors()
        .skip(1)
        .flat_map(|dir| DB_DIRS.iter().map(move |d| dir.join(d).join(DB_NAME)))
        .filter(|p| p.is_file())
}

fn best_entry(db: &Path, file: &Path) -> Option<CompileCommand> {
    let text = std::fs::read_to_string(db).ok()?;
    let entries: Vec<Entry> = serde_json::from_str(&text).ok()?;
    let sources: Vec<(PathBuf, &Entry)> = entries
        .iter()
        .map(|e| (Path::new(&e.directory).join(&e.file), e))
        .collect();
    let exact = sources
        .iter()
        .find(|(src, _)| src.canonicalize().ok().as_deref() == Some(file));
    let sibling = || {
        sources.iter().find(|(src, _)| {
            src.parent().and_then(|p| p.canonicalize().ok()).as_deref() == file.parent()
        })
    };
    let (src, entry) = exact.or_else(sibling)?;
    Some(CompileCommand {
        directory: PathBuf::from(&entry.directory),
        args: strip(argv(entry)?, src),
    })
}

fn argv(entry: &Entry) -> Option<Vec<String>> {
    match (&entry.arguments, &entry.command) {
        (Some(args), _) => Some(args.clone()),
        (None, Some(cmd)) => shlex::split(cmd),
        (None, None) => None,
    }
}

fn strip(args: Vec<String>, source: &Path) -> Vec<String> {
    let name = source.file_name();
    let mut out = Vec::new();
    let mut it = args.into_iter().skip(1);
    while let Some(arg) = it.next() {
        if SKIP_WITH_VALUE.contains(&arg.as_str()) {
            it.next();
        } else if !SKIP_ALONE.contains(&arg.as_str()) && Path::new(&arg).file_name() != name {
            out.push(arg);
        }
    }
    out
}
