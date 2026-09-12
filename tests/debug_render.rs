use std::fs;
use std::path::Path;
use std::sync::{Arc, Mutex};
use std::thread::sleep;
use std::time::{Duration, Instant};

use ride_engine::debug::render::{init_commands, toolchain_init_commands};
use ride_engine::{Breakpoint, DebugCommand, DebugEvent, DebugLaunch, DebugListener, DebugSession};

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
    assert!(toolchain_init_commands(false).is_empty());
}

#[test]
fn a_sysroot_without_the_scripts_gets_no_init_commands() {
    let root = sysroot_with(&[]);
    assert!(init_commands(Some(root.path()), true).is_empty());
    assert!(init_commands(None, true).is_empty());
}

fn launched(cwd: Option<&Path>) -> Arc<Recorder> {
    let listener = Arc::new(Recorder::default());
    let mut launch = DebugLaunch::program("/usr/bin/true");
    launch.cwd = cwd.map(|path| path.to_string_lossy().to_string());
    let session = DebugSession::start(
        Path::new(FAKE_ADAPTER),
        &[],
        launch,
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
fn the_launch_request_carries_the_rust_init_commands() {
    let root = tempfile::tempdir().expect("a temp crate");
    fs::write(root.path().join("Cargo.toml"), b"[package]\n").expect("the manifest");
    let listener = launched(Some(root.path()));
    let expected = toolchain_init_commands(true).join(" | ");
    let line = listener.line("initCommands:");
    assert_eq!(line, format!("initCommands: {expected}"));
    assert!(
        expected.is_empty() || line.contains("lldb_lookup.py"),
        "{line}"
    );
}

#[test]
fn the_launch_request_of_a_non_rust_target_carries_none() {
    let listener = launched(None);
    assert_eq!(listener.line("initCommands:"), "initCommands:");
}
