use std::path::{Path, PathBuf};

use ride_engine::remote::{
    Endpoint, PathMap, Reach, RemoteError, from_link, map_launch, to_local, to_remote,
};
use ride_engine::{DebugLaunch, RemoteLink, RemoteReach};

fn vm() -> Endpoint {
    Endpoint::vm(
        "dev",
        "builder",
        22,
        Some(Path::new("/Users/me/.ssh/id_ed25519")),
        Path::new("/Users/me/ride"),
        Path::new("/src/ride"),
    )
    .unwrap()
}

fn command(endpoint: &Endpoint, cwd: &Path, env: &[(&str, &str)], argv: &[&str]) -> String {
    let invocation = endpoint.invocation(cwd, env, argv).unwrap();
    assert_eq!(invocation.program, "ssh");
    let split = invocation.args.iter().position(|arg| arg == "--").unwrap();
    assert_eq!(split, invocation.args.len() - 2);
    invocation.args[split + 1].clone()
}

#[test]
fn a_vm_command_has_no_tty_and_fails_closed() {
    let invocation = vm()
        .invocation(Path::new("/Users/me/ride"), &[], &["cargo", "build"])
        .unwrap();
    assert_eq!(
        invocation.args,
        vec![
            "-o",
            "BatchMode=yes",
            "-o",
            "RequestTTY=no",
            "-o",
            "ConnectTimeout=15",
            "-o",
            "ServerAliveInterval=30",
            "-o",
            "ServerAliveCountMax=4",
            "-p",
            "22",
            "-o",
            "IdentitiesOnly=yes",
            "-i",
            "/Users/me/.ssh/id_ed25519",
            "dev@builder",
            "--",
            "cd /src/ride && exec cargo build",
        ]
        .into_iter()
        .map(str::to_string)
        .collect::<Vec<_>>()
    );
}

#[test]
fn metacharacters_stay_inside_the_remote_command() {
    let command = command(
        &vm(),
        Path::new("/Users/me/ride"),
        &[("RUST_BACKTRACE", "1")],
        &["cargo", "test", "--", "$(whoami)", "hello world"],
    );
    assert_eq!(
        command,
        "cd /src/ride && exec env 'RUST_BACKTRACE=1' cargo test -- '$(whoami)' 'hello world'"
    );
}

#[test]
fn a_local_absolute_arg_is_mapped_and_a_remote_one_is_kept() {
    let endpoint = vm();
    let built = command(
        &endpoint,
        Path::new("src"),
        &[],
        &[
            "/Users/me/ride/target/../target/debug/demo",
            "/src/ride/target/debug/demo",
            "cargo",
        ],
    );
    assert_eq!(
        built,
        "cd /src/ride/src && exec /src/ride/target/debug/demo /src/ride/target/debug/demo cargo"
    );
    let remote_cwd = command(
        &endpoint,
        Path::new("/src/ride/pkg"),
        &[],
        &["cargo", "test"],
    );
    assert_eq!(remote_cwd, "cd /src/ride/pkg && exec cargo test");
}

#[test]
fn a_path_outside_the_mapped_root_is_rejected() {
    let endpoint = vm();
    let err = endpoint
        .invocation(Path::new("/Users/me/ride"), &[], &["/usr/bin/cargo"])
        .unwrap_err();
    assert_eq!(
        err,
        RemoteError::Outside {
            path: "/usr/bin/cargo".to_string(),
        }
    );
    let escaped = endpoint
        .invocation(Path::new("../secret"), &[], &["cargo", "build"])
        .unwrap_err();
    assert!(matches!(escaped, RemoteError::Outside { .. }));
}

#[test]
fn the_prefix_map_uses_path_components() {
    let endpoint = Endpoint::vm(
        "dev",
        "builder",
        22,
        None,
        Path::new("/work"),
        Path::new("/src"),
    )
    .unwrap();
    assert_eq!(
        to_remote(
            endpoint.local_root(),
            endpoint.remote_root(),
            Path::new("/work")
        )
        .unwrap(),
        PathBuf::from("/src")
    );
    assert_eq!(
        to_remote(
            endpoint.local_root(),
            endpoint.remote_root(),
            Path::new("/work/src/main.rs")
        )
        .unwrap(),
        PathBuf::from("/src/src/main.rs")
    );
    assert!(matches!(
        to_remote(
            endpoint.local_root(),
            endpoint.remote_root(),
            Path::new("/workspace/src")
        )
        .unwrap_err(),
        RemoteError::Outside { .. }
    ));
    assert_eq!(
        to_local(
            endpoint.local_root(),
            endpoint.remote_root(),
            Path::new("/src/src/main.rs")
        )
        .unwrap(),
        PathBuf::from("/work/src/main.rs")
    );
}

