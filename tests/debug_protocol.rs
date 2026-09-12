use std::fmt::Debug;
use std::fs;
use std::path::PathBuf;

use serde::Serialize;
use serde::de::DeserializeOwned;
use serde_json::{Value, json};

use ride_engine::debug::protocol::{
    AttachArguments, BreakpointBody, Capabilities, ConfigurationDoneArguments, ContinueArguments,
    ContinueResponseBody, ContinuedBody, DisconnectArguments, ErrorMessage, EvaluateArguments,
    EvaluateContext, EvaluateResponseBody, Event, ExitedBody, InitializeArguments, LaunchArguments,
    OutputBody, PauseArguments, Request, Response, ScopesArguments, ScopesResponseBody,
    SetBreakpointsArguments, SetBreakpointsResponseBody, SetExceptionBreakpointsArguments,
    SetExceptionBreakpointsResponseBody, Source, SourceBreakpoint, StackTraceArguments,
    StackTraceResponseBody, StepArguments, SteppingGranularity, StoppedBody, TerminatedBody,
    ThreadBody, ThreadsResponseBody, VariablesArguments, VariablesResponseBody,
};

fn fixture(name: &str) -> Value {
    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures/dap")
        .join(format!("{name}.json"));
    let text = fs::read_to_string(&path).unwrap();
    serde_json::from_str(&text).unwrap()
}

fn round_trip<T>(value: &Value) -> T
where
    T: Serialize + DeserializeOwned + PartialEq + Debug,
{
    let parsed: T = serde_json::from_value(value.clone()).unwrap();
    let encoded = serde_json::to_value(&parsed).unwrap();
    let again: T = serde_json::from_value(encoded).unwrap();
    assert_eq!(parsed, again);
    parsed
}

fn request(name: &str) -> (Request, Value) {
    let raw = fixture(name);
    let parsed: Request = round_trip(&raw);
    assert_eq!(parsed.kind, "request");
    assert_eq!(serde_json::to_value(&parsed).unwrap(), raw);
    let arguments = parsed.arguments.clone().unwrap_or(Value::Null);
    (parsed, arguments)
}

fn response(name: &str) -> (Response, Value) {
    let raw = fixture(name);
    let parsed: Response = round_trip(&raw);
    assert_eq!(parsed.kind, "response");
    let body = parsed.body.clone().unwrap_or(Value::Null);
    (parsed, body)
}

fn event(name: &str) -> (Event, Value) {
    let raw = fixture(name);
    let parsed: Event = round_trip(&raw);
    assert_eq!(parsed.kind, "event");
    let body = parsed.body.clone().unwrap_or(Value::Null);
    (parsed, body)
}

#[test]
fn initialize_round_trips() {
    let (message, arguments) = request("initialize_request");
    assert_eq!(message.command, "initialize");
    let parsed: InitializeArguments = round_trip(&arguments);
    assert_eq!(parsed, InitializeArguments::ride());
    assert_eq!(serde_json::to_value(&parsed).unwrap(), arguments);

    let (message, body) = response("initialize_response");
    assert!(message.success);
    let capabilities: Capabilities = round_trip(&body);
    assert_eq!(capabilities.supports_configuration_done_request, Some(true));
    assert!(capabilities.has_filter("cpp_throw"));
    assert!(capabilities.has_filter("cpp_catch"));
    assert!(!capabilities.has_filter("rust_panic"));
}

#[test]
fn launch_and_attach_round_trip() {
    let (message, arguments) = request("launch_request");
    assert_eq!(message.command, "launch");
    let parsed: LaunchArguments = round_trip(&arguments);
    assert_eq!(serde_json::to_value(&parsed).unwrap(), arguments);
    assert_eq!(parsed.args, vec!["--demo".to_string()]);
    assert_eq!(parsed.stop_on_entry, Some(true));
    assert_eq!(parsed.env.get("RIDE_DEMO").map(String::as_str), Some("1"));
    assert_eq!(parsed.init_commands.len(), 1);

    let (message, _) = response("launch_error_response");
    assert!(!message.success);
    assert!(message.failure().unwrap().ends_with("does not exist"));

    let (message, arguments) = request("attach_request");
    assert_eq!(message.command, "attach");
    let parsed: AttachArguments = round_trip(&arguments);
    assert_eq!(serde_json::to_value(&parsed).unwrap(), arguments);
    assert!(parsed.core_file.is_some());
    assert_eq!(AttachArguments::pid(42).pid, Some(42));
}

