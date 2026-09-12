use std::collections::BTreeMap;
use std::path::Path;
use std::time::{Duration, Instant};

use crate::error::EngineError;
use crate::ffi::{DebugEvent, DebugState};

use super::wire::{arguments, body};
use super::{DebugSession, events};
use crate::debug::protocol::{
    CONFIGURATION_DONE, Capabilities, ConfigurationDoneArguments, FILTER_RUST_PANIC,
    FunctionBreakpoint, INITIALIZED, InitializeArguments, LaunchArguments,
    SetExceptionBreakpointsArguments, SetFunctionBreakpointsArguments,
};

const INITIALIZE: &str = "initialize";
const LAUNCH: &str = "launch";
const SET_EXCEPTION_BREAKPOINTS: &str = "setExceptionBreakpoints";
const SET_FUNCTION_BREAKPOINTS: &str = "setFunctionBreakpoints";
const RUST_PANIC_FUNCTION: &str = "rust_panic";
const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(30);

pub fn run(session: &DebugSession) -> Result<(), EngineError> {
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
    session.transport.await_response(launch_seq, LAUNCH)?;
    if !session.finished() && !matches!(session.state(), DebugState::Stopped { .. }) {
        session.set_state(DebugState::Running);
        session.emit(DebugEvent::Running);
    }
    Ok(())
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
        init_commands: Vec::new(),
    }
}

fn await_initialized(session: &DebugSession) -> Result<(), EngineError> {
    let deadline = Instant::now() + HANDSHAKE_TIMEOUT;
    while Instant::now() < deadline {
        let Some(event) = session.transport.poll_event(events::POLL)? else {
            continue;
        };
        if event.get("event").and_then(|name| name.as_str()) == Some(INITIALIZED) {
            return Ok(());
        }
        events::handle(session, &event);
    }
    Err(EngineError::debug("initialized event: timed out"))
}

fn exception_breakpoints(
    session: &DebugSession,
    capabilities: &Capabilities,
) -> Result<(), EngineError> {
    let rust = is_rust_target(session);
    let mut filters = Vec::new();
    if rust && capabilities.has_filter(FILTER_RUST_PANIC) {
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
