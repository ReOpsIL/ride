use std::collections::BTreeMap;
use std::path::Path;

use crate::error::EngineError;
use crate::ffi::{Breakpoint, DebugEvent};

use super::DebugSession;
use super::wire::{arguments, body};
use crate::debug::protocol::{
    SetBreakpointsArguments, SetBreakpointsResponseBody, Source, SourceBreakpoint,
};

pub const SET_BREAKPOINTS: &str = "setBreakpoints";

pub fn group(breakpoints: Vec<Breakpoint>) -> BTreeMap<String, Vec<Breakpoint>> {
    let mut grouped: BTreeMap<String, Vec<Breakpoint>> = BTreeMap::new();
    for breakpoint in breakpoints {
        grouped
            .entry(breakpoint.path.clone())
            .or_default()
            .push(breakpoint);
    }
    grouped
}

fn source_of(path: &str) -> Source {
    let name = Path::new(path)
        .file_name()
        .map(|name| name.to_string_lossy().to_string())
        .unwrap_or_else(|| path.to_string());
    Source::file(path, &name)
}

fn wanted(breakpoint: &Breakpoint) -> SourceBreakpoint {
    SourceBreakpoint {
        line: breakpoint.line,
        column: None,
        condition: breakpoint.condition.clone(),
        hit_condition: breakpoint.hit_condition.clone(),
        log_message: None,
    }
}

fn verified(
    mut breakpoints: Vec<Breakpoint>,
    reported: SetBreakpointsResponseBody,
) -> Vec<Breakpoint> {
    for (breakpoint, actual) in breakpoints.iter_mut().zip(reported.breakpoints) {
        breakpoint.verified = actual.verified;
        if let Some(line) = actual.line {
            breakpoint.line = line;
        }
    }
    breakpoints
}

impl DebugSession {
    pub fn set_breakpoints(
        &self,
        path: &str,
        breakpoints: Vec<Breakpoint>,
    ) -> Result<Vec<Breakpoint>, EngineError> {
        let request =
            SetBreakpointsArguments::new(source_of(path), breakpoints.iter().map(wanted).collect());
        let response = self
            .transport
            .request(SET_BREAKPOINTS, arguments(SET_BREAKPOINTS, &request)?)?;
        let reported = body::<SetBreakpointsResponseBody>(SET_BREAKPOINTS, response)?;
        let merged = verified(breakpoints, reported);
        if let Ok(mut store) = self.breakpoints.lock() {
            store.insert(path.to_string(), merged.clone());
        }
        self.emit(DebugEvent::Breakpoints {
            path: path.to_string(),
            breakpoints: merged.clone(),
        });
        Ok(merged)
    }

    pub(super) fn send_stored_breakpoints(&self) -> Result<(), EngineError> {
        let stored = self
            .breakpoints
            .lock()
            .map(|store| store.clone())
            .map_err(|_| EngineError::debug("breakpoint store poisoned"))?;
        for (path, breakpoints) in stored {
            self.set_breakpoints(&path, breakpoints)?;
        }
        Ok(())
    }

    pub(super) fn mark_verified(&self, reported: &crate::debug::protocol::Breakpoint) {
        let Some(line) = reported.line else {
            return;
        };
        let Some(path) = reported
            .source
            .as_ref()
            .and_then(|source| source.path.clone())
        else {
            return;
        };
        let updated = self.breakpoints.lock().ok().and_then(|mut store| {
            let entries = store.get_mut(&path)?;
            let entry = entries.iter_mut().find(|entry| entry.line == line)?;
            entry.verified = reported.verified;
            Some(entries.clone())
        });
        if let Some(breakpoints) = updated {
            self.emit(DebugEvent::Breakpoints { path, breakpoints });
        }
    }
}
