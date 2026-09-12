use std::time::Duration;

use serde_json::{Value, json};

pub const IGNORE_DISCONNECT: &str = "--ignore-disconnect";
pub const PID_FILE: &str = "--pid-file";
pub const DELAY_STOP: &str = "--delay-stop";
pub const EXIT_ON_CONTINUE: &str = "--exit-on-continue";
pub const DIE_ON_DONE: &str = "--die-on-done";

#[derive(Default)]
pub struct Reply {
    pub now: Vec<Value>,
    pub later: Vec<Value>,
    pub stop: bool,
}

pub struct State {
    seq: i64,
    pub line: u32,
    pub path: String,
    pub delay: Duration,
    pub launch_seq: Option<i64>,
    pub ignore_disconnect: bool,
    pub exit_on_continue: bool,
    pub die_on_done: bool,
}

impl Default for State {
    fn default() -> Self {
        Self {
            seq: 1,
            line: 10,
            path: "src/main.rs".to_string(),
            delay: Duration::ZERO,
            launch_seq: None,
            ignore_disconnect: false,
            exit_on_continue: false,
            die_on_done: false,
        }
    }
}

impl State {
    pub fn from_args(args: &[String]) -> Self {
        Self {
            ignore_disconnect: args.iter().any(|arg| arg == IGNORE_DISCONNECT),
            exit_on_continue: args.iter().any(|arg| arg == EXIT_ON_CONTINUE),
            die_on_done: args.iter().any(|arg| arg == DIE_ON_DONE),
            delay: Duration::from_millis(millis(args, DELAY_STOP)),
            ..Self::default()
        }
    }

    fn next_seq(&mut self) -> i64 {
        let seq = self.seq;
        self.seq += 1;
        seq
    }

    pub fn response(&mut self, command: &str, request_seq: i64, ok: bool, body: Value) -> Value {
        json!({
            "seq": self.next_seq(),
            "type": "response",
            "request_seq": request_seq,
            "success": ok,
            "command": command,
            "message": "fake failure",
            "body": body,
        })
    }

    pub fn event(&mut self, event: &str, body: Value) -> Value {
        json!({
            "seq": self.next_seq(),
            "type": "event",
            "event": event,
            "body": body,
        })
    }
}

fn millis(args: &[String], flag: &str) -> u64 {
    args.iter()
        .position(|arg| arg == flag)
        .and_then(|index| args.get(index + 1))
        .and_then(|value| value.parse::<u64>().ok())
        .unwrap_or_default()
}
