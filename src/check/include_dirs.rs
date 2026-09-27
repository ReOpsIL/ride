use std::path::{Path, PathBuf};

use crate::highlight::Lang;

use super::compile_db;
use super::compile_flags::{CompileArg, compile_args};

const DIR_FLAGS: &[&str] = &["-I", "-iquote", "-isystem"];

pub fn include_dirs(file: &Path) -> Vec<PathBuf> {
    let lang = Lang::for_path(file.to_str());
    let Some(cc) = compile_db::lookup(file, lang) else {
        return Vec::new();
    };
    let mut out = Vec::new();
    for arg in compile_args(&cc.args) {
        if let CompileArg::Valued { flag, value, .. } = arg
            && DIR_FLAGS.contains(&flag)
        {
            let path = cc.directory.join(value);
            if !out.contains(&path) {
                out.push(path);
            }
        }
    }
    out
}
