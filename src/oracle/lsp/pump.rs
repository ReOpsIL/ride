use std::io::BufReader;
use std::process::{ChildStdin, ChildStdout};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};

use serde_json::{Value, json};

use crate::wire::{Mailbox, read_frame};

use super::outgoing::write;

pub struct Pump {
    pub mailbox: Arc<Mailbox>,
    pub stdin: Arc<Mutex<ChildStdin>>,
    pub quiescent: Arc<AtomicBool>,
}

impl Pump {
    pub fn run(self, stdout: ChildStdout) {
        let mut reader = BufReader::new(stdout);
        loop {
            match read_frame(&mut reader) {
                Ok(Some(message)) => self.route(message),
                Ok(None) => return self.mailbox.fail("rust-analyzer exited"),
                Err(err) => return self.mailbox.fail(&err.to_string()),
            }
        }
    }

    fn route(&self, message: Value) {
        let method = message.get("method").and_then(Value::as_str);
        match (method, message.get("id")) {
            (None, Some(id)) => {
                if let Some(id) = id.as_i64() {
                    self.mailbox.deliver(id, message);
                }
            }
            (Some(_), Some(id)) => {
                let reply = json!({ "jsonrpc": "2.0", "id": id, "result": null });
                let _ = write(&self.stdin, &reply);
            }
            (Some("experimental/serverStatus"), None) => {
                let quiescent = message["params"]["quiescent"].as_bool().unwrap_or(false);
                self.quiescent.store(quiescent, Ordering::SeqCst);
            }
            _ => {}
        }
    }
}