#[test]
fn breakpoints_round_trip() {
    let (_, arguments) = request("set_breakpoints_request");
    let parsed: SetBreakpointsArguments = round_trip(&arguments);
    assert_eq!(serde_json::to_value(&parsed).unwrap(), arguments);
    assert_eq!(parsed.breakpoints[0].line, 10);
    assert_eq!(
        parsed.breakpoints[1].condition.as_deref(),
        Some("counter.count > 0")
    );
    assert_eq!(parsed.breakpoints[1].hit_condition.as_deref(), Some("2"));
    assert_eq!(parsed.lines, vec![10, 12]);

    let built = SetBreakpointsArguments::new(
        Source::file("/tmp/main.rs", "main.rs"),
        vec![SourceBreakpoint::line(7)],
    );
    assert_eq!(built.lines, vec![7]);

    let (_, body) = response("set_breakpoints_response");
    let parsed: SetBreakpointsResponseBody = round_trip(&body);
    assert_eq!(parsed.breakpoints.len(), 2);
    assert_eq!(parsed.breakpoints[0].id, Some(1));
    assert_eq!(parsed.breakpoints[0].line, Some(10));
    assert!(!parsed.breakpoints[0].verified);
    assert!(parsed.breakpoints[0].source.is_some());
}

#[test]
fn exception_breakpoints_round_trip() {
    let (_, arguments) = request("set_exception_breakpoints_request");
    let parsed: SetExceptionBreakpointsArguments = round_trip(&arguments);
    assert_eq!(serde_json::to_value(&parsed).unwrap(), arguments);
    assert_eq!(parsed.filters, vec!["cpp_throw", "cpp_catch", "rust_panic"]);

    let (_, body) = response("set_exception_breakpoints_response");
    let parsed: SetExceptionBreakpointsResponseBody = round_trip(&body);
    assert_eq!(parsed.breakpoints.len(), 2);
    assert!(parsed.breakpoints[0].verified);

    let (message, arguments) = request("configuration_done_request");
    assert_eq!(message.command, "configurationDone");
    let parsed: ConfigurationDoneArguments = round_trip(&arguments);
    assert_eq!(serde_json::to_value(&parsed).unwrap(), arguments);
    let (message, _) = response("configuration_done_response");
    assert!(message.success);
}

#[test]
fn threads_and_frames_round_trip() {
    let (_, body) = response("threads_response");
    let parsed: ThreadsResponseBody = round_trip(&body);
    assert_eq!(parsed.threads[0].name, "Thread 1");

    let (_, arguments) = request("stack_trace_request");
    let parsed: StackTraceArguments = round_trip(&arguments);
    assert_eq!(serde_json::to_value(&parsed).unwrap(), arguments);
    assert_eq!(parsed.levels, Some(20));

    let (_, body) = response("stack_trace_response");
    let parsed: StackTraceResponseBody = round_trip(&body);
    assert_eq!(parsed.total_frames, Some(18));
    let main = parsed
        .stack_frames
        .iter()
        .find(|frame| frame.name.starts_with("ride_demo::main"))
        .unwrap();
    assert_eq!(main.line, 20);
    assert!(main.path().unwrap().ends_with("src/main.rs"));

    let (_, arguments) = request("scopes_request");
    let parsed: ScopesArguments = round_trip(&arguments);
    assert_eq!(serde_json::to_value(&parsed).unwrap(), arguments);

    let (_, body) = response("scopes_response");
    let parsed: ScopesResponseBody = round_trip(&body);
    assert_eq!(parsed.scopes[0].name, "Locals");
    assert_eq!(
        parsed.scopes[0].presentation_hint.as_deref(),
        Some("locals")
    );
    assert_eq!(parsed.scopes[0].named_variables, Some(2));
}

