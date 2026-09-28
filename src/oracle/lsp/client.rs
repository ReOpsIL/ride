use std::path::Path;
use std::process::{Child, ChildStdin, Command, Stdio};
use std::sync::atomic::{AtomicBool, AtomicI64, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

use serde_json::{Value, json};

use crate::oracle::error::OracleError;
use crate::wire::{Mailbox, MailboxError};

use super::outgoing::write;
use super::pump::Pump;

pub struct Client {
    child: Mutex<Child>,
    stdin: Arc<Mutex<ChildStdin>>,
    next_id: AtomicI64,
    mailbox: Arc<Mailbox>,
    quiescent: Arc<AtomicBool>,
}

impl Client {
    pub fn spawn(program: &Path, args: &[&str], root: &Path) -> Result<Self, OracleError> {
        let mut child = Command::new(program)
            .args(args)
            .current_dir(root)
            .env("PATH", crate::toolchain::search_path())
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn()
            .map_err(|err| OracleError::Spawn(err.to_string()))?;
        let (Some(stdin), Some(stdout)) = (child.stdin.take(), child.stdout.take()) else {
            let _ = child.kill();
            return Err(OracleError::Spawn("pipes unavailable".into()));
        };
        let stdin = Arc::new(Mutex::new(stdin));
        let mailbox = Arc::new(Mailbox::default());
        let quiescent = Arc::new(AtomicBool::new(false));
        let pump = Pump {
            mailbox: Arc::clone(&mailbox),
            stdin: Arc::clone(&stdin),
            quiescent: Arc::clone(&quiescent),
        };
        thread::Builder::new()
            .name("ride-oracle-pump".into())
            .spawn(move || pump.run(stdout))
            .map_err(|err| OracleError::Spawn(err.to_string()))?;
        Ok(Self {
            child: Mutex::new(child),
            stdin,
            next_id: AtomicI64::new(1),
            mailbox,
            quiescent,
        })
    }

    pub fn request(
        &self,
        method: &str,
        params: Value,
        timeout: Duration,
    ) -> Result<Value, OracleError> {
        let id = self.next_id.fetch_add(1, Ordering::SeqCst);
        let message = json!({ "jsonrpc": "2.0", "id": id, "method": method, "params": params });
        write(&self.stdin, &message)?;
        match self.mailbox.wait(id, timeout) {
            Ok(reply) => result_of(reply, method),
            Err(source) => {
                if source == MailboxError::TimedOut {
                    let _ = self.notify("$/cancelRequest", json!({ "id": id }));
                }
                Err(OracleError::Reply {
                    method: method.to_string(),
                    source,
                })
            }
        }
    }

    pub fn notify(&self, method: &str, params: Value) -> Result<(), OracleError> {
        write(
            &self.stdin,
            &json!({ "jsonrpc": "2.0", "method": method, "params": params }),
        )
    }

    pub fn is_quiescent(&self) -> bool {
        self.quiescent.load(Ordering::SeqCst)
    }

    pub fn failure(&self) -> Option<String> {
        self.mailbox.failure()
    }
}

impl Drop for Client {
    fn drop(&mut self) {
        if let Ok(mut child) = self.child.lock() {
            let _ = child.kill();
            let _ = child.wait();
        }
    }
}

fn result_of(reply: Value, method: &str) -> Result<Value, OracleError> {
    if let Some(error) = reply.get("error") {
        return Err(OracleError::Server {
            method: method.to_string(),
            message: error["message"].as_str().unwrap_or("error").to_string(),
        });
    }
    Ok(reply.get("result").cloned().unwrap_or(Value::Null))
}
