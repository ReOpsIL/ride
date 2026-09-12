use serde_json::{Value, json};

use super::data::{capabilities, scopes, set_breakpoints, stack_trace, variables};
use super::state::{Reply, State};

pub fn reply(state: &mut State, command: &str, message: &Value) -> Reply {
    let request_seq = message.get("seq").and_then(Value::as_i64).unwrap_or(0);
    let arguments = message.get("arguments").cloned().unwrap_or(Value::Null);
    if command == "launch" {
        state.launch_seq = Some(request_seq);
        let commands = state.event(
            "output",
            json!({ "category": "console", "output": format!("initCommands: {}\n", init_commands(&arguments)) }),
        );
        return Reply {
            now: vec![commands, state.event("initialized", Value::Null)],
            ..Reply::default()
        };
    }
    if command == "configurationDone" {
        return configuration_done(state, request_seq);
    }
    if command == "disconnect" {
        if state.ignore_disconnect {
            return Reply::default();
        }
        let response = state.response(command, request_seq, true, Value::Null);
        let terminated = state.event("terminated", Value::Null);
        return Reply {
            now: vec![response, terminated],
            stop: true,
            ..Reply::default()
        };
    }
    let (ok, body) = outcome(state, command, &arguments);
    let mut now = vec![state.response(command, request_seq, ok, body)];
    now.extend(follow_up(state, command, &arguments));
    Reply {
        now,
        ..Reply::default()
    }
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
        "continue" => continued(state),
        "pause" => vec![state.event("stopped", stop_body("pause", Vec::new()))],
        _ => Vec::new(),
    }
}

fn continued(state: &mut State) -> Vec<Value> {
    let mut messages = vec![state.event("continued", json!({ "threadId": 1 }))];
    if state.exit_on_continue {
        messages.push(state.event("exited", json!({ "exitCode": 0 })));
        messages.push(state.event("terminated", Value::Null));
    }
    messages
}

fn configuration_done(state: &mut State, request_seq: i64) -> Reply {
    let mut now = vec![state.response("configurationDone", request_seq, true, Value::Null)];
    if let Some(seq) = state.launch_seq.take() {
        now.push(state.response("launch", seq, true, Value::Null));
    }
    let stopped = state.event("stopped", stop_body("breakpoint", vec![1]));
    if state.delay.is_zero() {
        now.push(stopped);
        return Reply {
            now,
            ..Reply::default()
        };
    }
    Reply {
        now,
        later: vec![stopped],
        stop: false,
    }
}

fn stop_body(reason: &str, hit: Vec<i64>) -> Value {
    json!({
        "reason": reason,
        "threadId": 1,
        "allThreadsStopped": true,
        "hitBreakpointIds": hit,
    })
}

fn init_commands(arguments: &Value) -> String {
    strings(arguments, "initCommands").join(" | ")
}

fn filter_names(arguments: &Value) -> String {
    strings(arguments, "filters").join(",")
}

fn strings(arguments: &Value, key: &str) -> Vec<String> {
    arguments
        .get(key)
        .and_then(Value::as_array)
        .map(|entries| {
            entries
                .iter()
                .filter_map(Value::as_str)
                .map(str::to_string)
                .collect::<Vec<String>>()
        })
        .unwrap_or_default()
}
