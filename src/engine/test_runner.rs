use std::panic::{AssertUnwindSafe, catch_unwind};

use crate::error::EngineError;
use crate::ffi::{Target, TestCase, TestCommands, TestEvent, TestFramework};
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