#[test]
fn docker_and_pod_are_ssh_endpoints() {
    let local = Path::new("/Users/me/ride");
    let remote = Path::new("/src/ride");
    let docker = Endpoint::docker("app", "root", None, local, remote).unwrap();
    assert_eq!(docker.reach(), Reach::Docker);
    assert_eq!(docker.host(), "127.0.0.1");
    assert_eq!(docker.port(), 22);
    assert_eq!(docker.proxy_command(), Some("docker exec -i app nc %h %p"));
    let pod = Endpoint::pod("builds", "job", Some("runner"), "root", None, local, remote).unwrap();
    assert_eq!(pod.reach(), Reach::Pod);
    assert_eq!(
        pod.proxy_command(),
        Some("kubectl exec -i -n builds job -c runner -- nc %h %p")
    );
    let plain = Endpoint::pod("builds", "job", None, "root", None, local, remote).unwrap();
    assert_eq!(
        plain.proxy_command(),
        Some("kubectl exec -i -n builds job -- nc %h %p")
    );
}

#[test]
fn presets_reject_a_destination_that_cannot_be_one_ssh_token() {
    let local = Path::new("/Users/me/ride");
    let remote = Path::new("/src/ride");
    assert!(matches!(
        Endpoint::vm("dev", "builder", 0, None, local, remote).unwrap_err(),
        RemoteError::Port
    ));
    assert!(matches!(
        Endpoint::docker("-rf", "root", None, local, remote).unwrap_err(),
        RemoteError::Name { .. }
    ));
    assert!(matches!(
        Endpoint::pod("builds", "a..b", None, "root", None, local, remote).unwrap_err(),
        RemoteError::Name { .. }
    ));
    assert!(matches!(
        Endpoint::vm("dev", "::1", 22, None, local, remote).unwrap_err(),
        RemoteError::Host { .. }
    ));
    assert!(matches!(
        Endpoint::container("dev", "builder", 22, None, Some("nc\n%h"), local, remote).unwrap_err(),
        RemoteError::Proxy
    ));
    assert!(matches!(
        Endpoint::vm("dev", "builder", 22, None, Path::new("/"), remote).unwrap_err(),
        RemoteError::Root { .. }
    ));
}

#[test]
fn sync_packs_the_local_root_and_unpacks_it_over_ssh() {
    let job = vm().sync().unwrap();
    assert_eq!(job.pack.program, "tar");
    assert_eq!(
        job.pack.args,
        [
            "-c",
            "-C",
            "/Users/me/ride",
            "--exclude",
            "target",
            "--exclude",
            "build",
            "--exclude",
            ".git",
            "."
        ]
        .into_iter()
        .map(str::to_string)
        .collect::<Vec<_>>()
    );
    assert_eq!(job.unpack.program, "ssh");
    assert!(job.unpack.args.iter().any(|arg| arg == "RequestTTY=no"));
    let command = job.unpack.args.last().unwrap();
    assert_eq!(command, "mkdir -p /src/ride && tar -x -C /src/ride");
}

#[test]
fn a_debug_launch_is_mapped_onto_the_remote_root() {
    let mut launch = DebugLaunch::program("/Users/me/ride/target/debug/demo");
    launch.cwd = Some("/Users/me/ride".to_string());
    launch.args = vec!["--flag".to_string()];
    let mapped = map_launch(&vm(), launch).unwrap();
    assert_eq!(mapped.program, "/src/ride/target/debug/demo");
    assert_eq!(mapped.cwd.as_deref(), Some("/src/ride"));
    assert_eq!(mapped.args, vec!["--flag".to_string()]);
    let outside = DebugLaunch::program("/usr/bin/demo");
    assert!(matches!(
        map_launch(&vm(), outside).unwrap_err(),
        RemoteError::Outside { .. }
    ));
}

#[test]
fn an_unmapped_frame_path_is_left_alone() {
    let map = vm().path_map();
    assert_eq!(
        map.to_remote_str("/Users/me/ride/src/main.rs"),
        "/src/ride/src/main.rs"
    );
    assert_eq!(
        map.to_local_str("/src/ride/src/main.rs"),
        "/Users/me/ride/src/main.rs"
    );
    assert_eq!(
        map.to_local_str("/usr/lib/libSystem.dylib"),
        "/usr/lib/libSystem.dylib"
    );
}

#[test]
fn a_docker_link_becomes_the_preset_proxy() {
    let mut link = sample_link(RemoteReach::Docker);
    link.name = "app".to_string();
    link.identity.clear();
    let endpoint = from_link(&link).unwrap();
    assert_eq!(endpoint.reach(), Reach::Docker);
    assert_eq!(endpoint.host(), "127.0.0.1");
    assert_eq!(
        endpoint.proxy_command(),
        Some("docker exec -i app nc %h %p")
    );
    let _: PathMap = endpoint.path_map();
}

fn sample_link(kind: RemoteReach) -> RemoteLink {
    RemoteLink {
        kind,
        user: "dev".to_string(),
        host: "builder".to_string(),
        port: 22,
        identity: "/Users/me/.ssh/id_ed25519".to_string(),
        proxy_command: String::new(),
        local_root: "/Users/me/ride".to_string(),
        remote_root: "/src/ride".to_string(),
        name: String::new(),
        namespace: String::new(),
        container: String::new(),
    }
}
