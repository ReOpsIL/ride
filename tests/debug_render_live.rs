use std::fs;
use std::path::PathBuf;
use std::process::Command;
use std::sync::{Arc, Mutex};
use std::thread::sleep;
use std::time::{Duration, Instant};

use ride_engine::{
    Breakpoint, DebugCommand, DebugEvent, DebugLaunch, DebugListener, DebugSession, find_adapter,
};

#[derive(Default)]
struct Recorder {
    events: Mutex<Vec<DebugEvent>>,
}

impl DebugListener for Recorder {
    fn on_event(&self, event: DebugEvent) {
        self.events.lock().unwrap().push(event);
    }

    fn on_output(&self, _category: String, _text: String) {}
}

impl Recorder {
    fn wait(&self, what: &str, matches: impl Fn(&DebugEvent) -> bool) {
        let deadline = Instant::now() + Duration::from_secs(30);
        while Instant::now() < deadline {
            if self.events.lock().unwrap().iter().any(&matches) {
                return;
            }
            sleep(Duration::from_millis(20));
        }
        panic!("timed out waiting for {what}");
    }
}

fn developer_mode() -> bool {
    Command::new("/usr/sbin/DevToolsSecurity")
        .arg("-status")
        .output()
        .map(|output| String::from_utf8_lossy(&output.stdout).contains("enabled"))
        .unwrap_or(false)
}

fn values_crate() -> Option<(PathBuf, PathBuf)> {
    let root = std::env::temp_dir().join("ride-debug-render-values");
    fs::create_dir_all(root.join("src")).ok()?;
    fs::write(
        root.join("Cargo.toml"),
        b"[package]\nname = \"ride-values\"\nversion = \"0.1.0\"\nedition = \"2021\"\n",
    )
    .ok()?;
    fs::write(
        root.join("src/main.rs"),
        b"fn main() {\n    let numbers: Vec<u32> = vec![1, 2, 3];\n    let name: Option<String> = Some(\"ride\".to_string());\n    println!(\"{} {:?}\", numbers.len(), name);\n}\n",
    )
    .ok()?;
    let target = root.join("target");
    let built = Command::new("cargo")
        .arg("build")
        .arg("--manifest-path")
        .arg(root.join("Cargo.toml"))
        .arg("--target-dir")
        .arg(&target)
        .output()
        .ok()?;
    if !built.status.success() {
        return None;
    }
    let program = target.join("debug/ride-values");
    program.is_file().then_some((root, program))
}

#[test]
fn the_live_session_summarises_rust_values() {
    if !developer_mode() {
        eprintln!("skipped: macOS developer mode is disabled, lldb cannot launch a debuggee");
        return;
    }
    let Some(adapter) = find_adapter() else {
        eprintln!("skipped: lldb-dap was not found");
        return;
    };
    let Some((root, program)) = values_crate() else {
        eprintln!("skipped: the values crate did not build");
        return;
    };
    let mut launch = DebugLaunch::program(&program.to_string_lossy());
    launch.cwd = Some(root.to_string_lossy().to_string());
    let listener = Arc::new(Recorder::default());
    let source = root.join("src/main.rs");
    let breakpoint = Breakpoint::at(&source.to_string_lossy(), 4);
    let session = DebugSession::start(&adapter, &[], launch, vec![breakpoint], listener.clone())
        .expect("start the live session");
    listener.wait("the breakpoint stop", |event| {
        matches!(event, DebugEvent::Stopped { .. })
    });
    let threads = session.threads().expect("threads");
    let stack = session.stack(threads[0].id).expect("stackTrace");
    let scopes = session.scopes(stack[0].id).expect("scopes");
    let locals = scopes
        .iter()
        .find(|scope| scope.name.to_lowercase().contains("local"))
        .expect("a locals scope");
    let variables = session
        .variables(locals.variables_reference, 0, 0)
        .expect("variables");
    let numbers = variables
        .iter()
        .find(|variable| variable.name == "numbers")
        .expect("the vector local");
    let name = variables
        .iter()
        .find(|variable| variable.name == "name")
        .expect("the option local");
    assert!(numbers.value.contains("size=3"), "{numbers:?}");
    assert!(
        name.value.contains("ride") || name.value.contains("Some"),
        "{name:?}"
    );
    let _ = session.command(DebugCommand::Disconnect);
}
