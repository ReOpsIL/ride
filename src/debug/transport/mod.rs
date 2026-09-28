mod pump;
mod reply;
mod trace;

use std::path::Path;
use std::process::{Child, ChildStdin, Command, Stdio};
use std::sync::Arc;
use std::sync::Mutex;
use std::sync::atomic::{AtomicI64, AtomicU64, Ordering};
use std::sync::mpsc::{Receiver, RecvTimeoutError, channel};
use std::thread;
use std::time::Duration;

use serde_json::{Value, json};

use crate::error::EngineError;
use crate::wire::{Mailbox, write_frame};

const DEFAULT_TIMEOUT: Duration = Duration::from_secs(15);

pub struct Transport {
    child: Mutex<Child>,
    stdin: Mutex<ChildStdin>,
    seq: AtomicI64,
    mailbox: Arc<Mailbox>,
    events: Mutex<Receiver<(u64, Value)>>,
    received: Arc<AtomicU64>,
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
        let mailbox = Arc::new(Mailbox::default());
        let (sender, events) = channel();
        let reader = Arc::clone(&mailbox);
        let received = Arc::new(AtomicU64::new(0));
        let counter = Arc::clone(&received);
        thread::spawn(move || pump::pump(stdout, reader, sender, counter));
        Ok(Self {
            child: Mutex::new(child),
            stdin: Mutex::new(stdin),
            seq: AtomicI64::new(1),
            mailbox,
            events: Mutex::new(events),
            received,
        })
    }

    pub fn request(&self, command: &str, arguments: Value) -> Result<Value, EngineError> {
        self.request_within(command, arguments, DEFAULT_TIMEOUT)
    }

    pub fn request_within(
        &self,
        command: &str,
        arguments: Value,
        timeout: Duration,
    ) -> Result<Value, EngineError> {
        let seq = self.send_request(command, arguments)?;
        reply::await_body(&self.mailbox, seq, command, timeout)
    }

    pub fn await_response(&self, seq: i64, command: &str) -> Result<Value, EngineError> {
        reply::await_body(&self.mailbox, seq, command, DEFAULT_TIMEOUT)
    }

    pub fn send_request(&self, command: &str, arguments: Value) -> Result<i64, EngineError> {
        let seq = self.seq.fetch_add(1, Ordering::SeqCst);
        let mut message = json!({ "seq": seq, "type": "request", "command": command });
        if !arguments.is_null() {
            message["arguments"] = arguments;
        }
        trace::record("->", &message);
        let mut stdin = self
            .stdin
            .lock()
            .map_err(|_| EngineError::debug("transport poisoned"))?;
        write_frame(&mut *stdin, &message)
            .map_err(|err| EngineError::debug(format!("{command}: {err}")))?;
        Ok(seq)
    }

    pub fn events_received(&self) -> u64 {
        self.received.load(Ordering::SeqCst)
    }

    pub fn poll_received(&self, timeout: Duration) -> Result<Option<(u64, Value)>, EngineError> {
        let events = self
            .events
            .lock()
            .map_err(|_| EngineError::debug("transport poisoned"))?;
        match events.recv_timeout(timeout) {
            Ok(stamped) => Ok(Some(stamped)),
            Err(RecvTimeoutError::Timeout) => Ok(None),
            Err(RecvTimeoutError::Disconnected) => {
                Err(EngineError::debug("adapter closed the connection"))
            }
        }
    }

    pub fn shutdown(&self) {
        let Ok(mut child) = self.child.lock() else {
            return;
        };
        let _ = child.kill();
        let _ = child.wait();
    }
}

impl Drop for Transport {
    fn drop(&mut self) {
        self.shutdown();
    }
}
