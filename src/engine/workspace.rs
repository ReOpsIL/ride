use std::path::Path;
use std::sync::Arc;

use crate::discover::workspace_info;
use crate::error::EngineError;
use crate::ffi::{IndexStatus, IndexStatusListener, WorkspaceInfo};

use super::Engine;
use super::open_workspace::OpenWorkspace;

#[uniffi::export]
impl Engine {
    pub fn open_workspace(&self, path: String) -> Result<WorkspaceInfo, EngineError> {
        self.guard(|| {
            let config = self.read(|i| i.config.clone())?;
            let info = workspace_info(Path::new(&path), &config)?;
            self.write(|i| {
                i.last_status.rust_src_available = info.rust_src_available;
                i.workspace = Some(OpenWorkspace::new(info.clone()));
                i.watch.invalidate();
            })?;
            Ok(info)
        })
    }

    pub fn close_workspace(&self) {
        let _ = self.write(|i| {
            i.oracle.stop_all();
            i.workspace = None;
            i.refs = None;
            i.overlay.clear();
            i.watch.invalidate();
        });
    }

    pub fn status(&self) -> IndexStatus {
        self.read(|i| i.last_status.clone())
            .unwrap_or_else(|_| IndexStatus::idle(false))
    }

    pub fn set_status_listener(&self, listener: Arc<dyn IndexStatusListener>) {
        let status = self.status();
        let _ = self.write(|i| {
            i.listener = Some(listener.clone());
        });
        listener.on_status(status);
    }

    pub fn workspace_file_changed(&self, path: String) {
        let _ = self.write(|i| {
            i.overlay.insert(path);
        });
    }
}
