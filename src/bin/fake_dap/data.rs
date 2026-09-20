use serde_json::{Value, json};

use super::state::State;

pub fn capabilities() -> Value {
    json!({
        "supportsConfigurationDoneRequest": true,
        "supportsConditionalBreakpoints": true,
        "supportsFunctionBreakpoints": true,
        "supportsSteppingGranularity": true,
        "exceptionBreakpointFilters": [
            { "filter": "cpp_throw", "label": "C++ Throw", "default": true },
            { "filter": "cpp_catch", "label": "C++ Catch", "default": false }
        ],
    })
}

pub fn set_breakpoints(state: &mut State, arguments: &Value) -> Value {
    if let Some(path) = arguments
        .pointer("/source/path")
        .and_then(Value::as_str)
        .filter(|path| !path.is_empty())
    {
        state.path = path.to_string();
    }
    let lines: Vec<u32> = arguments
        .get("breakpoints")
        .and_then(Value::as_array)
        .map(|entries| {
            entries
                .iter()
                .filter_map(|entry| entry.get("line").and_then(Value::as_u64))
                .map(|line| line as u32)
                .collect()
        })
        .unwrap_or_default();
    if let Some(line) = lines.first() {
        state.line = *line;
    }
    let verified = !state.verify_canonical || is_canonical(&state.path);
    let breakpoints: Vec<Value> = lines
        .iter()
        .enumerate()
        .map(|(index, line)| {
            json!({
                "id": index as i64 + 1,
                "verified": verified,
                "line": line,
                "source": { "path": state.path },
            })
        })
        .collect();
    json!({ "breakpoints": breakpoints })
}

fn is_canonical(path: &str) -> bool {
    std::fs::canonicalize(path)
        .map(|resolved| resolved.to_string_lossy() == path)
        .unwrap_or(false)
}

pub fn stack_trace(state: &State) -> Value {
    json!({
        "stackFrames": [
            {
                "id": 1000,
                "name": "main",
                "line": state.line,
                "column": 5,
                "source": { "name": "main.rs", "path": state.path },
            },
            { "id": 1001, "name": "core::ops::function::FnOnce::call_once", "line": 0, "column": 0 }
        ],
        "totalFrames": 2,
    })
}

pub fn scopes() -> Value {
    json!({
        "scopes": [
            { "name": "Locals", "variablesReference": 1001, "expensive": false },
            { "name": "Registers", "variablesReference": 1002, "expensive": true }
        ]
    })
}

pub fn variables(arguments: &Value) -> Value {
    let reference = arguments
        .get("variablesReference")
        .and_then(Value::as_i64)
        .unwrap_or(0);
    if reference != 1001 {
        return json!({ "variables": [] });
    }
    json!({
        "variables": [
            { "name": "counter", "value": "Counter { events: {} }", "type": "rust_demo::util::Counter", "variablesReference": 1003, "namedVariables": 1 },
            { "name": "totals", "value": "size=0", "type": "HashMap<&str, u32>", "variablesReference": 0 }
        ]
    })
}
