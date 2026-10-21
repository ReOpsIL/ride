mod debug_support;

use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::thread::sleep;
use std::time::Duration;

use debug_support::{Recorder, alive, stopped, until};
use ride_engine::{
    AttachProcess, Breakpoint, DebugAttach, DebugCommand, DebugEvent, DebugLaunch, DebugSession,
    DebugState, DebugTarget, list_processes, parse_processes,
};
use serde_json::Value;

const FAKE_ADAPTER: &str = env!("CARGO_BIN_EXE_fake-dap");

struct Journal {
    path: PathBuf,
}

impl Journal {
    fn new(name: &str) -> Self {
        let path = std::env::temp_dir().join(format!(
            "ride-debug-attach-{name}-{}.jsonl",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&path);
        Self { path }
    }

    fn flags(&self, extra: &[&str]) -> Vec<String> {
        let mut flags = vec!["--journal".to_string(), self.path.display().to_string()];
        flags.extend(extra.iter().map(|flag| flag.to_string()));
        flags
    }

    fn arguments(&self, command: &str) -> Value {
        let text = std::fs::read_to_string(&self.path).unwrap_or_default();
        text.lines()
            .filter_map(|line| serde_json::from_str::<Value>(line).ok())
            .find(|message| message["command"] == command)
            .map(|message| message["arguments"].clone())
            .unwrap_or_else(|| panic!("no {command} request in {text}"))
    }
}

impl Drop for Journal {
    fn drop(&mut self) {
        let _ = std::fs::remove_file(&self.path);
    }
}

fn start(
    flags: &[String],
    target: impl Into<DebugTarget>,
    breakpoints: Vec<Breakpoint>,
) -> (Arc<DebugSession>, Arc<Recorder>) {
    let listener = Arc::new(Recorder::default());
    let session = DebugSession::start(
        Path::new(FAKE_ADAPTER),
        flags,
        target,
        None,
        breakpoints,
        listener.clone(),
    )
    .expect("start the scripted session");
    (session, listener)
}

fn disconnect(session: &DebugSession, listener: &Recorder) {
    session
        .command(DebugCommand::Disconnect)
        .expect("disconnect");
    listener.wait("termination", |event| {
        matches!(event, DebugEvent::Terminated)
    });
}

#[test]
fn an_attach_by_pid_sends_only_the_pid_and_stops_at_the_breakpoint() {
    let journal = Journal::new("pid");
    let attach = DebugAttach {
        process: AttachProcess::Pid {
            pid: 4242,
            program: Some("/usr/bin/true".to_string()),
        },
        cwd: None,
        exception_filters: Vec::new(),
    };
    let (session, listener) = start(
        &journal.flags(&[]),
        attach,
        vec![Breakpoint::at("src/main.rs", 10)],
    );
    listener.wait("the breakpoint stop", |event| stopped(event, "breakpoint"));
    let arguments = journal.arguments("attach");
    assert_eq!(arguments["pid"], 4242, "{arguments}");
    assert!(arguments.get("program").is_none(), "{arguments}");
    assert!(arguments.get("waitFor").is_none(), "{arguments}");
    assert_eq!(session.stack(1).expect("stackTrace")[0].line, 10);
    disconnect(&session, &listener);
}

#[test]
fn a_wait_for_attach_names_the_program_and_waits() {
    let journal = Journal::new("wait");
    let (session, listener) = start(
        &journal.flags(&[]),
        DebugAttach::wait_for("debugger-lab"),
        vec![Breakpoint::at("src/fork.rs", 44)],
    );
    listener.wait("the breakpoint stop", |event| stopped(event, "breakpoint"));
    let arguments = journal.arguments("attach");
    assert_eq!(arguments["program"], "debugger-lab", "{arguments}");
    assert_eq!(arguments["waitFor"], true, "{arguments}");
    assert!(arguments.get("pid").is_none(), "{arguments}");
    disconnect(&session, &listener);
}

#[test]
fn stopping_an_attached_session_detaches() {
    let journal = Journal::new("detach");
    let (session, listener) = start(&journal.flags(&[]), DebugAttach::pid(7), Vec::new());
    listener.wait("the stop", |event| stopped(event, "breakpoint"));
    disconnect(&session, &listener);
    assert_eq!(journal.arguments("disconnect")["terminateDebuggee"], false);
}

#[test]
fn stopping_a_launched_session_terminates_the_debuggee() {
    let journal = Journal::new("terminate");
    let (session, listener) = start(
        &journal.flags(&[]),
        DebugLaunch::program("/usr/bin/true"),
        Vec::new(),
    );
    listener.wait("the stop", |event| stopped(event, "breakpoint"));
    disconnect(&session, &listener);
    assert_eq!(journal.arguments("disconnect")["terminateDebuggee"], true);
}

#[test]
fn stopping_while_waiting_for_the_process_ends_the_session_once() {
    let journal = Journal::new("hold");
    let pid_file =
        std::env::temp_dir().join(format!("ride-debug-attach-hold-{}.pid", std::process::id()));
    let _ = std::fs::remove_file(&pid_file);
    let mut flags = journal.flags(&["--hold-attach", "--pid-file"]);
    flags.push(pid_file.display().to_string());
    let (session, listener) = start(&flags, DebugAttach::wait_for("never-started"), Vec::new());
    until("the adapter pid", || pid_file.is_file());
    let pid: u32 = std::fs::read_to_string(&pid_file)
        .expect("the pid file")
        .trim()
        .parse()
        .expect("a pid");
    until("the attach request", || {
        std::fs::read_to_string(&journal.path).is_ok_and(|text| text.contains("\"attach\""))
    });
    sleep(Duration::from_millis(200));
    assert_eq!(session.state(), DebugState::Launching);
    disconnect(&session, &listener);
    until("the adapter to exit", || !alive(pid));
    sleep(Duration::from_millis(300));
    assert_eq!(
        listener.count(|event| matches!(event, DebugEvent::Terminated)),
        1,
        "{:?}",
        listener.events()
    );
    assert!(
        !listener.saw(|event| matches!(event, DebugEvent::Failed { .. })),
        "{:?}",
        listener.events()
    );
    let _ = std::fs::remove_file(&pid_file);
}

#[test]
fn the_process_listing_parses_paths_with_spaces_newest_first() {
    let listing = "  364     1 /System/Library/CoreServices/IOUIAgent\n\
                   6694  6686 /Applications/Claude.app/Contents/Frameworks/Claude Helper.app/Contents/MacOS/Claude Helper\n\
                   31550 31548 ./target/debug/debugger-lab\n\
                   garbage\n\
                   \n";
    let processes = parse_processes(listing);
    let summary: Vec<(u32, u32, &str)> = processes
        .iter()
        .map(|process| (process.pid, process.parent, process.name.as_str()))
        .collect();
    assert_eq!(
        summary,
        vec![
            (31550, 31548, "debugger-lab"),
            (6694, 6686, "Claude Helper"),
            (364, 1, "IOUIAgent"),
        ]
    );
    assert_eq!(processes[0].path, "./target/debug/debugger-lab");
}

#[test]
fn the_live_process_listing_includes_this_test() {
    let processes = list_processes().expect("list the processes");
    let me = processes
        .iter()
        .find(|process| process.pid == std::process::id())
        .expect("this test process");
    assert!(me.name.starts_with("debug_attach"), "{me:?}");
}
