use std::path::Path;
use std::sync::OnceLock;

use crate::error::EngineError;
use crate::ffi::ExceptionFilter;

use super::adapter::adapter_path;
use super::protocol::{Capabilities, ExceptionBreakpointFilter, InitializeArguments};
use super::transport::Transport;

const INITIALIZE: &str = "initialize";

static CACHE: OnceLock<Vec<ExceptionFilter>> = OnceLock::new();

pub fn exception_filters() -> Vec<ExceptionFilter> {
    if let Some(cached) = CACHE.get() {
        return cached.clone();
    }
    let Ok(adapter) = adapter_path() else {
        return Vec::new();
    };
    let Ok(found) = probe_exception_filters(&adapter) else {
        return Vec::new();
    };
    CACHE.get_or_init(|| found).clone()
}

pub fn probe_exception_filters(adapter: &Path) -> Result<Vec<ExceptionFilter>, EngineError> {
    let transport = Transport::spawn(adapter, &[])?;
    let arguments = serde_json::to_value(InitializeArguments::ride())
        .map_err(|err| EngineError::debug(format!("{INITIALIZE} arguments: {err}")))?;
    let response = transport.request(INITIALIZE, arguments)?;
    let capabilities: Capabilities = serde_json::from_value(response)
        .map_err(|err| EngineError::debug(format!("{INITIALIZE} body: {err}")))?;
    transport.shutdown();
    Ok(capabilities
        .exception_breakpoint_filters
        .iter()
        .map(filter)
        .collect())
}

pub fn enabled(wanted: &[String], capabilities: &Capabilities) -> Vec<String> {
    wanted
        .iter()
        .filter(|id| capabilities.has_filter(id))
        .cloned()
        .collect()
}

fn filter(source: &ExceptionBreakpointFilter) -> ExceptionFilter {
    ExceptionFilter {
        id: source.filter.clone(),
        label: source.label.clone(),
        default_on: source.default.unwrap_or(false),
    }
}
