use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::{Arc, Mutex};
use std::thread::sleep;
use std::time::{Duration, Instant};

use ride_engine::{
    Breakpoint, DebugCommand, DebugEvaluateContext, DebugEvent, DebugLaunch, DebugListener,
    DebugRegistry, DebugSession, DebugState, ExceptionFilter, find_adapter,
    probe_exception_filters,
};

const FAKE_ADAPTER: &str = env!("CARGO_BIN_EXE_fake-dap");

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
    scripted_with(&[], breakpoints)
}

fn scripted_with(
    arguments: &[String],
    breakpoints: Vec<Breakpoint>,
) -> (Arc<DebugSession>, Arc<Recorder>) {
    let listener = Arc::new(Recorder::default());
    let launch = DebugLaunch::program("/usr/bin/true");
    let session = DebugSession::start(
        Path::new(FAKE_ADAPTER),
        arguments,
        launch,
        breakpoints,
        listener.clone(),
    )
    .expect("start the scripted session");
    (session, listener)
}

#[test]
fn the_adapter_advertises_its_exception_filters() {
    let filters = probe_exception_filters(Path::new(FAKE_ADAPTER)).expect("probe the filters");
    assert_eq!(
        filters,
        vec![
            ExceptionFilter {
                id: "cpp_throw".to_string(),
                label: "C++ Throw".to_string(),
                default_on: true,
            },
            ExceptionFilter {
                id: "cpp_catch".to_string(),
                label: "C++ Catch".to_string(),
                default_on: false,
            },
        ]
    );
}

#[test]
fn the_launch_sends_only_the_advertised_enabled_filters() {
    let listener = Arc::new(Recorder::default());
    let mut launch = DebugLaunch::program("/usr/bin/true");
    launch.exception_filters = vec!["cpp_catch".to_string(), "swift_throw".to_string()];
    let session = DebugSession::start(
        Path::new(FAKE_ADAPTER),
        &[],
        launch,
        vec![Breakpoint::at("src/main.rs", 10)],
        listener.clone(),
    )
    .expect("start the scripted session");
    listener.wait("the breakpoint stop", |event| stopped(event, "breakpoint"));
    assert!(
        listener
            .output()
            .iter()
            .any(|line| line == "console: filters: cpp_catch\n"),
        "{:?}",
        listener.output()
    );
    let _ = session.command(DebugCommand::Disconnect);
}

fn alive(pid: u32) -> bool {
    Command::new("/bin/kill")
        .arg("-0")
        .arg(pid.to_string())
        .output()
        .map(|output| output.status.success())
        .unwrap_or(false)
}

fn adapter_pid(pid_file: &Path) -> u32 {
    let deadline = Instant::now() + Duration::from_secs(10);
    while Instant::now() < deadline {
        if let Ok(text) = std::fs::read_to_string(pid_file)
            && let Ok(pid) = text.trim().parse::<u32>()
        {
            return pid;
        }
        sleep(Duration::from_millis(20));
    }
    panic!("the fake adapter never wrote its pid");
}

fn until(what: &str, ready: impl Fn() -> bool) {
    let deadline = Instant::now() + Duration::from_secs(10);
    while Instant::now() < deadline {
        if ready() {
            return;
        }
        sleep(Duration::from_millis(20));
    }
    panic!("timed out waiting for {what}");
}

#[test]
fn a_stop_on_entry_launch_never_reports_running() {
    let (session, listener) = scripted(vec![Breakpoint::at("src/main.rs", 10)]);
    listener.wait("the breakpoint stop", |event| stopped(event, "breakpoint"));
    let events = listener.events();
    let stop = events
        .iter()
        .position(|event| matches!(event, DebugEvent::Stopped { .. }))
        .expect("a stopped event");
    assert!(matches!(events[0], DebugEvent::Launching), "{events:?}");
    assert!(
        !events[..stop]
            .iter()
            .any(|event| matches!(event, DebugEvent::Running)),
        "{events:?}"
    );
    let _ = session.command(DebugCommand::Disconnect);
}

#[test]
fn a_disconnect_kills_an_adapter_that_never_answers() {
    let pid_file = std::env::temp_dir().join("ride-fake-dap-disconnect.pid");
    let _ = std::fs::remove_file(&pid_file);
    let arguments = vec![
        "--ignore-disconnect".to_string(),
        "--pid-file".to_string(),
        pid_file.to_string_lossy().to_string(),
    ];
    let (session, listener) = scripted_with(&arguments, vec![Breakpoint::at("src/main.rs", 10)]);
    listener.wait("the breakpoint stop", |event| stopped(event, "breakpoint"));
    let pid = adapter_pid(&pid_file);
    assert!(alive(pid));

    let started = Instant::now();
    session
        .command(DebugCommand::Disconnect)
        .expect("disconnect");
    assert!(
        started.elapsed() < Duration::from_secs(10),
        "the disconnect blocked"
    );
    assert_eq!(session.state(), DebugState::Terminated);
    assert!(listener.saw(|event| matches!(event, DebugEvent::Terminated)));
    assert!(!alive(pid), "the adapter {pid} outlived the disconnect");
    assert!(session.threads().is_err());
    let _ = std::fs::remove_file(&pid_file);
}

#[test]
fn a_disconnected_session_leaves_the_registry() {
    let registry = Arc::new(DebugRegistry::default());
    let listener = Arc::new(Recorder::default());
    let id = registry
        .start(
            Path::new(FAKE_ADAPTER),
            &[],
            DebugLaunch::program("/usr/bin/true"),
            vec![Breakpoint::at("src/main.rs", 10)],
            listener.clone(),
        )
        .expect("start the registered session");
    let session = registry.get(id).expect("the registered session");
    listener.wait("the breakpoint stop", |event| stopped(event, "breakpoint"));
    session
        .command(DebugCommand::Disconnect)
        .expect("disconnect");
    until("the session to leave the registry", || {
        registry.get(id).is_none()
    });
    assert!(registry.reserve() > id, "the registry reused an id");
}

#[test]
fn a_failed_handshake_leaves_the_registry() {
    let registry = Arc::new(DebugRegistry::default());
    let listener = Arc::new(Recorder::default());
    let id = registry
        .start(
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
    until("the session to leave the registry", || {
        registry.get(id).is_none()
    });
    assert!(registry.reserve() > id, "the registry reused an id");
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