#[test]
fn variables_and_evaluate_round_trip() {
    let (_, arguments) = request("variables_request");
    let parsed: VariablesArguments = round_trip(&arguments);
    assert_eq!(serde_json::to_value(&parsed).unwrap(), arguments);

    let (_, body) = response("variables_response");
    let parsed: VariablesResponseBody = round_trip(&body);
    let counter = &parsed.variables[0];
    assert_eq!(counter.name, "counter");
    assert_eq!(
        counter.type_name.as_deref(),
        Some("ride_demo::util::Counter")
    );
    assert!(counter.expandable());

    let (_, arguments) = request("variables_paged_request");
    let parsed: VariablesArguments = round_trip(&arguments);
    assert_eq!(parsed.start, Some(0));
    assert_eq!(parsed.count, Some(2));
    assert_eq!(
        serde_json::to_value(VariablesArguments::page(parsed.variables_reference, 0, 2)).unwrap(),
        arguments
    );

    let (_, body) = response("variables_paged_response");
    let parsed: VariablesResponseBody = round_trip(&body);
    assert_eq!(parsed.variables[0].name, "counts");
    assert_eq!(
        parsed.variables[0].evaluate_name.as_deref(),
        Some("counter.counts")
    );
}

#[test]
fn evaluate_contexts_round_trip() {
    let (_, arguments) = request("evaluate_watch_request");
    let parsed: EvaluateArguments = round_trip(&arguments);
    assert_eq!(serde_json::to_value(&parsed).unwrap(), arguments);
    assert_eq!(parsed.context, Some(EvaluateContext::Watch));
    assert_eq!(
        serde_json::to_value(EvaluateArguments::in_frame(
            "counter",
            parsed.frame_id.unwrap(),
            EvaluateContext::Watch
        ))
        .unwrap(),
        arguments
    );

    let (_, arguments) = request("evaluate_repl_request");
    let parsed: EvaluateArguments = round_trip(&arguments);
    assert_eq!(parsed.context, Some(EvaluateContext::Repl));
    assert_eq!(EvaluateContext::Hover.as_str(), "hover");

    let (_, body) = response("evaluate_watch_response");
    let parsed: EvaluateResponseBody = round_trip(&body);
    assert!(parsed.result.contains("ride_demo::util::Counter"));
    assert_ne!(parsed.variables_reference, 0);

    let (_, body) = response("evaluate_hover_response");
    let parsed: EvaluateResponseBody = round_trip(&body);
    assert!(parsed.type_name.unwrap().contains("HashMap"));

    let (_, body) = response("evaluate_repl_response");
    let parsed: EvaluateResponseBody = round_trip(&body);
    assert_eq!(parsed.result, "(int) 6\n");
    assert_eq!(parsed.variables_reference, 0);
}

#[test]
fn execution_commands_round_trip() {
    let (_, arguments) = request("continue_request");
    let parsed: ContinueArguments = round_trip(&arguments);
    assert_eq!(serde_json::to_value(&parsed).unwrap(), arguments);

    let (message, _) = response("continue_error_response");
    assert!(!message.success);
    assert_eq!(
        message.failure().unwrap(),
        "mach-o-core does not support resuming processes"
    );

    let (message, arguments) = request("next_request");
    assert_eq!(message.command, "next");
    let parsed: StepArguments = round_trip(&arguments);
    assert_eq!(serde_json::to_value(&parsed).unwrap(), arguments);
    assert_eq!(parsed.granularity, Some(SteppingGranularity::Statement));
    assert_eq!(
        StepArguments::by_statement(parsed.thread_id).granularity,
        Some(SteppingGranularity::Statement)
    );

    for name in ["step_in_request", "step_out_request"] {
        let (_, arguments) = request(name);
        let parsed: StepArguments = round_trip(&arguments);
        assert_eq!(serde_json::to_value(&parsed).unwrap(), arguments);
        assert_eq!(parsed.granularity, None);
    }

    let (_, arguments) = request("pause_request");
    let parsed: PauseArguments = round_trip(&arguments);
    assert_eq!(serde_json::to_value(&parsed).unwrap(), arguments);
    let (message, _) = response("pause_response");
    assert!(message.success);
    assert!(message.failure().is_none());

    let parsed: ContinueResponseBody = round_trip(&json!({"allThreadsContinued": true}));
    assert_eq!(parsed.all_threads_continued, Some(true));
}

