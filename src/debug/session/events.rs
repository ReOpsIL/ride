use std::time::Duration;

use serde_json::Value;

use crate::ffi::{DebugEvent, DebugState};

use super::DebugSession;
use crate::debug::protocol::{
    BREAKPOINT, BreakpointBody, CONTINUED, ContinuedBody, EXITED, Event, ExitedBody, OUTPUT,
    OutputBody, STOPPED, StoppedBody, TERMINATED,
};

pub const POLL: Duration = Duration::from_millis(100);

pub fn pump(session: &DebugSession) {
    loop {
        match session.transport.poll_received(POLL) {
            Ok(Some((stamp, event))) => {
                handle(session, &event);
                session.mark_processed(stamp);
                if session.finished() {
                    return;
                }
            }
            Ok(None) => {
                if session.finished() {
                    return;
                }
            }
            Err(_) => return terminate(session),
        }
    }
}

pub fn handle(session: &DebugSession, raw: &Value) {
    let Ok(event) = serde_json::from_value::<Event>(raw.clone()) else {
        return;
    };
    match event.event.as_str() {
        STOPPED => stopped(session, &event),
        CONTINUED => continued(session, &event),
        OUTPUT => output(session, &event),
        EXITED => exited(session, &event),
        TERMINATED => terminate(session),
        BREAKPOINT => breakpoint(session, &event),
        _ => {}
    }
}

fn stopped(session: &DebugSession, event: &Event) {
    let Ok(stop) = event.body_as::<StoppedBody>() else {
        return;
    };
    let thread_id = stop.thread_id.unwrap_or(0);
    let reason = stop.reason.unwrap_or_else(|| "stopped".to_string());
    if !session.transition(DebugState::Stopped {
        thread_id,
        reason: reason.clone(),
    }) {
        return;
    }
    session.refresh_threads();
    session.emit(DebugEvent::Stopped {
        thread_id,
        reason,
        description: stop.description,
        hit_breakpoint_ids: stop.hit_breakpoint_ids,
    });
}

fn continued(session: &DebugSession, event: &Event) {
    let Ok(resumed) = event.body_as::<ContinuedBody>() else {
        return;
    };
    if !session.transition(DebugState::Running) {
        return;
    }
    session.emit(DebugEvent::Continued {
        thread_id: resumed.thread_id,
    });
}

fn output(session: &DebugSession, event: &Event) {
    let Ok(text) = event.body_as::<OutputBody>() else {
        return;
    };
    session
        .listener
        .on_output(text.category_or_console().to_string(), text.output);
}

fn exited(session: &DebugSession, event: &Event) {
    let Ok(exit) = event.body_as::<ExitedBody>() else {
        return;
    };
    if !session.transition(DebugState::Exited {
        code: exit.exit_code,
    }) {
        return;
    }
    session.emit(DebugEvent::Exited {
        code: exit.exit_code,
    });
}

fn breakpoint(session: &DebugSession, event: &Event) {
    let Ok(changed) = event.body_as::<BreakpointBody>() else {
        return;
    };
    session.mark_verified(&changed.breakpoint);
}

fn terminate(session: &DebugSession) {
    if session.abandon_launch("the adapter ended before the launch completed") {
        return;
    }
    if session.transition(DebugState::Terminated) {
        session.emit(DebugEvent::Terminated);
    }
}
