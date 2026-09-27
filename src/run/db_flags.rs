use std::path::Path;

use crate::abspath::absolute_string;
use crate::check::{CompileArg, compile_args};
use crate::highlight::Lang;

const KEPT_PREFIXES: &[&str] = &["-std="];

pub fn flags(path: &Path, lang: Lang) -> Vec<String> {
    let Some(command) = crate::check::lookup(path, lang) else {
        return Vec::new();
    };
    let dir = command.directory.as_path();
    let mut out = Vec::new();
    for arg in compile_args(&command.args) {
        let path_flag = arg.is_path();
        match arg {
            CompileArg::Valued {
                flag,
                value,
                joined,
            } => {
                let value = if path_flag {
                    absolute_string(dir, value)
                } else {
                    value.to_string()
                };
                push_valued(&mut out, flag, value, joined);
            }
            CompileArg::Plain(plain) if KEPT_PREFIXES.iter().any(|p| plain.starts_with(p)) => {
                out.push(plain.to_string());
            }
            CompileArg::Plain(_) => {}
        }
    }
    out
}

fn push_valued(out: &mut Vec<String>, flag: &str, value: String, joined: bool) {
    if joined {
        out.push(format!("{flag}{value}"));
    } else {
        out.extend([flag.to_string(), value]);
    }
}
