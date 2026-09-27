use std::path::{Path, PathBuf};
use std::sync::Arc;

use crate::refs::RefIndex;

pub struct BoundRefs {
    root: PathBuf,
    index: Arc<RefIndex>,
}

impl BoundRefs {
    pub fn new(root: PathBuf, index: RefIndex) -> Self {
        Self {
            root,
            index: Arc::new(index),
        }
    }

    pub fn for_root(&self, root: &Path) -> Option<Arc<RefIndex>> {
        (self.root == root).then(|| self.index.clone())
    }
}
