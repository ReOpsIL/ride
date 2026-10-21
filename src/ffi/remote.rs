#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum RemoteReach {
    Vm,
    Container,
    Pod,
    Docker,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct RemoteLink {
    pub kind: RemoteReach,
    pub user: String,
    pub host: String,
    pub port: u16,
    pub identity: String,
    pub proxy_command: String,
    pub local_root: String,
    pub remote_root: String,
    pub name: String,
    pub namespace: String,
    pub container: String,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct RemoteCommand {
    pub program: String,
    pub args: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct RemoteSync {
    pub pack: RemoteCommand,
    pub unpack: RemoteCommand,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum RemoteCheckStatus {
    Pass,
    Warn,
    Fail,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct RemoteCheck {
    pub title: String,
    pub status: RemoteCheckStatus,
    pub detail: String,
}
