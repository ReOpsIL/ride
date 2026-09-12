#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct SingleRun {
    pub compile: Vec<String>,
    pub run: Vec<String>,
    pub output: String,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct RecompileCommand {
    pub argv: Vec<String>,
    pub directory: String,
}
