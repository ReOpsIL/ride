use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::Path;

use crate::error::EngineError;
use crate::ffi::{RecompileCommand, SingleRun};

use super::Engine;

#[uniffi::export]
impl Engine {
    pub fn single_file_command(
        &self,
        path: String,
        out_dir: String,
    ) -> Result<SingleRun, EngineError> {
        self.guard(|| crate::run::single_file_command(Path::new(&path), Path::new(&out_dir)))
    }

    pub fn recompile_command(&self, path: String) -> Option<RecompileCommand> {
        catch_unwind(AssertUnwindSafe(|| {
            crate::run::recompile_command(Path::new(&path))
        }))
        .ok()
        .flatten()
    }
}
