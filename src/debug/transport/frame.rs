use std::collections::{HashMap, HashSet};
use std::io::{BufRead, BufReader};
use std::process::ChildStdout;
use std::sync::mpsc::Sender;
use std::sync::{Arc, Condvar, Mutex};

use serde_json::Value;

use crate::error::EngineError;

#[derive(Default)]
pub struct Inbox {
    pub responses: HashMap<i64, Value>,
    pub timed_out: HashSet<i64>,
    pub failure: Option<String>,
}

pub type Shared = Arc<(Mutex<Inbox>, Condvar)>;

pub fn pump(stdout: ChildStdout, shared: Shared, events: Sender<Value>) {
    let mut reader = BufReader::new(stdout);
    loop {
        match read_frame(&mut reader) {
            Ok(Some(message)) => {
                if dispatch(message, &shared, &events).is_err() {
                    return;
                }
            }
            Ok(None) => return fail(&shared, "adapter closed the connection"),
            Err(err) => return fail(&shared, &err.to_string()),
        }
    }
}

fn dispatch(message: Value, shared: &Shared, events: &Sender<Value>) -> Result<(), ()> {
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
        "event" => events.send(message).map_err(|_| ()),
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

fn read_frame<R: BufRead>(reader: &mut R) -> Result<Option<Value>, EngineError> {
    let mut length: Option<usize> = None;
    loop {
        let mut line = String::new();
        let read = reader
            .read_line(&mut line)
            .map_err(|err| EngineError::debug(format!("read header: {err}")))?;
        if read == 0 {
            return match length {
                Some(_) => Err(EngineError::debug("truncated header")),
                None => Ok(None),
            };
        }
        let header = line.trim_end_matches(['\r', '\n']);
        if header.is_empty() {
            break;
        }
        if let Some((name, value)) = header.split_once(':')
            && name.trim().eq_ignore_ascii_case("content-length")
        {
            let parsed = value
                .trim()
                .parse::<usize>()
                .map_err(|err| EngineError::debug(format!("content length: {err}")))?;
            length = Some(parsed);
        }
    }
    let length = length.ok_or_else(|| EngineError::debug("frame without content length"))?;
    let mut body = vec![0u8; length];
    reader
        .read_exact(&mut body)
        .map_err(|err| EngineError::debug(format!("truncated frame: {err}")))?;
    serde_json::from_slice(&body).map_err(|err| EngineError::debug(format!("frame json: {err}")))
}
