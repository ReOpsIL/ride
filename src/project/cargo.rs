use std::path::Path;

use crate::discover::metadata::{CrateTarget, PackageTargets, workspace_targets};
use crate::error::EngineError;
use crate::ffi::{EngineConfig, Target, TargetKind};

use super::Detect;
use super::model::{self, ProjectKind, ProjectModel};

pub struct Cargo;

impl Detect for Cargo {
    fn detect(root: &Path, config: &EngineConfig) -> Result<Option<ProjectModel>, EngineError> {
        let Some(mut model) = model::marked(root, ProjectKind::Cargo, &["Cargo.toml"]) else {
            return Ok(None);
        };
        model.profiles = vec!["debug".to_string(), "release".to_string()];
        model.targets = match workspace_targets(Path::new(&model.manifest), config.offline_metadata)
        {
            Ok(packages) => packages
                .iter()
                .flat_map(|pkg| package_targets(pkg, &model.root))
                .collect(),
            Err(_) => Vec::new(),
        };
        Ok(Some(model))
    }
}

fn package_targets(pkg: &PackageTargets, working_dir: &str) -> Vec<Target> {
    let mut targets: Vec<Target> = pkg
        .targets
        .iter()
        .filter_map(|unit| unit_target(pkg, unit, working_dir))
        .collect();
    if let Some(test) = test_target(pkg, working_dir) {
        targets.push(test);
    }
    targets
}

fn unit_target(pkg: &PackageTargets, unit: &CrateTarget, working_dir: &str) -> Option<Target> {
    let kind = unit_kind(&unit.kinds)?;
    let (build, run) = match kind {
        TargetKind::Bin => (
            argv(pkg, &["build", "--bin", &unit.name]),
            Some(argv(pkg, &["run", "--bin", &unit.name])),
        ),
        TargetKind::Lib => (argv(pkg, &["build", "--lib"]), None),
        TargetKind::Example => (
            argv(pkg, &["build", "--example", &unit.name]),
            Some(argv(pkg, &["run", "--example", &unit.name])),
        ),
        TargetKind::Bench => (
            argv(pkg, &["build", "--bench", &unit.name]),
            Some(argv(pkg, &["bench", "--bench", &unit.name])),
        ),
        _ => return None,
    };
    Some(Target {
        name: unit.name.clone(),
        kind,
        build,
        run,
        sources: vec![unit.src_path.clone()],
        working_dir: working_dir.to_string(),
    })
}

fn unit_kind(kinds: &[String]) -> Option<TargetKind> {
    if kinds.iter().any(|k| k == "bin") {
        return Some(TargetKind::Bin);
    }
    if kinds.iter().any(|k| is_lib_kind(k)) {
        return Some(TargetKind::Lib);
    }
    if kinds.iter().any(|k| k == "example") {
        return Some(TargetKind::Example);
    }
    if kinds.iter().any(|k| k == "bench") {
        return Some(TargetKind::Bench);
    }
    None
}

fn is_lib_kind(kind: &str) -> bool {
    matches!(
        kind,
        "lib" | "rlib" | "dylib" | "cdylib" | "staticlib" | "proc-macro"
    )
}

fn test_target(pkg: &PackageTargets, working_dir: &str) -> Option<Target> {
    let harnessed: Vec<&CrateTarget> = pkg
        .targets
        .iter()
        .filter(|unit| unit.kinds.iter().any(|k| k == "test"))
        .collect();
    let units: Vec<&CrateTarget> = if harnessed.is_empty() {
        pkg.targets
            .iter()
            .filter(|unit| {
                unit.kinds
                    .iter()
                    .any(|k| k == "bin" || is_lib_kind(k) || k == "test")
            })
            .collect()
    } else {
        harnessed
    };
    if units.is_empty() {
        return None;
    }
    Some(Target {
        name: pkg.name.clone(),
        kind: TargetKind::Test,
        build: argv(pkg, &["test"]),
        run: None,
        sources: units.iter().map(|u| u.src_path.clone()).collect(),
        working_dir: working_dir.to_string(),
    })
}

fn argv(pkg: &PackageTargets, rest: &[&str]) -> Vec<String> {
    let mut args = vec!["cargo".to_string()];
    let Some((command, flags)) = rest.split_first() else {
        return args;
    };
    args.push((*command).to_string());
    args.push("-p".to_string());
    args.push(pkg.name.clone());
    args.extend(flags.iter().map(|f| (*f).to_string()));
    args
}
