use std::collections::BTreeMap;
use std::path::Path;
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

use crate::error::EngineError;
use crate::ffi::DebugEvent;

use super::wire::{arguments, body};
use super::{DebugSession, events};
use crate::debug::filters;
use crate::debug::protocol::{
    CONFIGURATION_DONE, Capabilities, ConfigurationDoneArguments, FILTER_RUST_PANIC,
    FunctionBreakpoint, INITIALIZED, InitializeArguments, LaunchArguments,
    SetExceptionBreakpointsArguments, SetFunctionBreakpointsArguments,
};
use crate::debug::render;

const INITIALIZE: &str = "initialize";
const LAUNCH: &str = "launch";
const SET_EXCEPTION_BREAKPOINTS: &str = "setExceptionBreakpoints";
const SET_FUNCTION_BREAKPOINTS: &str = "setFunctionBreakpoints";
const RUST_PANIC_FUNCTION: &str = "rust_panic";
const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(30);

pub fn run(session: &Arc<DebugSession>) -> Result<(), EngineError> {
    let capabilities = initialize(session)?;
    let launch_seq = session
        .transport
        .send_request(LAUNCH, arguments(LAUNCH, &launch_arguments(session))?)?;
    await_initialized(session)?;
    session.send_stored_breakpoints()?;
    exception_breakpoints(session, &capabilities)?;
    session.transport.request(
        CONFIGURATION_DONE,
        arguments(CONFIGURATION_DONE, &ConfigurationDoneArguments {})?,
    )?;
    let launched = Arc::clone(session);
    thread::spawn(move || decide(&launched, launch_seq));
    Ok(())
}

fn decide(session: &DebugSession, launch_seq: i64) {
    if let Err(err) = session.transport.await_response(launch_seq, LAUNCH) {
        session.fail(&err.to_string());
        return;
    }
    if !session.drained(session.transport.events_received()) {
        session.abandon_launch("launch: the adapter stopped delivering events");
        return;
    }
    if session.begin_running() {
        session.emit(DebugEvent::Running);
    }
}

fn initialize(session: &DebugSession) -> Result<Capabilities, EngineError> {
    let response = session.transport.request(
        INITIALIZE,
        arguments(INITIALIZE, &InitializeArguments::ride())?,
    )?;
    let capabilities = body::<Capabilities>(INITIALIZE, response)?;
    if let Ok(mut stored) = session.capabilities.lock() {
        *stored = capabilities.clone();
    }
    Ok(capabilities)
}

fn launch_arguments(session: &DebugSession) -> LaunchArguments {
    let launch = &session.launch;
    LaunchArguments {
        program: launch.program.clone(),
        args: launch.args.clone(),
        cwd: launch.cwd.clone(),
        env: launch
            .env
            .iter()
            .map(|(name, value)| (name.clone(), value.clone()))
            .collect::<BTreeMap<String, String>>(),
        stop_on_entry: Some(launch.stop_on_entry),
        init_commands: render::toolchain_init_commands(is_rust_target(session)),
    }
}

fn await_initialized(session: &DebugSession) -> Result<(), EngineError> {
    let deadline = Instant::now() + HANDSHAKE_TIMEOUT;
    while Instant::now() < deadline {
        let Some((stamp, event)) = session.transport.poll_received(events::POLL)? else {
            continue;
        };
        if event.get("event").and_then(|name| name.as_str()) == Some(INITIALIZED) {
            session.mark_processed(stamp);
            return Ok(());
        }
        events::handle(session, &event);
        session.mark_processed(stamp);
    }
    Err(EngineError::debug("initialized event: timed out"))
}

fn exception_breakpoints(
    session: &DebugSession,
    capabilities: &Capabilities,
) -> Result<(), EngineError> {
    let rust = is_rust_target(session);
    let mut filters = filters::enabled(&session.launch.exception_filters, capabilities);
    if rust
        && capabilities.has_filter(FILTER_RUST_PANIC)
        && !filters.iter().any(|id| id == FILTER_RUST_PANIC)
    {
        filters.push(FILTER_RUST_PANIC.to_string());
    }
    let request = SetExceptionBreakpointsArguments {
        filters,
        filter_options: Vec::new(),
    };
    session.transport.request(
        SET_EXCEPTION_BREAKPOINTS,
        arguments(SET_EXCEPTION_BREAKPOINTS, &request)?,
    )?;
    if !rust || capabilities.has_filter(FILTER_RUST_PANIC) {
        return Ok(());
    }
    let request = SetFunctionBreakpointsArguments {
        breakpoints: vec![FunctionBreakpoint::name(RUST_PANIC_FUNCTION)],
    };
    session.transport.request(
        SET_FUNCTION_BREAKPOINTS,
        arguments(SET_FUNCTION_BREAKPOINTS, &request)?,
    )?;
    Ok(())
}

fn is_rust_target(session: &DebugSession) -> bool {
    let launch = &session.launch;
    if let Some(cwd) = &launch.cwd
        && Path::new(cwd).join("Cargo.toml").is_file()
    {
        return true;
    }
    Path::new(&launch.program)
        .ancestors()
        .any(|parent| parent.file_name().is_some_and(|name| name == "target"))
}
