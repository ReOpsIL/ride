use std::collections::HashMap;
use std::path::PathBuf;
use std::process::Stdio;
use std::sync::Mutex;

use crate::toolchain::tool;

const START: &str = "#include <...> search starts here:";
const END: &str = "End of search list.";
const FRAMEWORK_SUFFIX: &str = "(framework directory)";
const PROBE_FLAGS: &[&str] = &["-isysroot", "--sysroot", "-target", "--target", "-stdlib"];

type Key = (String, Vec<String>);
type Ranked = Vec<(PathBuf, bool)>;

#[derive(Default)]
pub struct SystemIncludes {
    cache: Mutex<HashMap<Key, Ranked>>,
}

impl SystemIncludes {
    pub fn dirs(&self, clang_lang: &str, extra_args: &[String]) -> Vec<PathBuf> {
        self.dirs_ranked(clang_lang, extra_args)
            .into_iter()
            .filter(|(_, is_framework)| !is_framework)
            .map(|(dir, _)| dir)
            .collect()
    }

    pub fn dirs_ranked(&self, clang_lang: &str, extra_args: &[String]) -> Ranked {
        let key = (clang_lang.to_string(), extra_args.to_vec());
        if let Some(cached) = self.cached(&key) {
            return cached;
        }
        let dirs = probe(clang_lang, extra_args).unwrap_or_default();
        if let Ok(mut cache) = self.cache.lock() {
            cache.insert(key, dirs.clone());
        }
        dirs
    }

    fn cached(&self, key: &Key) -> Option<Ranked> {
        self.cache.lock().ok()?.get(key).cloned()
    }
}

fn probe(clang_lang: &str, extra_args: &[String]) -> Option<Ranked> {
    let output = tool("clang")
        .args(["-E", "-x", clang_lang, "-"])
        .args(extra_args)
        .arg("-v")
        .stdin(Stdio::null())
        .output()
        .ok()?;
    Some(parse_search_list(&String::from_utf8_lossy(&output.stderr)))
}

pub fn parse_search_list(transcript: &str) -> Ranked {
    let mut inside = false;
    let mut dirs = Vec::new();
    for line in transcript.lines().map(str::trim) {
        if line == START {
            inside = true;
        } else if !inside || line.is_empty() {
            continue;
        } else if line == END {
            break;
        } else {
            dirs.push(classify(line));
        }
    }
    dirs.sort_by_key(|(_, is_framework)| *is_framework);
    dirs
}

fn classify(line: &str) -> (PathBuf, bool) {
    match line.strip_suffix(FRAMEWORK_SUFFIX) {
        Some(path) => (PathBuf::from(path.trim_end()), true),
        None => (PathBuf::from(line), false),
    }
}

pub fn probe_args(compile_args: &[String]) -> Vec<String> {
    let mut out = Vec::new();
    let mut it = compile_args.iter();
    while let Some(arg) = it.next() {
        if PROBE_FLAGS.contains(&arg.as_str()) {
            if let Some(value) = it.next() {
                out.push(arg.clone());
                out.push(value.clone());
            }
        } else if has_attached_value(arg) {
            out.push(arg.clone());
        }
    }
    out
}

fn has_attached_value(arg: &str) -> bool {
    PROBE_FLAGS.iter().any(|flag| {
        arg.strip_prefix(flag)
            .is_some_and(|rest| rest.starts_with('='))
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    const TRANSCRIPT: &str = include_str!("../../tests/fixtures/clang_v_cxx.txt");

    #[test]
    fn parses_the_angled_search_list_and_flags_framework_dirs() {
        let dirs = parse_search_list(TRANSCRIPT);
        assert_eq!(dirs.len(), 7, "{dirs:?}");
        assert_eq!(dirs[0], (PathBuf::from("/usr/local/include"), false));
        assert_eq!(
            dirs[1].0,
            PathBuf::from("/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/c++/v1")
        );
        assert!(dirs[..5].iter().all(|(_, fw)| !fw));
        assert!(dirs[5..].iter().all(|(_, fw)| *fw));
        assert_eq!(
            dirs[5].0,
            PathBuf::from(
                "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks"
            )
        );
    }

    #[test]
    fn framework_dirs_move_last_even_when_interleaved() {
        let text = "#include <...> search starts here:\n /a (framework directory)\n /b\n /c (framework directory)\n /d\nEnd of search list.\n /ignored\n";
        let dirs = parse_search_list(text);
        let paths: Vec<&str> = dirs.iter().filter_map(|(p, _)| p.to_str()).collect();
        assert_eq!(paths, ["/b", "/d", "/a", "/c"]);
        assert!(dirs[2].1);
    }

    #[test]
    fn transcript_without_search_list_yields_nothing() {
        assert!(parse_search_list("clang: error: no such file\n").is_empty());
    }
}
