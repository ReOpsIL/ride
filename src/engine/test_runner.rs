use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::Path;

use crate::error::EngineError;
use crate::ffi::{Target, TestCase, TestCommands, TestEvent, TestFramework, TestMarker};
use crate::run::tests;

use super::Engine;

#[uniffi::export]
impl Engine {
    pub fn list_tests(&self, framework: TestFramework, text: String) -> Vec<TestCase> {
        catch_unwind(AssertUnwindSafe(|| tests::list_tests(framework, &text))).unwrap_or_default()
    }

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

    pub fn test_commands(
        &self,
        target: Target,
        framework: TestFramework,
    ) -> Result<TestCommands, EngineError> {
        match catch_unwind(AssertUnwindSafe(|| {
            tests::test_commands(&target, framework)
        })) {
            Ok(r) => r,
            Err(p) => Err(EngineError::from_panic(p)),
        }
    }
}
