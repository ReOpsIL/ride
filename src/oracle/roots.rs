use std::collections::HashMap;
use std::path::{Path, PathBuf};

use super::server::Server;

#[derive(Default)]
pub struct Roots {
    by_dir: HashMap<(Server, PathBuf), Option<PathBuf>>,
}

impl Roots {
    pub fn of(&mut self, server: Server, file: &Path) -> Option<PathBuf> {
        let dir = file.parent()?;
        self.by_dir
            .entry((server, dir.to_path_buf()))
            .or_insert_with(|| server.root_of(file))
            .clone()
    }
}
