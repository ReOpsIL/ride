use std::time::Duration;

use serde_json::Value;

use crate::error::EngineError;
use crate::wire::Mailbox;

pub fn await_body(
    mailbox: &Mailbox,
    seq: i64,
    command: &str,
    timeout: Duration,
) -> Result<Value, EngineError> {
    let message = mailbox
        .wait(seq, timeout)
        .map_err(|err| EngineError::debug(format!("{command}: {err}")))?;
    body_of(message, command)
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
