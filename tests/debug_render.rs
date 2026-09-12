use std::fs;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::thread::sleep;
use std::time::{Duration, Instant};

use ride_engine::debug::render::init_commands;
use ride_engine::{
    Breakpoint, DebugCommand, DebugEvent, DebugLaunch, DebugListener, DebugSession, EngineConfig,
    sysroot_path,
};

const FAKE_ADAPTER: &str = env!("CARGO_BIN_EXE_fake-dap");
const LOOKUP: &str = "lib/rustlib/etc/lldb_lookup.py";
const COMMANDS: &str = "lib/rustlib/etc/lldb_commands";

#[derive(Default)]
struct Recorder {
    events: Mutex<Vec<DebugEvent>>,
    output: Mutex<Vec<String>>,
}

impl DebugListener for Recorder {
    fn on_event(&self, event: DebugEvent) {
        self.events.lock().unwrap().push(event);
    }

    fn on_output(&self, _category: String, text: String) {
        self.output.lock().unwrap().push(text);
    }
}

impl Recorder {
    fn line(&self, prefix: &str) -> String {
        let deadline = Instant::now() + Duration::from_secs(20);
        while Instant::now() < deadline {
            let found = self
                .output
                .lock()
                .unwrap()
                .iter()
                .find(|line| line.starts_with(prefix))
                .cloned();
            if let Some(line) = found {
                return line.trim_end().to_string();
            }
            sleep(Duration::from_millis(20));
        }
        panic!("timed out waiting for {prefix}");
    }

    fn wait(&self, what: &str, matches: impl Fn(&DebugEvent) -> bool) {
        let deadline = Instant::now() + Duration::from_secs(20);
        while Instant::now() < deadline {
            if self.events.lock().unwrap().iter().any(&matches) {
                return;
            }
            sleep(Duration::from_millis(20));
        }
        panic!("timed out waiting for {what}");
    }
}

fn sysroot_with(files: &[&str]) -> tempfile::TempDir {
    let root = tempfile::tempdir().expect("a temp sysroot");
    for file in files {
        let path = root.path().join(file);
        fs::create_dir_all(path.parent().expect("a parent")).expect("the etc directory");
        fs::write(&path, b"").expect("the script");
    }
    root
}

#[test]
fn the_lookup_script_is_imported_when_the_sysroot_ships_it() {
    let root = sysroot_with(&[LOOKUP]);
    let commands = init_commands(Some(root.path()), true);
    assert_eq!(
        commands,
        vec![format!(
            "command script import \"{}\"",
            root.path().join(LOOKUP).display()
        )]
    );
}

#[test]
fn the_lldb_commands_file_is_sourced_when_present() {
    let root = sysroot_with(&[LOOKUP, COMMANDS]);
    let commands = init_commands(Some(root.path()), true);
    assert_eq!(commands.len(), 2, "{commands:?}");
    assert!(commands[1].starts_with("command source"), "{commands:?}");
    assert!(commands[1].contains("lldb_commands"), "{commands:?}");
}

#[test]
fn a_non_rust_target_gets_no_init_commands() {
    let root = sysroot_with(&[LOOKUP, COMMANDS]);
    assert!(init_commands(Some(root.path()), false).is_empty());
}

#[test]
fn a_sysroot_without_the_scripts_gets_no_init_commands() {
    let root = sysroot_with(&[]);
    assert!(init_commands(Some(root.path()), true).is_empty());
    assert!(init_commands(None, true).is_empty());
}

fn configured(sysroot: &Path) -> Option<PathBuf> {
    let config = EngineConfig {
        index_dir: String::new(),
        cargo_home: None,
        sysroot: Some(sysroot.to_string_lossy().to_string()),
        offline_metadata: true,
    };
    sysroot_path(&config).expect("the configured sysroot")
}

fn launched(program: &str, cwd: Option<&Path>, sysroot: Option<PathBuf>) -> Arc<Recorder> {
    let listener = Arc::new(Recorder::default());
    let mut launch = DebugLaunch::program(program);
    launch.cwd = cwd.map(|path| path.to_string_lossy().to_string());
    let session = DebugSession::start(
        Path::new(FAKE_ADAPTER),
        &[],
        launch,
        sysroot,
        vec![Breakpoint::at("src/main.rs", 10)],
        listener.clone(),
    )
    .expect("start the scripted session");
    listener.wait("the breakpoint stop", |event| {
        matches!(event, DebugEvent::Stopped { .. })
    });
    let _ = session.command(DebugCommand::Disconnect);
    listener
}

#[test]
fn the_launch_request_carries_the_configured_sysroot() {
    let root = tempfile::tempdir().expect("a temp crate");
    fs::write(root.path().join("Cargo.toml"), b"[package]\n").expect("the manifest");
    let sysroot = sysroot_with(&[LOOKUP, COMMANDS]);
    let listener = launched(
        "/usr/bin/true",
        Some(root.path()),
        configured(sysroot.path()),
    );
    let expected = init_commands(Some(sysroot.path()), true).join(" | ");
    assert_eq!(
        listener.line("initCommands:"),
        format!("initCommands: {expected}")
    );
    assert!(expected.contains("lldb_lookup.py"), "{expected}");
}

#[test]
fn a_crate_below_the_working_directory_root_is_a_rust_target() {
    let root = tempfile::tempdir().expect("a temp crate");
    fs::write(root.path().join("Cargo.toml"), b"[package]\n").expect("the manifest");
    let nested = root.path().join("src/inner");
    fs::create_dir_all(&nested).expect("the nested directory");
    let sysroot = sysroot_with(&[LOOKUP]);
    let listener = launched("/usr/bin/true", Some(&nested), configured(sysroot.path()));
    assert!(
        listener.line("initCommands:").contains("lldb_lookup.py"),
        "the manifest above the working directory makes it a rust target"
    );
}

#[test]
fn a_target_directory_without_a_manifest_is_not_a_rust_target() {
    let root = tempfile::tempdir().expect("a temp project");
    let binary = root.path().join("target/debug/demo");
    fs::create_dir_all(binary.parent().expect("a parent")).expect("the build directory");
    let sysroot = sysroot_with(&[LOOKUP, COMMANDS]);
    let listener = launched(
        &binary.to_string_lossy(),
        Some(root.path()),
        configured(sysroot.path()),
    );
    assert_eq!(listener.line("initCommands:"), "initCommands:");
}

#[test]
fn the_launch_request_of_a_non_rust_target_carries_none() {
    let sysroot = sysroot_with(&[LOOKUP, COMMANDS]);
    let listener = launched("/usr/bin/true", None, configured(sysroot.path()));
    assert_eq!(listener.line("initCommands:"), "initCommands:");
}
