const HINTS: [(&[&str], &str); 15] = [
    (
        &[
            "cannot connect to the docker daemon",
            "docker daemon socket",
        ],
        "Docker is not running on this Mac.",
    ),
    (
        &["no such container"],
        "Docker has no container with that name. docker ps lists running containers.",
    ),
    (
        &["is not running"],
        "The container is stopped. Start it with docker start <name>.",
    ),
    (
        &["pods \"", "notfound"],
        "Kubernetes has no pod with that name in this namespace.",
    ),
    (
        &[
            "executable file not found",
            "nc: not found",
            "nc: command not found",
        ],
        "The container has no nc. Ride tunnels SSH through it; install netcat in the image.",
    ),
    (
        &[
            "docker: command not found",
            "kubectl: command not found",
            "command not found: docker",
            "command not found: kubectl",
        ],
        "The proxy tool (docker or kubectl) is not on this Mac's PATH.",
    ),
    (
        &["remote host identification has changed"],
        "The host key changed. Remove the old one with ssh-keygen -R <host>, then connect once from Terminal.",
    ),
    (
        &["host key verification failed", "no matching host key"],
        "The host key is not in ~/.ssh/known_hosts. Ride cannot answer the prompt; connect once from Terminal first.",
    ),
    (
        &["bad permissions", "unprotected private key"],
        "The key file is readable by others. Run chmod 600 on it.",
    ),
    (
        &["invalid format", "error in libcrypto"],
        "Identity is not a private key. Pick the file without .pub.",
    ),
    (
        &["permission denied"],
        "The server rejected the login. Check User and Identity, and that the public key is in the remote ~/.ssh/authorized_keys.",
    ),
    (
        &["connection refused"],
        "Nothing is listening for SSH there. Check Host and Port, and that sshd is running.",
    ),
    (
        &["could not resolve hostname", "nodename nor servname"],
        "The host name does not resolve.",
    ),
    (
        &["timed out"],
        "No answer within 15 seconds. Check Host, Port, and the network.",
    ),
    (
        &[
            "kex_exchange_identification",
            "connection closed by",
            "connection reset",
        ],
        "The connection closed before login. sshd may not be running on the endpoint.",
    ),
];

const FALLBACK: &str = "SSH did not reach a shell on the endpoint.";

pub fn explain(output: &str) -> &'static str {
    let text = output.to_lowercase();
    HINTS
        .iter()
        .find(|(needles, _)| needles.iter().any(|needle| text.contains(needle)))
        .map_or(FALLBACK, |(_, hint)| hint)
}
