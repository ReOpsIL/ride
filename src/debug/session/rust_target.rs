use std::path::Path;

use crate::debug::target::DebugTarget;

pub fn is_rust_target(target: &DebugTarget) -> bool {
    if let Some(cwd) = target.cwd()
        && has_manifest(Path::new(cwd))
    {
        return true;
    }
    target
        .program()
        .is_some_and(|program| Path::new(program).ancestors().any(is_cargo_target_dir))
}

fn has_manifest(directory: &Path) -> bool {
    directory
        .ancestors()
        .any(|parent| parent.join("Cargo.toml").is_file())
}

fn is_cargo_target_dir(directory: &Path) -> bool {
    directory.file_name().is_some_and(|name| name == "target")
        && directory
            .parent()
            .is_some_and(|parent| parent.join("Cargo.toml").is_file())
}
