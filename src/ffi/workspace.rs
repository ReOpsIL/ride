#[derive(Debug, Clone, uniffi::Record)]
pub struct WorkspaceInfo {
    pub root: String,
    pub package_name: Option<String>,
    pub is_cargo: bool,
    pub members: Vec<String>,
    pub rust_src_available: bool,
    pub sysroot: Option<String>,
}
