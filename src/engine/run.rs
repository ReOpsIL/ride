use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::Path;

use crate::error::EngineError;
use crate::ffi::SingleRun;

use super::Engine;

#[uniffi::export]
impl Engine {
    pub fn single_file_command(
        &self,
        path: String,
        out_dir: String,
    ) -> Result<SingleRun, EngineError> {
        match catch_unwind(AssertUnwindSafe(|| {
            crate::run::single_file_command(Path::new(&path), Path::new(&out_dir))
        })) {
            Ok(r) => r,
            Err(p) => Err(EngineError::from_panic(p)),
        }
    }

    pub fn recompile_command(&self, path: String) -> Option<Vec<String>> {
        catch_unwind(AssertUnwindSafe(|| {
            crate::run::recompile_command(Path::new(&path))
        }))
        .ok()
        .flatten()
    }
}
