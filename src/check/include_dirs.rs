use std::path::{Path, PathBuf};

use crate::highlight::Lang;

use super::compile_db;

const DIR_FLAGS: &[&str] = &["-I", "-iquote", "-isystem"];

pub fn include_dirs(file: &Path) -> Vec<PathBuf> {
    let lang = Lang::for_path(file.to_str());
    let Some(cc) = compile_db::lookup(file, lang) else {
        return Vec::new();
    };
    let mut out = Vec::new();
    let mut it = cc.args.iter();
    while let Some(arg) = it.next() {
        if let Some(dir) = dir_of(arg, &mut it) {
            let path = cc.directory.join(dir);
            if !out.contains(&path) {
                out.push(path);
            }
        }
    }
    out
}

fn dir_of<'a>(arg: &'a str, rest: &mut impl Iterator<Item = &'a String>) -> Option<&'a str> {
    for flag in DIR_FLAGS {
        if arg == *flag {
            return rest.next().map(String::as_str);
        }
        if let Some(attached) = arg.strip_prefix(flag)
            && !attached.is_empty()
        {
            return Some(attached);
        }
    }
    None
}
