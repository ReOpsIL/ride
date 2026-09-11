use std::path::Path;

use crate::ffi::{Target, TargetKind};

use super::cmake_api::TargetJson;

pub fn targets(items: &[TargetJson], root: &Path, build_dir: &str) -> Vec<Target> {
    items
        .iter()
        .map(|item| one(item, root, build_dir))
        .collect()
}

fn one(item: &TargetJson, root: &Path, build_dir: &str) -> Target {
    let kind = kind_of(item);
    Target {
        name: item.name.clone(),
        kind,
        build: vec![
            "cmake".to_string(),
            "--build".to_string(),
            build_dir.to_string(),
            "--target".to_string(),
            item.name.clone(),
        ],
        run: run_of(item, kind, build_dir),
        sources: item.sources.iter().map(|s| s.path.clone()).collect(),
        working_dir: root.display().to_string(),
    }
}

fn kind_of(item: &TargetJson) -> TargetKind {
    if item.name.to_lowercase().starts_with("test") {
        return TargetKind::Test;
    }
    match item.kind.as_str() {
        "EXECUTABLE" => TargetKind::Bin,
        "STATIC_LIBRARY" | "SHARED_LIBRARY" | "MODULE_LIBRARY" | "OBJECT_LIBRARY"
        | "INTERFACE_LIBRARY" => TargetKind::Lib,
        _ => TargetKind::Custom,
    }
}

fn run_of(item: &TargetJson, kind: TargetKind, build_dir: &str) -> Option<Vec<String>> {
    match kind {
        TargetKind::Test => Some(vec![
            "ctest".to_string(),
            "--test-dir".to_string(),
            build_dir.to_string(),
        ]),
        TargetKind::Bin => item
            .artifacts
            .first()
            .map(|artifact| vec![format!("{build_dir}/{}", artifact.path)]),
        _ => None,
    }
}
