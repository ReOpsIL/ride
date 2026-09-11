#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct SingleRun {
    pub compile: Vec<String>,
    pub run: Vec<String>,
    pub output: String,
}
