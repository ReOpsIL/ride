#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, uniffi::Enum)]
pub enum OracleState {
    #[default]
    Off,
    Idle,
    Starting,
    Ready,
    Unavailable,
    Failed,
}

#[derive(Debug, Clone, PartialEq, Eq, Default, uniffi::Record)]
pub struct OracleStatus {
    pub state: OracleState,
    pub message: Option<String>,
}

#[uniffi::export(with_foreign)]
pub trait OracleListener: Send + Sync {
    fn on_completions_ready(&self, session_id: u64);
    fn on_oracle_status(&self, status: OracleStatus);
}
