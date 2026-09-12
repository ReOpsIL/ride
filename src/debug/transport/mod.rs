mod frame;

use std::io::Write;
use std::path::Path;
use std::process::{Child, ChildStdin, Command, Stdio};
use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::mpsc::{Receiver, TryIter, channel};
use std::sync::{Arc, Condvar, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use serde_json::{Value, json};

use crate::error::EngineError;
use frame::{Inbox, Shared, pump};

pub const DEFAULT_TIMEOUT: Duration = Duration::from_secs(15);

pub struct Transport {
    child: Child,
    stdin: Mutex<ChildStdin>,
    seq: AtomicI64,
    shared: Shared,
    events: Receiver<Value>,
    timeout: Duration,
}

impl Transport {
    pub fn spawn(program: &Path, args: &[String]) -> Result<Self, EngineError> {
        let mut child = Command::new(program)
            .args(args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn()
            .map_err(|err| EngineError::debug(format!("spawn {}: {err}", program.display())))?;
        let stdin = child
            .stdin
            .take()
            .ok_or_else(|| EngineError::debug("adapter stdin unavailable"))?;
        let stdout = child
            .stdout
            .take()
            .ok_or_else(|| EngineError::debug("adapter stdout unavailable"))?;
        let shared: Shared = Arc::new((Mutex::new(Inbox::default()), Condvar::new()));
        let (sender, events) = channel();
        let reader = Arc::clone(&shared);
        thread::spawn(move || pump(stdout, reader, sender));
        Ok(Self {
            child,
            stdin: Mutex::new(stdin),
            seq: AtomicI64::new(1),
            shared,
            events,
            timeout: DEFAULT_TIMEOUT,
        })
    }

    pub fn with_timeout(mut self, timeout: Duration) -> Self {
        self.timeout = timeout;
        self
    }

    pub fn request(&self, command: &str, arguments: Value) -> Result<Value, EngineError> {
        let seq = self.seq.fetch_add(1, Ordering::SeqCst);
        let mut message = json!({ "seq": seq, "type": "request", "command": command });
        if !arguments.is_null() {
            message["arguments"] = arguments;
        }
        self.send(&message)?;
        self.await_response(seq, command)
    }

    pub fn events(&self) -> TryIter<'_, Value> {
        self.events.try_iter()
    }

    pub fn next_event(&self, timeout: Duration) -> Result<Value, EngineError> {
        self.events
            .recv_timeout(timeout)
            .map_err(|err| EngineError::debug(format!("event: {err}")))
    }

    fn send(&self, message: &Value) -> Result<(), EngineError> {
        let body = serde_json::to_vec(message)
            .map_err(|err| EngineError::debug(format!("encode: {err}")))?;
        let mut stdin = self
            .stdin
            .lock()
            .map_err(|_| EngineError::debug("transport poisoned"))?;
        let header = format!("Content-Length: {}\r\n\r\n", body.len());
        stdin
            .write_all(header.as_bytes())
            .and_then(|()| stdin.write_all(&body))
            .and_then(|()| stdin.flush())
            .map_err(|err| EngineError::debug(format!("write: {err}")))
    }

    fn await_response(&self, seq: i64, command: &str) -> Result<Value, EngineError> {
        let (lock, signal) = &*self.shared;
        let deadline = Instant::now() + self.timeout;
        let mut inbox = lock
            .lock()
            .map_err(|_| EngineError::debug("transport poisoned"))?;
        loop {
            if let Some(message) = inbox.responses.remove(&seq) {
                return body_of(message, command);
            }
            if let Some(failure) = &inbox.failure {
                return Err(EngineError::debug(format!("{command}: {failure}")));
            }
            let left = deadline.saturating_duration_since(Instant::now());
            if left.is_zero() {
                return Err(EngineError::debug(format!("{command}: timed out")));
            }
            inbox = signal
                .wait_timeout(inbox, left)
                .map_err(|_| EngineError::debug("transport poisoned"))?
                .0;
        }
    }
}

impl Drop for Transport {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

fn body_of(message: Value, command: &str) -> Result<Value, EngineError> {
    let ok = message
        .get("success")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    if !ok {
        let reason = message
            .get("message")
            .and_then(Value::as_str)
            .unwrap_or("request failed");
        return Err(EngineError::debug(format!("{command}: {reason}")));
    }
    Ok(message.get("body").cloned().unwrap_or(Value::Null))
}
