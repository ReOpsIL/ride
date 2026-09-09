#[derive(Debug, Clone, uniffi::Record)]
pub struct EngineConfig {
    pub index_dir: String,
    pub cargo_home: Option<String>,
    pub sysroot: Option<String>,
    pub offline_metadata: bool,
}
