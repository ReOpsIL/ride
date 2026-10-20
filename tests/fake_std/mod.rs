#![allow(dead_code)]

use std::path::Path;
use std::sync::Arc;

use ride_engine::{Engine, EngineConfig, engine_start, write_index};

pub struct FakeStd {
    pub engine: Arc<Engine>,
    _dir: tempfile::TempDir,
}

impl FakeStd {
    pub fn with(modules: &[(&str, &str)]) -> Self {
        let dir = tempfile::tempdir().expect("tempdir");
        let project = dir.path().join("app");
        let sysroot = dir.path().join("sysroot");
        let std_root = sysroot.join("lib/rustlib/src/rust/library/std");
        write(&project, "Cargo.toml", &manifest("app", "0.1.0"));
        write(&project, "src/lib.rs", "pub fn app() {}\n");
        write(&std_root, "Cargo.toml", &manifest("std", "0.0.0"));
        let lib: String = modules
            .iter()
            .map(|(name, _)| format!("pub mod {name};\n"))
            .collect();
        write(&std_root, "src/lib.rs", &lib);
        for (name, body) in modules {
            write(&std_root, &format!("src/{name}.rs"), body);
        }
        let index = dir.path().join("index");
        let config = EngineConfig {
            index_dir: index.display().to_string(),
            cargo_home: Some(dir.path().join("cargo").display().to_string()),
            sysroot: Some(sysroot.display().to_string()),
            offline_metadata: true,
            refs_dir: None,
            report_dir: None,
        };
        write_index(&project, &index, &config).expect("index");
        let engine = engine_start(config);
        engine
            .open_workspace(project.display().to_string())
            .expect("workspace");
        Self { engine, _dir: dir }
    }

    pub fn open(&self, path: Option<&str>, src: &str) -> u64 {
        self.engine
            .open_session("buf".into(), path.map(str::to_string), src.into(), None)
            .expect("session")
            .session_id
    }
}

pub fn at(src: &str, needle: &str, nth: usize) -> u32 {
    src.match_indices(needle).nth(nth).expect("needle").0 as u32 + 1
}

fn manifest(name: &str, version: &str) -> String {
    format!("[package]\nname = \"{name}\"\nversion = \"{version}\"\nedition = \"2021\"\n")
}

fn write(root: &Path, path: &str, body: &str) {
    let file = root.join(path);
    if let Some(parent) = file.parent() {
        std::fs::create_dir_all(parent).expect("dirs");
    }
    std::fs::write(file, body).expect("write");
}
