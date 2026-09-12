#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum TestFramework {
    Cargo,
    GoogleTest,
    Catch2,
    CTest,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum TestStatus {
    Started,
    Passed,
    Failed,
    Ignored,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct TestEvent {
    pub suite: Option<String>,
    pub name: String,
    pub status: TestStatus,
    pub output: String,
    pub duration_ms: Option<u64>,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct TestCase {
    pub suite: Option<String>,
    pub name: String,
    pub file: Option<String>,
    pub line: Option<u32>,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct TestCommands {
    pub list: Vec<String>,
    pub run: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct TestMarker {
    pub name: String,
    pub byte_start: u32,
    pub framework: Option<TestFramework>,
}
