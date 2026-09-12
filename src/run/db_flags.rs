use std::path::{Path, PathBuf};

use crate::highlight::Lang;

const WITH_VALUE: &[&str] = &["-I", "-D", "-isystem", "-iquote", "-F"];
const PREFIXES: &[&str] = &["-I", "-D", "-std=", "-isystem", "-iquote", "-F"];
const PATH_FLAGS: &[&str] = &["-I", "-isystem", "-iquote", "-F"];

pub fn flags(path: &Path, lang: Lang) -> Vec<String> {
    let Some(command) = crate::check::lookup(path, lang) else {
        return Vec::new();
    };
    let dir = command.directory;
    let mut out = Vec::new();
    let mut args = command.args.into_iter();
    while let Some(arg) = args.next() {
        if WITH_VALUE.contains(&arg.as_str()) {
            if let Some(value) = args.next() {
                let is_path = PATH_FLAGS.contains(&arg.as_str());
                out.push(arg);
                out.push(if is_path {
                    absolute(&dir, &value)
                } else {
                    value
                });
            }
        } else if let Some(flag) = PATH_FLAGS.iter().find(|f| joined(&arg, f)) {
            out.push(format!("{}{}", flag, absolute(&dir, &arg[flag.len()..])));
        } else if PREFIXES.iter().any(|p| joined(&arg, p)) {
            out.push(arg);
        }
    }
    out
}

fn joined(arg: &str, flag: &str) -> bool {
    arg.len() > flag.len() && arg.starts_with(flag)
}

fn absolute(dir: &Path, value: &str) -> String {
    let path = PathBuf::from(value);
    if path.is_absolute() {
        return value.to_string();
    }
    let joined = dir.join(path);
    joined
        .canonicalize()
        .unwrap_or(joined)
        .display()
        .to_string()
}
