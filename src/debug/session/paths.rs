use crate::ffi::StackFrame;

use super::DebugSession;

impl DebugSession {
    pub(super) fn remote_path(&self, path: &str) -> String {
        match &self.paths {
            Some(map) => map.to_remote_str(path),
            None => path.to_string(),
        }
    }

    pub(super) fn local_path(&self, path: &str) -> String {
        match &self.paths {
            Some(map) => map.to_local_str(path),
            None => path.to_string(),
        }
    }

    pub(super) fn mapped(&self) -> bool {
        self.paths.is_some()
    }

    pub(super) fn local_frame(&self, mut frame: StackFrame) -> StackFrame {
        frame.path = frame.path.map(|path| self.local_path(&path));
        frame
    }
}
