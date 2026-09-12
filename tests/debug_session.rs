use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::{Arc, Mutex};
use std::thread::sleep;
use std::time::{Duration, Instant};

use ride_engine::{
    Breakpoint, DebugCommand, DebugEvaluateContext, DebugEvent, DebugLaunch, DebugListener,
    DebugSession, DebugState, find_adapter,
};

#[derive(Default)]
struct Recorder {
    events: Mutex<Vec<DebugEvent>>,
    output: Mutex<Vec<String>>,
}

impl DebugListener for Recorder {
    fn on_event(&self, event: DebugEvent) {
        self.events.lock().unwrap().push(event);
    }

    fn on_output(&self, category: String, text: String) {
        self.output
            .lock()
            .unwrap()
            .push(format!("{category}: {text}"));
    }
}

impl Recorder {
    fn events(&self) -> Vec<DebugEvent> {
        self.events.lock().unwrap().clone()
    }

    fn output(&self) -> Vec<String> {
        self.output.lock().unwrap().clone()
    }

    fn saw(&self, matches: impl Fn(&DebugEvent) -> bool) -> bool {
        self.events().iter().any(matches)
    }

    fn wait(&self, what: &str, matches: impl Fn(&DebugEvent) -> bool) -> DebugEvent {
        let deadline = Instant::now() + Duration::from_secs(20);
        while Instant::now() < deadline {
            if let Some(event) = self.events().into_iter().find(&matches) {
                return event;
            }
            sleep(Duration::from_millis(20));
        }
        panic!("timed out waiting for {what}, saw {:?}", self.events());
    }
}

fn stopped(event: &DebugEvent, expected: &str) -> bool {
    matches!(event, DebugEvent::Stopped { reason, .. } if reason == expected)
}

fn scripted(breakpoints: Vec<Breakpoint>) -> (Arc<DebugSession>, Arc<Recorder>) {
    let listener = Arc::new(Recorder::default());
    let launch = DebugLaunch::program("/usr/bin/true");
    let session = DebugSession::start(
        Path::new(env!("CARGO_BIN_EXE_fake-dap")),
        &[],
        launch,
        breakpoints,
        listener.clone(),
    )
    .expect("start the scripted session");
    (session, listener)
}

#[test]
fn the_scripted_session_stops_inspects_and_steps() {
    let (session, listener) = scripted(vec![Breakpoint::at("src/main.rs", 10)]);
    let stop = listener.wait("the breakpoint stop", |event| stopped(event, "breakpoint"));
    let DebugEvent::Stopped {
        thread_id,
        hit_breakpoint_ids,
        ..
    } = stop
    else {
        panic!("a stopped event");
    };
    assert_eq!(thread_id, 1);
    assert_eq!(hit_breakpoint_ids, vec![1]);
    assert_eq!(
        session.state(),
        DebugState::Stopped {
            thread_id: 1,
            reason: "breakpoint".to_string()
        }
    );
    assert!(listener.saw(|event| matches!(event, DebugEvent::Launching)));
    assert!(
        listener
            .output()
            .iter()
            .any(|line| line.starts_with("console: fake adapter ready")),
        "{:?}",
        listener.output()
    );
    assert!(session.breakpoints("src/main.rs")[0].verified);

    let threads = session.threads().expect("threads");
    assert_eq!(threads.len(), 1);
    assert_eq!(threads[0].name, "main");

    let stack = session.stack(threads[0].id).expect("stackTrace");
    assert_eq!(stack[0].name, "main");
    assert_eq!(stack[0].line, 10);
    assert!(stack[0].path.as_deref().unwrap().ends_with("main.rs"));

    let scopes = session.scopes(stack[0].id).expect("scopes");
    assert_eq!(scopes[0].name, "Locals");
    assert!(!scopes[0].expensive);

    let variables = session
        .variables(scopes[0].variables_reference, 0, 0)
        .expect("variables");
    let counter = variables
        .iter()
        .find(|variable| variable.name == "counter")
        .expect("a counter local");
    assert!(counter.variables_reference != 0);
    assert_eq!(counter.children_count, 1);

    let evaluated = session
        .evaluate(stack[0].id, "counter", DebugEvaluateContext::Watch)
        .expect("evaluate");
    assert_eq!(evaluated.value, "7");

    session.command(DebugCommand::Next).expect("next");
    listener.wait("the step stop", |event| stopped(event, "step"));
    let stack = session.stack(threads[0].id).expect("stackTrace after next");
    assert_eq!(stack[0].line, 11);

    session
        .command(DebugCommand::Disconnect)
        .expect("disconnect");
    listener.wait("termination", |event| {
        matches!(event, DebugEvent::Terminated)
    });
    assert_eq!(session.state(), DebugState::Terminated);
}

