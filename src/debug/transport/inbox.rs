use std::collections::{HashMap, HashSet};
use std::sync::{Arc, Condvar, Mutex};
use std::time::{Duration, Instant};

use serde_json::Value;

use crate::error::EngineError;

#[derive(Default)]
pub struct Inbox {
    pub responses: HashMap<i64, Value>,
    pub timed_out: HashSet<i64>,
    pub failure: Option<String>,
}

pub type Shared = Arc<(Mutex<Inbox>, Condvar)>;

pub fn shared() -> Shared {
    Arc::new((Mutex::new(Inbox::default()), Condvar::new()))
}

pub fn await_response(
    shared: &Shared,
    seq: i64,
    command: &str,
    timeout: Duration,
) -> Result<Value, EngineError> {
    let (lock, signal) = &**shared;
    let deadline = Instant::now() + timeout;
    let mut inbox = lock.lock().map_err(|_| poisoned())?;
    loop {
        if let Some(message) = inbox.responses.remove(&seq) {
            return body_of(message, command);
        }
        if let Some(failure) = &inbox.failure {
            return Err(EngineError::debug(format!("{command}: {failure}")));
        }
        let left = deadline.saturating_duration_since(Instant::now());
        if left.is_zero() {
            inbox.timed_out.insert(seq);
            return Err(EngineError::debug(format!("{command}: timed out")));
        }
        inbox = signal.wait_timeout(inbox, left).map_err(|_| poisoned())?.0;
    }
}

pub fn poisoned() -> EngineError {
    EngineError::debug("transport poisoned")
}

fn body_of(message: Value, command: &str) -> Result<Value, EngineError> {
    let ok = message
        .get("success")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    if !ok {
        let reason = crate::debug::protocol::failure_text(&message)
            .or_else(|| {
                message
                    .get("message")
                    .and_then(Value::as_str)
                    .map(str::to_string)
            })
            .unwrap_or_else(|| "request failed".to_string());
        return Err(EngineError::debug(format!("{command}: {reason}")));
    }
    Ok(message.get("body").cloned().unwrap_or(Value::Null))
}
