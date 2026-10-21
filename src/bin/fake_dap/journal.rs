use std::fs::OpenOptions;
use std::io::Write;

use serde_json::Value;

pub fn record(path: Option<&str>, message: &Value) {
    let Some(path) = path else {
        return;
    };
    let Ok(mut file) = OpenOptions::new().create(true).append(true).open(path) else {
        return;
    };
    let _ = writeln!(file, "{message}");
}
