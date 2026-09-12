mod frame;

use std::io::Write;
use std::path::Path;
use std::process::{Child, ChildStdin, Command, Stdio};
use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::mpsc::{Receiver, RecvTimeoutError, channel};
use std::sync::{Arc, Condvar, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use serde_json::{Value, json};

use crate::error::EngineError;
use frame::{Inbox, Shared, pump};

pub const DEFAULT_TIMEOUT: Duration = Duration::from_secs(15);

pub struct Transport {
    child: Mutex<Child>,
    stdin: Mutex<ChildStdin>,
    seq: AtomicI64,
    shared: Shared,
    events: Mutex<Receiver<Value>>,
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
            child: Mutex::new(child),
            stdin: Mutex::new(stdin),
            seq: AtomicI64::new(1),
            shared,
            events: Mutex::new(events),
            timeout: DEFAULT_TIMEOUT,
        })
    }

    pub fn with_timeout(mut self, timeout: Duration) -> Self {
        self.timeout = timeout;
        self
    }

    pub fn request(&self, command: &str, arguments: Value) -> Result<Value, EngineError> {
        self.request_within(command, arguments, self.timeout)
    }

    pub fn request_within(
        &self,
        command: &str,
        arguments: Value,
        timeout: Duration,
    ) -> Result<Value, EngineError> {
        let seq = self.send_request(command, arguments)?;
        self.await_within(seq, command, timeout)
    }

    pub fn shutdown(&self) {
        let Ok(mut child) = self.child.lock() else {
            return;
        };
        let _ = child.kill();
        let _ = child.wait();
    }

    pub fn send_request(&self, command: &str, arguments: Value) -> Result<i64, EngineError> {
        let seq = self.seq.fetch_add(1, Ordering::SeqCst);
        let mut message = json!({ "seq": seq, "type": "request", "command": command });
        if !arguments.is_null() {
            message["arguments"] = arguments;
        }
        self.send(&message)
            .map_err(|err| EngineError::debug(format!("{command}: {err}")))?;
        Ok(seq)
    }

    pub fn try_event(&self) -> Option<Value> {
        self.events
            .lock()
            .ok()
            .and_then(|events| events.try_recv().ok())
    }

    pub fn poll_event(&self, timeout: Duration) -> Result<Option<Value>, EngineError> {
        let events = self
            .events
            .lock()
            .map_err(|_| EngineError::debug("transport poisoned"))?;
        match events.recv_timeout(timeout) {
            Ok(event) => Ok(Some(event)),
            Err(RecvTimeoutError::Timeout) => Ok(None),
            Err(RecvTimeoutError::Disconnected) => {
                Err(EngineError::debug("adapter closed the connection"))
            }
        }
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

    pub fn await_response(&self, seq: i64, command: &str) -> Result<Value, EngineError> {
        self.await_within(seq, command, self.timeout)
    }

    pub fn await_within(
        &self,
        seq: i64,
        command: &str,
        timeout: Duration,
    ) -> Result<Value, EngineError> {
        let (lock, signal) = &*self.shared;
        let deadline = Instant::now() + timeout;
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
                inbox.timed_out.insert(seq);
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
        self.shutdown();
    }
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