#[test]
fn breakpoints_can_be_edited_while_the_session_runs() {
    let (session, listener) = scripted(vec![Breakpoint::at("src/main.rs", 10)]);
    listener.wait("the breakpoint stop", |event| stopped(event, "breakpoint"));
    let mut edited = Breakpoint::at("src/util.rs", 4);
    edited.condition = Some("events > 1".to_string());
    let stored = session
        .set_breakpoints("src/util.rs", vec![edited])
        .expect("setBreakpoints");
    assert_eq!(stored.len(), 1);
    assert!(stored[0].verified);
    assert_eq!(session.breakpoints("src/util.rs"), stored);
    assert!(listener.saw(
        |event| matches!(event, DebugEvent::Breakpoints { path, .. } if path == "src/util.rs")
    ));
    let _ = session.command(DebugCommand::Disconnect);
}

#[test]
fn a_handshake_against_a_silent_adapter_fails() {
    let listener = Arc::new(Recorder::default());
    let session = DebugSession::start(
        Path::new("/usr/bin/true"),
        &[],
        DebugLaunch::program("/usr/bin/true"),
        Vec::new(),
        listener.clone(),
    )
    .expect("spawn the silent adapter");
    listener.wait("a failure", |event| {
        matches!(event, DebugEvent::Failed { .. })
    });
    assert_eq!(session.state(), DebugState::Terminated);
}

fn developer_mode() -> bool {
    Command::new("/usr/sbin/DevToolsSecurity")
        .arg("-status")
        .output()
        .map(|output| String::from_utf8_lossy(&output.stdout).contains("enabled"))
        .unwrap_or(false)
}

fn demo_binary() -> Option<PathBuf> {
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("samples/rust-demo");
    let target = std::env::temp_dir().join("ride-debug-session-demo");
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
    let program = target.join("debug/ride-demo");
    program.is_file().then_some(program)
}

#[test]
fn the_live_adapter_stops_in_the_rust_demo() {
    if !developer_mode() {
        eprintln!("skipped: macOS developer mode is disabled, lldb cannot launch a debuggee");
        return;
    }
    let Some(adapter) = find_adapter() else {
        eprintln!("skipped: lldb-dap was not found");
        return;
    };
    let Some(program) = demo_binary() else {
        eprintln!("skipped: the rust-demo sample did not build");
        return;
    };
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("samples/rust-demo");
    let source = root.join("src/main.rs");
    let mut launch = DebugLaunch::program(&program.to_string_lossy());
    launch.cwd = Some(root.to_string_lossy().to_string());
    let listener = Arc::new(Recorder::default());
    let breakpoint = Breakpoint::at(&source.to_string_lossy(), 10);
    let session = DebugSession::start(&adapter, &[], launch, vec![breakpoint], listener.clone())
        .expect("start the live session");

    listener.wait("the breakpoint stop", |event| stopped(event, "breakpoint"));
    let threads = session.threads().expect("threads");
    let stack = session.stack(threads[0].id).expect("stackTrace");
    assert!(stack[0].name.contains("main"), "{:?}", stack[0]);
    assert_eq!(stack[0].line, 10);

    let scopes = session.scopes(stack[0].id).expect("scopes");
    let locals = scopes
        .iter()
        .find(|scope| scope.name.to_lowercase().contains("local"))
        .expect("a locals scope");
    let variables = session
        .variables(locals.variables_reference, 0, 0)
        .expect("variables");
    assert!(
        variables.iter().any(|variable| variable.name == "counter"),
        "{variables:?}"
    );

    session.command(DebugCommand::Next).expect("next");
    listener.wait("the step stop", |event| stopped(event, "step"));
    let stack = session.stack(threads[0].id).expect("stackTrace after next");
    assert_eq!(stack[0].line, 11);

    session
        .command(DebugCommand::Disconnect)
        .expect("disconnect");
    listener.wait("termination", |event| {
        matches!(event, DebugEvent::Terminated)
    });
}
