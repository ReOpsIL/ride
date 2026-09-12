use std::fs::OpenOptions;
use std::io::Write;
use std::sync::{Mutex, OnceLock};

use serde_json::Value;

pub const TRACE_VARIABLE: &str = "RIDE_DAP_TRACE";

fn sink() -> Option<&'static Mutex<std::fs::File>> {
    static SINK: OnceLock<Option<Mutex<std::fs::File>>> = OnceLock::new();
    SINK.get_or_init(|| {
        let path = std::env::var(TRACE_VARIABLE).ok()?;
        let file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(path)
            .ok()?;
        Some(Mutex::new(file))
    })
    .as_ref()
}

pub fn record(direction: &str, message: &Value) {
    let Some(sink) = sink() else {
        return;
    };
    let Ok(mut file) = sink.lock() else {
        return;
    };
    let _ = writeln!(file, "{direction} {message}");
    let _ = file.flush();
}
