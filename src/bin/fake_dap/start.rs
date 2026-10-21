use serde_json::{Value, json};

use super::script::{init_commands, stop_body};
use super::state::{Reply, State};

pub fn start(state: &mut State, command: &str, request_seq: i64, arguments: &Value) -> Reply {
    if command == "attach" && state.hold_attach {
        return Reply::default();
    }
    state.start = Some((command.to_string(), request_seq));
    let commands = state.event(
        "output",
        json!({ "category": "console", "output": format!("initCommands: {}\n", init_commands(arguments)) }),
    );
    Reply {
        now: vec![commands, state.event("initialized", Value::Null)],
        ..Reply::default()
    }
}

pub fn configuration_done(state: &mut State, request_seq: i64) -> Reply {
    if state.die_on_done {
        return Reply {
            stop: true,
            ..Reply::default()
        };
    }
    let mut now = vec![
        state.response("configurationDone", request_seq, true, Value::Null),
        state.event(
            "process",
            json!({ "name": "fake", "startMethod": "launch" }),
        ),
    ];
    if state.die_after_done {
        return Reply {
            now,
            later: Vec::new(),
            stop: true,
        };
    }
    if state.delay.is_zero() {
        now.push(state.event("stopped", stop_body("breakpoint", vec![1])));
        now.extend(start_response(state));
        return Reply {
            now,
            ..Reply::default()
        };
    }
    now.extend(start_response(state));
    Reply {
        now,
        later: vec![state.event("stopped", stop_body("breakpoint", vec![1]))],
        stop: false,
    }
}

fn start_response(state: &mut State) -> Vec<Value> {
    state
        .start
        .take()
        .map(|(command, seq)| vec![state.response(&command, seq, true, Value::Null)])
        .unwrap_or_default()
}
