use std::path::{Path, PathBuf};
use std::time::Duration;

use serde_json::{Value, json};

use crate::highlight::Lang;

use super::items::Dialect;

const CLANGD_ARGS: &[&str] = &[
    "--completion-parse=always",
    "--limit-results=0",
    "--header-insertion=never",
    "--header-insertion-decorators=false",
    "--function-arg-placeholders=1",
    "--log=error",
];

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Server {
    RustAnalyzer,
    Clangd,
}

impl Server {
    pub fn for_lang(lang: Lang) -> Option<Self> {
        match lang {
            Lang::Rust => Some(Self::RustAnalyzer),
            Lang::C | Lang::Cpp => Some(Self::Clangd),
            _ => None,
        }
    }

    pub fn name(self) -> &'static str {
        match self {
            Self::RustAnalyzer => "rust-analyzer",
            Self::Clangd => "clangd",
        }
    }

    pub fn hint(self) -> &'static str {
        match self {
            Self::RustAnalyzer => "rustup component add rust-analyzer",
            Self::Clangd => "install Xcode or the Command Line Tools (xcode-select --install)",
        }
    }

    pub fn args(self, root: &Path, cache: &Path) -> Vec<String> {
        match self {
            Self::RustAnalyzer => Vec::new(),
            Self::Clangd => {
                let mut args: Vec<String> = CLANGD_ARGS.iter().map(|a| a.to_string()).collect();
                if let Some(dir) = super::clangd::database_dir(cache, root) {
                    args.push(format!("--compile-commands-dir={}", dir.display()));
                }
                args
            }
        }
    }

    pub fn init_options(self) -> Value {
        match self {
            Self::RustAnalyzer => json!({
                "checkOnSave": false,
                "diagnostics": { "enable": false },
                "completion": {
                    "autoimport": { "enable": false },
                    "postfix": { "enable": false },
                    "callable": { "snippets": "fill_arguments" }
                }
            }),
            Self::Clangd => json!({}),
        }
    }

    pub fn waits_for_load(self) -> bool {
        self == Self::RustAnalyzer
    }

    pub fn completion_timeout(self) -> Duration {
        match self {
            Self::RustAnalyzer => Duration::from_secs(5),
            Self::Clangd => Duration::from_secs(30),
        }
    }

    pub fn dialect(self) -> Dialect {
        match self {
            Self::RustAnalyzer => Dialect::Rust,
            Self::Clangd => Dialect::Clang,
        }
    }

    pub fn root_of(self, file: &Path) -> Option<PathBuf> {
        let dir = file.parent()?;
        match self {
            Self::RustAnalyzer => crate::discover::cargo_workspace_root(dir),
            Self::Clangd => {
                Some(crate::check::project_root(file).unwrap_or_else(|| dir.to_path_buf()))
            }
        }
    }
}

pub fn language_id(lang: Lang) -> &'static str {
    match lang {
        Lang::Rust => "rust",
        Lang::C => "c",
        Lang::Cpp => "cpp",
        _ => "plaintext",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn each_language_goes_to_its_server() {
        assert_eq!(Server::for_lang(Lang::Rust), Some(Server::RustAnalyzer));
        assert_eq!(Server::for_lang(Lang::C), Some(Server::Clangd));
        assert_eq!(Server::for_lang(Lang::Cpp), Some(Server::Clangd));
        assert_eq!(language_id(Lang::Cpp), "cpp");
    }

    #[test]
    fn clangd_reads_the_database_ride_writes_into_its_cache() {
        let cache = tempfile::tempdir().expect("cache");
        let root = tempfile::tempdir().expect("root");
        let args = Server::Clangd.args(root.path(), cache.path());
        let dir = args
            .iter()
            .find_map(|a| a.strip_prefix("--compile-commands-dir="))
            .expect("database dir");
        assert!(dir.starts_with(&cache.path().display().to_string()));
        assert!(
            std::path::Path::new(dir)
                .join("compile_commands.json")
                .is_file()
        );
    }
}
