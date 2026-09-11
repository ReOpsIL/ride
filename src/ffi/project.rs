#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum ProjectKind {
    Cargo,
    CMake,
    Make,
    CompileDb,
    None,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum TargetKind {
    Bin,
    Lib,
    Test,
    Bench,
    Example,
    Custom,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct Target {
    pub name: String,
    pub kind: TargetKind,
    pub build: Vec<String>,
    pub run: Option<Vec<String>>,
    pub sources: Vec<String>,
    pub working_dir: String,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct ProjectModel {
    pub root: String,
    pub kind: ProjectKind,
    pub targets: Vec<Target>,
    pub profiles: Vec<String>,
    pub manifest: String,
}
