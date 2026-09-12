mod cargo;
mod catch2;
mod commands;
mod ctest;
mod gtest;
mod markers;
mod markers_cpp;

use crate::ffi::{TestCase, TestEvent, TestFramework};

pub use commands::test_commands;
pub use markers::{markers, rust_module_path};

pub fn list_tests(framework: TestFramework, text: &str) -> Vec<TestCase> {
    match framework {
        TestFramework::Cargo => cargo::list(text),
        TestFramework::GoogleTest => gtest::list(text),
        TestFramework::Catch2 => catch2::list(text),
        TestFramework::CTest => ctest::list(text),
    }
}

pub fn parse_test_output(framework: TestFramework, text: &str) -> Vec<TestEvent> {
    match framework {
        TestFramework::Cargo => cargo::parse(text),
        TestFramework::GoogleTest => gtest::parse(text),
        TestFramework::Catch2 => catch2::parse(text),
        TestFramework::CTest => ctest::parse(text),
    }
}

pub(crate) fn suite_of(name: &str) -> Option<String> {
    name.rsplit_once("::").map(|(module, _)| module.to_string())
}

pub(crate) fn event(
    suite: Option<String>,
    name: &str,
    status: crate::ffi::TestStatus,
    duration_ms: Option<u64>,
) -> TestEvent {
    TestEvent {
        suite,
        name: name.to_string(),
        status,
        output: String::new(),
        duration_ms,
    }
}
