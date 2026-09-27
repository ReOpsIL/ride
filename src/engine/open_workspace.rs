use std::path::{Path, PathBuf};

use crate::ffi::WorkspaceInfo;

#[derive(Clone)]
pub struct OpenWorkspace {
    pub info: WorkspaceInfo,
    pub tree: WorkspaceTree,
}

impl OpenWorkspace {
    pub fn new(info: WorkspaceInfo) -> Self {
        let tree = WorkspaceTree::new(Path::new(&info.root));
        Self { info, tree }
    }
}

#[derive(Clone, Debug, Default)]
pub struct WorkspaceTree {
    roots: Vec<PathBuf>,
}

impl WorkspaceTree {
    pub fn new(root: &Path) -> Self {
        let mut roots = vec![root.to_path_buf()];
        if let Ok(real) = std::fs::canonicalize(root)
            && real != root
        {
            roots.push(real);
        }
        Self { roots }
    }

    pub fn contains(&self, path: &Path) -> bool {
        self.roots.iter().any(|root| path.starts_with(root))
    }
}