#[test]
fn disconnect_round_trips() {
    let (_, arguments) = request("disconnect_request");
    let parsed: DisconnectArguments = round_trip(&arguments);
    assert_eq!(serde_json::to_value(&parsed).unwrap(), arguments);
    assert_eq!(parsed.terminate_debuggee, Some(true));
    let (message, _) = response("disconnect_response");
    assert!(message.success);
}

#[test]
fn events_round_trip() {
    let (message, _) = event("initialized_event");
    assert_eq!(message.event, "initialized");
    assert!(message.body.is_none());

    let (message, body) = event("stopped_event");
    assert_eq!(message.event, "stopped");
    let parsed: StoppedBody = round_trip(&body);
    assert_eq!(parsed.reason.as_deref(), Some("exception"));
    assert_eq!(parsed.thread_id, Some(0));
    assert_eq!(parsed.all_threads_stopped, Some(true));
    assert!(parsed.hit_breakpoint_ids.is_empty());

    let (message, body) = event("output_event");
    assert_eq!(message.event, "output");
    let parsed: OutputBody = round_trip(&body);
    assert_eq!(parsed.category_or_console(), "console");
    assert!(parsed.output.contains("breakpoint"));

    let (message, body) = event("terminated_event");
    assert_eq!(message.event, "terminated");
    let parsed: TerminatedBody = round_trip(&body);
    assert_eq!(parsed.restart, None);
}

#[test]
fn live_process_events_round_trip() {
    let parsed: StoppedBody = round_trip(&json!({
        "reason": "breakpoint",
        "threadId": 1,
        "allThreadsStopped": true,
        "hitBreakpointIds": [1, 2]
    }));
    assert_eq!(parsed.hit_breakpoint_ids, vec![1, 2]);

    let parsed: ContinuedBody = round_trip(&json!({"threadId": 1, "allThreadsContinued": true}));
    assert_eq!(parsed.thread_id, 1);

    let parsed: ExitedBody = round_trip(&json!({"exitCode": 0}));
    assert_eq!(parsed.exit_code, 0);

    let parsed: ThreadBody = round_trip(&json!({"reason": "started", "threadId": 1}));
    assert_eq!(parsed.reason, "started");

    let parsed: BreakpointBody = round_trip(&json!({
        "reason": "changed",
        "breakpoint": {"id": 1, "verified": true, "line": 10}
    }));
    assert_eq!(parsed.breakpoint.line, Some(10));
    assert!(parsed.breakpoint.verified);
}

#[test]
fn unknown_fields_are_tolerated() {
    let raw = fixture("terminated_event");
    let parsed: Event = round_trip(&raw);
    assert!(parsed.body.unwrap().get("$__lldb_statistics").is_some());

    let parsed: StoppedBody = round_trip(&json!({"reason": "pause", "ride": {"unknown": 1}}));
    assert_eq!(parsed.reason.as_deref(), Some("pause"));

    let built = Request::new(9, "threads", None);
    assert_eq!(
        serde_json::to_value(&built).unwrap(),
        json!({"seq": 9, "type": "request", "command": "threads"})
    );
}

#[test]
fn error_message_variables_are_interpolated() {
    let raw = json!({
        "id": 3002,
        "format": "breakpoint {number} at {path} could not be set",
        "variables": {"number": "1", "path": "src/main.rs"},
        "showUser": true
    });
    let parsed: ErrorMessage = round_trip(&raw);
    assert_eq!(
        parsed.variables.as_ref().unwrap().get("path").unwrap(),
        "src/main.rs"
    );
    assert_eq!(
        parsed.text(),
        "breakpoint 1 at src/main.rs could not be set"
    );

    let message: Response = serde_json::from_value(json!({
        "seq": 7,
        "type": "response",
        "request_seq": 6,
        "success": false,
        "command": "setBreakpoints",
        "message": "failed",
        "body": {"error": raw}
    }))
    .unwrap();
    assert_eq!(
        message.failure().unwrap(),
        "breakpoint 1 at src/main.rs could not be set"
    );

    let plain: ErrorMessage = round_trip(&json!({"id": 1, "format": "plain {name}"}));
    assert_eq!(plain.text(), "plain {name}");
}
