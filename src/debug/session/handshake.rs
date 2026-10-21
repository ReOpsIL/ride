use std::sync::Arc;
use std::thread;
use std::time::Instant;

use crate::error::EngineError;
use crate::ffi::DebugEvent;

use super::rust_target::is_rust_target;
use super::start_request::start_request;
use super::wire::{arguments, body};
use super::{DebugSession, events};
use crate::debug::filters;
use crate::debug::protocol::{
    CONFIGURATION_DONE, Capabilities, ConfigurationDoneArguments, FILTER_RUST_PANIC,
    FunctionBreakpoint, INITIALIZED, InitializeArguments, SetExceptionBreakpointsArguments,
    SetFunctionBreakpointsArguments,
};
use crate::debug::render;

const INITIALIZE: &str = "initialize";
const SET_EXCEPTION_BREAKPOINTS: &str = "setExceptionBreakpoints";
const SET_FUNCTION_BREAKPOINTS: &str = "setFunctionBreakpoints";
const RUST_PANIC_FUNCTION: &str = "rust_panic";

pub fn run(session: &Arc<DebugSession>) -> Result<(), EngineError> {
    let capabilities = initialize(session)?;
    let target = &session.target;
    let init_commands = render::init_commands(session.sysroot.as_deref(), is_rust_target(target));
    let start_seq = session
        .transport
        .send_request(target.command(), start_request(target, init_commands)?)?;
    await_initialized(session)?;
    session.send_stored_breakpoints()?;
    exception_breakpoints(session, &capabilities)?;
    session.transport.request(
        CONFIGURATION_DONE,
        arguments(CONFIGURATION_DONE, &ConfigurationDoneArguments {})?,
    )?;
    let started = Arc::clone(session);
    thread::spawn(move || decide(&started, start_seq));
    Ok(())
}

fn decide(session: &DebugSession, start_seq: i64) {
    let target = &session.target;
    let command = target.command();
    if let Err(err) =
        session
            .transport
            .await_response(start_seq, command, target.handshake_timeout())
    {
        session.fail(&err.to_string());
        return;
    }
    if !session.drained(session.transport.events_received()) {
        session.abandon_launch(&format!("{command}: the adapter stopped delivering events"));
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
    body::<Capabilities>(INITIALIZE, response)
}

fn await_initialized(session: &DebugSession) -> Result<(), EngineError> {
    let deadline = Instant::now() + session.target.handshake_timeout();
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
    let rust = is_rust_target(&session.target);
    let mut filters = filters::enabled(session.target.exception_filters(), capabilities);
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
