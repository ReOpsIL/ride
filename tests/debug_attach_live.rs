mod debug_support;

use std::io::{BufRead, BufReader, Lines};
use std::path::PathBuf;
use std::process::{Child, ChildStdout, Command, Stdio};
use std::sync::Arc;

use debug_support::{Recorder, alive, developer_mode, stopped};
use ride_engine::{
    AttachProcess, Breakpoint, DebugAttach, DebugCommand, DebugEvent, DebugSession, find_adapter,
};

const BREAKPOINT_STATEMENT: &str = "let squared = round * round;";

struct Lab {
    root: PathBuf,
    program: PathBuf,
}

impl Lab {
    fn build() -> Option<Self> {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("samples/debugger/rust");
        let target = std::env::temp_dir().join(format!("ride-attach-lab-{}", std::process::id()));
        let built = Command::new("cargo")
            .arg("build")
            .arg("--manifest-path")
            .arg(root.join("Cargo.toml"))
            .arg("--target-dir")
            .arg(&target)
            .output()
            .ok()?;
        let program = target.join("debug/debugger-lab");
        (built.status.success() && program.is_file()).then_some(Self { root, program })
    }

    fn source(&self) -> PathBuf {
        self.root.join("src/fork.rs")
    }

    fn breakpoint(&self) -> Breakpoint {
        let text = std::fs::read_to_string(self.source()).expect("fork.rs");
        let line = text
            .lines()
            .position(|line| line.contains(BREAKPOINT_STATEMENT))
            .expect("the breakpoint statement") as u32
            + 1;
        Breakpoint::at(&self.source().to_string_lossy(), line)
    }

    fn spawn(&self, delay: u32) -> Forked {
        let mut parent = Command::new(&self.program)
            .args(["fork", &delay.to_string()])
            .stdout(Stdio::piped())
            .spawn()
            .expect("spawn the lab");
        let stdout = parent.stdout.take().expect("the lab stdout");
        Forked {
            parent,
            lines: BufReader::new(stdout).lines(),
            child: None,
        }
    }

    fn attach(&self, process: AttachProcess) -> (Arc<DebugSession>, Arc<Recorder>) {
        let adapter = find_adapter().expect("lldb-dap");
        let listener = Arc::new(Recorder::default());
        let attach = DebugAttach {
            process,
            cwd: Some(self.root.to_string_lossy().to_string()),
            exception_filters: Vec::new(),
        };
        let session = DebugSession::start(
            &adapter,
            &[],
            attach,
            None,
            vec![self.breakpoint()],
            listener.clone(),
        )
        .expect("start the attach session");
        (session, listener)
    }
}

struct Forked {
    parent: Child,
    lines: Lines<BufReader<ChildStdout>>,
    child: Option<u32>,
}

impl Forked {
    fn read_until(&mut self, prefix: &str) -> String {
        for line in self.lines.by_ref().map_while(Result::ok) {
            if let Some(rest) = line.strip_prefix(prefix) {
                return rest.to_string();
            }
        }
        panic!("the lab never printed {prefix}");
    }

    fn child_pid(&mut self) -> u32 {
        let pid = self
            .read_until("fork: child pid ")
            .trim()
            .parse()
            .expect("a pid");
        self.child = Some(pid);
        pid
    }
}

impl Drop for Forked {
    fn drop(&mut self) {
        if let Some(pid) = self.child {
            let _ = Command::new("/bin/kill").arg(pid.to_string()).status();
        }
        let _ = self.parent.kill();
        let _ = self.parent.wait();
    }
}

fn ready() -> Option<Lab> {
    if !developer_mode() {
        eprintln!("skipped: macOS developer mode is disabled, lldb cannot attach");
        return None;
    }
    if find_adapter().is_none() {
        eprintln!("skipped: lldb-dap was not found");
        return None;
    }
    let lab = Lab::build();
    if lab.is_none() {
        eprintln!("skipped: the debugger lab did not build");
    }
    lab
}

fn assert_stopped_in_child(session: &DebugSession, listener: &Recorder, lab: &Lab) {
    let event = listener.wait("the breakpoint stop", |event| stopped(event, "breakpoint"));
    let DebugEvent::Stopped { thread_id, .. } = event else {
        unreachable!();
    };
    let stack = session.stack(thread_id).expect("stackTrace");
    assert!(stack[0].name.contains("child_work"), "{stack:?}");
    assert_eq!(stack[0].line, lab.breakpoint().line);
}

#[test]
fn attaching_by_pid_stops_the_forked_child_and_stop_detaches() {
    let Some(lab) = ready() else {
        return;
    };
    let mut forked = lab.spawn(0);
    let child = forked.child_pid();
    let (session, listener) = lab.attach(AttachProcess::Pid {
        pid: child,
        program: None,
    });
    assert_stopped_in_child(&session, &listener, &lab);
    session
        .command(DebugCommand::Disconnect)
        .expect("disconnect");
    listener.wait("termination", |event| {
        matches!(event, DebugEvent::Terminated)
    });
    assert!(alive(child), "the detached child should keep running");
}

#[test]
fn waiting_for_the_program_name_catches_the_forked_child() {
    let Some(lab) = ready() else {
        return;
    };
    let mut forked = lab.spawn(4);
    forked.read_until("fork: parent pid ");
    let (session, listener) = lab.attach(AttachProcess::WaitFor {
        program: lab.program.to_string_lossy().to_string(),
    });
    let child = forked.child_pid();
    assert_stopped_in_child(&session, &listener, &lab);
    session
        .command(DebugCommand::Disconnect)
        .expect("disconnect");
    listener.wait("termination", |event| {
        matches!(event, DebugEvent::Terminated)
    });
    assert!(alive(child), "the detached child should keep running");
}
