#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum IndexState {
    Idle,
    Indexing,
    Ready,
    Rebuilding,
    Error,
}

#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct IndexStatus {
    pub state: IndexState,
    pub docs: u32,
    pub crates_done: u32,
    pub crates_total: u32,
    pub rust_src_available: bool,
    pub message: Option<String>,
}

impl IndexStatus {
    pub fn idle(rust_src_available: bool) -> Self {
        Self {
            state: IndexState::Idle,
            docs: 0,
            crates_done: 0,
            crates_total: 0,
            rust_src_available,
            message: None,
        }
    }
}

#[uniffi::export(with_foreign)]
pub trait IndexStatusListener: Send + Sync {
    fn on_status(&self, status: IndexStatus);
}
