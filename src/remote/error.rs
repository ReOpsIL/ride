#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum RemoteError {
    #[error("User \"{user}\" is not a login name. Use letters, digits, '.', '_' or '-'.")]
    User { user: String },
    #[error("Host \"{host}\" is not a host name or IPv4 address.")]
    Host { host: String },
    #[error("Port must be between 1 and 65535.")]
    Port,
    #[error(
        "\"{name}\" is not a container, pod, or namespace name. Use letters, digits, '.', '_' or '-'."
    )]
    Name { name: String },
    #[error("Proxy command is empty or contains control characters.")]
    Proxy,
    #[error(
        "Identity must be the absolute path of an SSH private key on this Mac, such as /Users/you/.ssh/id_ed25519. Got \"{path}\"."
    )]
    Identity { path: String },
    #[error("No SSH private key at {path} on this Mac.")]
    IdentityMissing { path: String },
    #[error("Remote Root must be an absolute directory other than /. Got \"{path}\".")]
    Root { path: String },
    #[error("path is outside the mapped root: {path}")]
    Outside { path: String },
    #[error("empty command")]
    EmptyCommand,
    #[error("env name {name}")]
    EnvName { name: String },
    #[error("path {path} is not UTF-8")]
    Path { path: String },
    #[error("a value cannot be quoted for the remote shell")]
    Quote,
}
