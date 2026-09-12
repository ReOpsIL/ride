use std::path::Path;

use super::markers_cpp::cpp;
use crate::ffi::{TestFramework, TestMarker};
use crate::highlight::Lang;

pub fn markers(lang: Lang, text: &str, module_path: &str) -> Vec<TestMarker> {
    match lang {
        Lang::Rust => rust(text, module_path),
        Lang::C | Lang::Cpp => cpp(text),
        _ => Vec::new(),
    }
}

pub fn rust_module_path(path: Option<&Path>) -> String {
    let Some(path) = path else {
        return String::new();
    };
    let mut parts: Vec<String> = Vec::new();
    let mut in_crate = false;
    for component in path.components() {
        let Some(name) = component.as_os_str().to_str() else {
            continue;
        };
        if !in_crate {
            in_crate = name == "src";
            continue;
        }
        parts.push(name.to_string());
    }
    let last = parts.pop().unwrap_or_default();
    let Some(stem) = last.strip_suffix(".rs") else {
        return String::new();
    };
    if !matches!(stem, "main" | "lib" | "mod") {
        parts.push(stem.to_string());
    }
    parts.join("::")
}

struct RustScan {
    mods: Vec<(String, usize)>,
    depth: usize,
    pending: bool,
    in_block: bool,
}

fn rust(text: &str, module_path: &str) -> Vec<TestMarker> {
    let mut scan = RustScan {
        mods: Vec::new(),
        depth: 0,
        pending: false,
        in_block: false,
    };
    let mut out = Vec::new();
    let mut offset = 0usize;
    for line in text.split_inclusive('\n') {
        let code = outside_block_comment(line, &mut scan.in_block);
        if let Some(marker) = rust_line(code.trim(), offset, module_path, &mut scan) {
            out.push(marker);
        }
        offset += line.len();
    }
    out
}

fn outside_block_comment(line: &str, in_block: &mut bool) -> String {
    let mut out = String::new();
    let mut rest = line;
    loop {
        if *in_block {
            let Some(at) = rest.find("*/") else {
                return out;
            };
            rest = &rest[at + 2..];
            *in_block = false;
            continue;
        }
        let open = rest.find("/*");
        let eol = rest.find("//");
        match (open, eol) {
            (Some(open), Some(eol)) if eol < open => {
                out.push_str(rest);
                return out;
            }
            (Some(open), _) => {
                out.push_str(&rest[..open]);
                rest = &rest[open + 2..];
                *in_block = true;
            }
            (None, _) => {
                out.push_str(rest);
                return out;
            }
        }
    }
}

fn rust_line(
    trimmed: &str,
    offset: usize,
    module_path: &str,
    scan: &mut RustScan,
) -> Option<TestMarker> {
    let name = fn_name(trimmed);
    let marker = match name {
        Some(name) if scan.pending => Some(TestMarker {
            name: qualified(name, module_path, &scan.mods),
            byte_start: offset as u32,
            framework: Some(TestFramework::Cargo),
        }),
        Some("main") if scan.depth == 0 && module_path.is_empty() => Some(TestMarker {
            name: "main".to_string(),
            byte_start: offset as u32,
            framework: None,
        }),
        _ => None,
    };
    if trimmed.starts_with("#[") {
        scan.pending = scan.pending || trimmed.contains("test]");
    } else if !trimmed.is_empty() && !trimmed.starts_with("//") {
        scan.pending = false;
    }
    if let Some(module) = mod_name(trimmed) {
        scan.mods.push((module.to_string(), scan.depth));
    }
    scan.depth =
        (scan.depth + trimmed.matches('{').count()).saturating_sub(trimmed.matches('}').count());
    while scan.mods.last().is_some_and(|(_, at)| scan.depth <= *at) {
        scan.mods.pop();
    }
    marker
}

fn qualified(name: &str, module_path: &str, mods: &[(String, usize)]) -> String {
    let mut parts: Vec<&str> = Vec::new();
    if !module_path.is_empty() {
        parts.push(module_path);
    }
    parts.extend(mods.iter().map(|(m, _)| m.as_str()));
    parts.push(name);
    parts.join("::")
}

fn fn_name(trimmed: &str) -> Option<&str> {
    let rest = keyword(trimmed, "fn")?;
    let end = rest.find(|c: char| !c.is_alphanumeric() && c != '_')?;
    let name = rest.get(..end)?;
    if name.is_empty() { None } else { Some(name) }
}

fn mod_name(trimmed: &str) -> Option<&str> {
    let rest = keyword(trimmed, "mod")?;
    let end = rest.find(|c: char| !c.is_alphanumeric() && c != '_')?;
    let name = rest.get(..end)?;
    if rest.get(end..)?.trim_start().starts_with('{') {
        Some(name)
    } else {
        None
    }
}

fn keyword<'a>(trimmed: &'a str, word: &str) -> Option<&'a str> {
    let mut rest = trimmed;
    loop {
        if let Some(after) = rest.strip_prefix(word).and_then(|a| a.strip_prefix(' ')) {
            return Some(after.trim_start());
        }
        let (head, tail) = rest.split_once(' ')?;
        if !matches!(
            head,
            "pub" | "async" | "unsafe" | "const" | "extern" | "default"
        ) && !head.starts_with("pub(")
        {
            return None;
        }
        rest = tail.trim_start();
    }
}
