use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::Path;

use crate::ffi::{TestEvent, TestFramework, TestMarker};
use crate::run::tests;

use super::Engine;

#[uniffi::export]
impl Engine {
    pub fn parse_test_output(&self, framework: TestFramework, text: String) -> Vec<TestEvent> {
        catch_unwind(AssertUnwindSafe(|| {
            tests::parse_test_output(framework, &text)
        }))
        .unwrap_or_default()
    }

    pub fn test_markers(&self, session_id: u64, path: Option<String>) -> Vec<TestMarker> {
        let module = tests::rust_module_path(path.as_deref().map(Path::new));
        catch_unwind(AssertUnwindSafe(|| {
            self.read(|i| {
                i.sessions
                    .get(&session_id)
                    .map(|s| tests::markers(s.lang(), s.replica(), &module))
            })
            .ok()
            .flatten()
        }))
        .ok()
        .flatten()
        .unwrap_or_default()
    }
}
