use std::path::Path;

pub use crate::ffi::{ProjectKind, ProjectModel};

pub fn unmatched(root: &Path) -> ProjectModel {
    ProjectModel {
        root: root.display().to_string(),
        kind: ProjectKind::None,
        targets: Vec::new(),
        profiles: Vec::new(),
        manifest: String::new(),
        notice: None,
    }
}

pub fn marked(root: &Path, kind: ProjectKind, names: &[&str]) -> Option<ProjectModel> {
    names
        .iter()
        .map(|name| root.join(name))
        .find(|path| path.is_file())
        .map(|path| ProjectModel {
            root: root.display().to_string(),
            kind,
            targets: Vec::new(),
            profiles: Vec::new(),
            manifest: path.display().to_string(),
            notice: None,
        })
}
