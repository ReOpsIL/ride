use std::io::BufReader;
use std::process::ChildStdout;
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::mpsc::Sender;

use serde_json::Value;

use crate::wire::{Mailbox, read_frame};

pub type Events = Sender<(u64, Value)>;

pub fn pump(stdout: ChildStdout, mailbox: Arc<Mailbox>, events: Events, received: Arc<AtomicU64>) {
    let mut reader = BufReader::new(stdout);
    loop {
        match read_frame(&mut reader) {
            Ok(Some(message)) => {
                super::trace::record("<-", &message);
                if dispatch(message, &mailbox, &events, &received).is_err() {
                    return;
                }
            }
            Ok(None) => return mailbox.fail("adapter closed the connection"),
            Err(err) => return mailbox.fail(&err.to_string()),
        }
    }
}

fn dispatch(
    message: Value,
    mailbox: &Mailbox,
    events: &Events,
    received: &Arc<AtomicU64>,
) -> Result<(), ()> {
    match message.get("type").and_then(Value::as_str).unwrap_or("") {
        "response" => {
            let seq = message
                .get("request_seq")
                .and_then(Value::as_i64)
                .unwrap_or(-1);
            mailbox.deliver(seq, message);
            Ok(())
        }
        "event" => {
            let stamp = received.fetch_add(1, Ordering::SeqCst) + 1;
            events.send((stamp, message)).map_err(|_| ())
        }
        _ => Ok(()),
    }
}
