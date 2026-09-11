use std::path::Path;

use super::Engine;

#[uniffi::export]
impl Engine {
    pub fn is_system_path(&self, path: String) -> bool {
        self.read(|i| i.system_includes.clone())
            .map(|sys| sys.contains(Path::new(&path)))
            .unwrap_or(false)
    }
}
