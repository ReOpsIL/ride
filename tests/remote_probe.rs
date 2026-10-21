use std::path::Path;
use std::process::Command;

use ride_engine::remote::{Check, Endpoint, RemoteError, Status, read_probe};

fn endpoint(local: &Path, remote: &Path) -> Endpoint {
    Endpoint::docker("ride-rust", "dev", None, local, remote).unwrap()
}

fn remote_script(endpoint: &Endpoint) -> String {
    let invocation = endpoint.probe().unwrap();
    assert_eq!(invocation.program, "ssh");
    invocation.args.last().unwrap().clone()
}

fn run_here(script: &str) -> String {
    let output = Command::new("sh").arg("-c").arg(script).output().unwrap();
    String::from_utf8_lossy(&output.stdout).into_owned()
}

fn status(checks: &[Check], title: &str) -> Status {
    checks
        .iter()
        .find(|check| check.title == title)
        .unwrap()
        .status
}

#[test]
fn a_missing_identity_fails_before_ssh_runs() {
    let local = tempfile::tempdir().unwrap();
    let endpoint = Endpoint::docker(
        "ride-rust",
        "dev",
        Some(Path::new("/nonexistent/ride_docker")),
        local.path(),
        Path::new("/work/demo"),
    )
    .unwrap();
    assert!(matches!(
        endpoint.probe(),
        Err(RemoteError::IdentityMissing { .. })
    ));
}

#[test]
fn a_relative_identity_names_the_expected_form() {
    let error = Endpoint::docker(
        "ride-rust",
        "dev",
        Some(Path::new("169c7e84f07c")),
        Path::new("/Users/me/ride"),
        Path::new("/work/ride"),
    )
    .unwrap_err();
    assert!(
        error
            .to_string()
            .contains("absolute path of an SSH private key")
    );
}

#[test]
fn the_script_reports_a_root_it_will_create() {
    let local = tempfile::tempdir().unwrap();
    std::fs::write(local.path().join("Cargo.toml"), "").unwrap();
    let remote = tempfile::tempdir().unwrap();
    let endpoint = endpoint(local.path(), &remote.path().join("work/demo"));
    let checks = read_probe(&endpoint, &run_here(&remote_script(&endpoint)));
    assert_eq!(status(&checks, "Connect"), Status::Pass);
    assert_eq!(status(&checks, "Remote Root"), Status::Pass);
    assert_eq!(status(&checks, "tar"), Status::Pass);
    assert!(checks.iter().any(|check| check.title == "cargo"));
    assert!(!checks.iter().any(|check| check.title == "cmake"));
}

#[test]
fn the_script_reports_an_existing_root() {
    let local = tempfile::tempdir().unwrap();
    let remote = tempfile::tempdir().unwrap();
    let endpoint = endpoint(local.path(), remote.path());
    let checks = read_probe(&endpoint, &run_here(&remote_script(&endpoint)));
    let root = checks
        .iter()
        .find(|check| check.title == "Remote Root")
        .unwrap();
    assert!(
        root.detail.contains("exists and is writable"),
        "{}",
        root.detail
    );
}

#[test]
fn a_missing_required_tool_fails_and_an_optional_one_warns() {
    let local = tempfile::tempdir().unwrap();
    std::fs::write(local.path().join("CMakeLists.txt"), "").unwrap();
    let endpoint = endpoint(local.path(), Path::new("/work/demo"));
    let output = "ride-probe login dev Linux aarch64\nride-probe root ready\nride-probe tool tar /usr/bin/tar\nride-probe tool cmake\nride-probe tool lldb-dap\n";
    let checks = read_probe(&endpoint, output);
    assert_eq!(status(&checks, "cmake"), Status::Fail);
    assert_eq!(status(&checks, "lldb-dap"), Status::Warn);
    assert_eq!(checks[0].detail, "Signed in as dev on Linux aarch64.");
}

#[test]
fn a_rejected_key_explains_the_login() {
    let endpoint = endpoint(Path::new("/Users/me/ride"), Path::new("/work/ride"));
    let checks = read_probe(&endpoint, "dev@127.0.0.1: Permission denied (publickey).\n");
    assert_eq!(checks.len(), 1);
    assert_eq!(checks[0].status, Status::Fail);
    assert!(
        checks[0]
            .detail
            .starts_with("The server rejected the login.")
    );
    assert!(checks[0].detail.ends_with("Permission denied (publickey)."));
}

#[test]
fn a_stopped_container_is_named_before_the_dropped_connection() {
    let endpoint = endpoint(Path::new("/Users/me/ride"), Path::new("/work/ride"));
    let output = "Error response from daemon: container 169c7e84f07c is not running\nkex_exchange_identification: Connection closed by remote host\n";
    let checks = read_probe(&endpoint, output);
    assert!(checks[0].detail.starts_with("The container is stopped."));
}
