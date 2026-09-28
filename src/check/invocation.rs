use std::path::{Path, PathBuf};

use crate::highlight::Lang;

use super::compile_db;

pub struct Invocation {
    pub directory: PathBuf,
    pub args: Vec<String>,
}

pub fn invocation(file: &Path, lang: Lang) -> Option<Invocation> {
    let lang_name = lang.clang_name()?;
    let mut args = vec!["-x".to_string(), lang_name.to_string()];
    let directory = match compile_db::lookup(file, lang) {
        Some(cc) => {
            args.extend(cc.args);
            cc.directory
        }
        None => {
            args.extend(default_args(lang, file));
            file.parent().map(Path::to_path_buf).unwrap_or_default()
        }
    };
    Some(Invocation { directory, args })
}

fn default_args(lang: Lang, file: &Path) -> Vec<String> {
    let std = match lang {
        Lang::Cpp => "-std=c++23",
        _ => "-std=c23",
    };
    let include = file
        .parent()
        .map(Path::to_path_buf)
        .unwrap_or_else(|| PathBuf::from("."));
    vec![
        std.to_string(),
        "-Wall".to_string(),
        "-I".to_string(),
        include.display().to_string(),
    ]
}
