use std::io::BufReader;
use std::process::ChildStdout;
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::mpsc::Sender;

use serde_json::Value;

use super::codec::read_frame;
use super::inbox::Shared;

pub type Events = Sender<(u64, Value)>;

pub fn pump(stdout: ChildStdout, shared: Shared, events: Events, received: Arc<AtomicU64>) {
    let mut reader = BufReader::new(stdout);
    loop {
        match read_frame(&mut reader) {
            Ok(Some(message)) => {
                super::trace::record("<-", &message);
                if dispatch(message, &shared, &events, &received).is_err() {
                    return;
                }
            }
            Ok(None) => return fail(&shared, "adapter closed the connection"),
            Err(err) => return fail(&shared, &err.to_string()),
        }
    }
}

fn dispatch(
    message: Value,
    shared: &Shared,
    events: &Events,
    received: &Arc<AtomicU64>,
) -> Result<(), ()> {
    let (lock, signal) = &**shared;
    match message.get("type").and_then(Value::as_str).unwrap_or("") {
        "response" => {
            let seq = message
                .get("request_seq")
                .and_then(Value::as_i64)
                .unwrap_or(-1);
            let mut inbox = lock.lock().map_err(|_| ())?;
            if !inbox.timed_out.remove(&seq) {
                inbox.responses.insert(seq, message);
            }
            signal.notify_all();
            Ok(())
        }
        "event" => {
            let stamp = received.fetch_add(1, Ordering::SeqCst) + 1;
            events.send((stamp, message)).map_err(|_| ())
        }
        _ => Ok(()),
    }
}

fn fail(shared: &Shared, reason: &str) {
    let (lock, signal) = &**shared;
    if let Ok(mut inbox) = lock.lock() {
        inbox.failure = Some(reason.to_string());
        signal.notify_all();
    }
}
