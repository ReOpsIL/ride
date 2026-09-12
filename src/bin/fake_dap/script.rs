use serde_json::{Value, json};

use super::data::{capabilities, scopes, set_breakpoints, stack_trace, variables};

pub const IGNORE_DISCONNECT: &str = "--ignore-disconnect";
pub const PID_FILE: &str = "--pid-file";

pub struct State {
    seq: i64,
    pub line: u32,
    pub path: String,
    launch_seq: Option<i64>,
    ignore_disconnect: bool,
}

impl Default for State {
    fn default() -> Self {
        Self {
            seq: 1,
            line: 10,
            path: "src/main.rs".to_string(),
            launch_seq: None,
            ignore_disconnect: false,
        }
    }
}

impl State {
    pub fn from_args(args: &[String]) -> Self {
        Self {
            ignore_disconnect: args.iter().any(|arg| arg == IGNORE_DISCONNECT),
            ..Self::default()
        }
    }

    fn next_seq(&mut self) -> i64 {
        let seq = self.seq;
        self.seq += 1;
        seq
    }

    fn response(&mut self, command: &str, request_seq: i64, ok: bool, body: Value) -> Value {
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

    fn event(&mut self, event: &str, body: Value) -> Value {
        json!({
            "seq": self.next_seq(),
            "type": "event",
            "event": event,
            "body": body,
        })
    }
}

pub fn reply(state: &mut State, command: &str, message: &Value) -> (Vec<Value>, bool) {
    let request_seq = message.get("seq").and_then(Value::as_i64).unwrap_or(0);
    let arguments = message.get("arguments").cloned().unwrap_or(Value::Null);
    if command == "launch" {
        state.launch_seq = Some(request_seq);
        return (vec![state.event("initialized", Value::Null)], false);
    }
    if command == "configurationDone" {
        return (configuration_done(state, request_seq), false);
    }
    if command == "disconnect" {
        if state.ignore_disconnect {
            return (Vec::new(), false);
        }
        let response = state.response(command, request_seq, true, Value::Null);
        let terminated = state.event("terminated", Value::Null);
        return (vec![response, terminated], true);
    }
    let (ok, body) = outcome(state, command, &arguments);
    let mut messages = vec![state.response(command, request_seq, ok, body)];
    messages.extend(follow_up(state, command, &arguments));
    (messages, false)
}

fn outcome(state: &mut State, command: &str, arguments: &Value) -> (bool, Value) {
    match command {
        "initialize" => (true, capabilities()),
        "setBreakpoints" => (true, set_breakpoints(state, arguments)),
        "setFunctionBreakpoints" => (
            true,
            json!({ "breakpoints": [{ "id": 99, "verified": true }] }),
        ),
        "setExceptionBreakpoints" => (true, json!({ "breakpoints": [] })),
        "threads" => (true, json!({ "threads": [{ "id": 1, "name": "main" }] })),
        "stackTrace" => (true, stack_trace(state)),
        "scopes" => (true, scopes()),
        "variables" => (true, variables(arguments)),
        "evaluate" => (
            true,
            json!({ "result": "7", "type": "i32", "variablesReference": 0 }),
        ),
        "continue" => (true, json!({ "allThreadsContinued": true })),
        "fail" => (false, Value::Null),
        _ => (true, Value::Null),
    }
}

fn follow_up(state: &mut State, command: &str, arguments: &Value) -> Vec<Value> {
    match command {
        "setExceptionBreakpoints" => vec![state.event(
            "output",
            json!({ "category": "console", "output": format!("filters: {}\n", filter_names(arguments)) }),
        )],
        "initialize" => vec![state.event(
            "output",
            json!({ "category": "console", "output": "fake adapter ready\n" }),
        )],
        "next" | "stepIn" | "stepOut" => {
            state.line += 1;
            vec![state.event("stopped", stop_body("step", Vec::new()))]
        }
        "continue" => vec![state.event("continued", json!({ "threadId": 1 }))],
        "pause" => vec![state.event("stopped", stop_body("pause", Vec::new()))],
        _ => Vec::new(),
    }
}

fn configuration_done(state: &mut State, request_seq: i64) -> Vec<Value> {
    let mut messages = vec![state.response("configurationDone", request_seq, true, Value::Null)];
    if let Some(seq) = state.launch_seq.take() {
        messages.push(state.response("launch", seq, true, Value::Null));
    }
    messages.push(state.event("stopped", stop_body("breakpoint", vec![1])));
    messages
}

fn stop_body(reason: &str, hit: Vec<i64>) -> Value {
    json!({
        "reason": reason,
        "threadId": 1,
        "allThreadsStopped": true,
        "hitBreakpointIds": hit,
    })
}

fn filter_names(arguments: &Value) -> String {
    arguments
        .get("filters")
        .and_then(Value::as_array)
        .map(|entries| {
            entries
                .iter()
                .filter_map(Value::as_str)
                .collect::<Vec<&str>>()
                .join(",")
        })
        .unwrap_or_default()
}
