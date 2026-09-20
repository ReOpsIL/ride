use std::fs::{OpenOptions, create_dir_all};
use std::io::Write;
use std::panic::PanicHookInfo;
use std::path::{Path, PathBuf};
use std::sync::{Once, OnceLock};
use std::time::{SystemTime, UNIX_EPOCH};

use super::line::panic_line;

static PATH: OnceLock<PathBuf> = OnceLock::new();
static INSTALLED: Once = Once::new();

pub fn install_panic_hook(dir: &Path) {
    let _ = PATH.set(dir.join("panics.jsonl"));
    INSTALLED.call_once(|| {
        let previous = std::panic::take_hook();
        std::panic::set_hook(Box::new(move |info| {
            append(info);
            previous(info);
        }));
    });
}

fn append(info: &PanicHookInfo<'_>) {
    let Some(path) = PATH.get() else {
        return;
    };
    match path.parent() {
        Some(parent) if create_dir_all(parent).is_err() => return,
        _ => {}
    }
    let Ok(mut file) = OpenOptions::new().create(true).append(true).open(path) else {
        return;
    };
    let line = panic_line(now(), &message(info), &location(info), &backtrace());
    let _ = writeln!(file, "{line}");
}

fn now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|elapsed| elapsed.as_secs())
        .unwrap_or_default()
}

fn message(info: &PanicHookInfo<'_>) -> String {
    let payload = info.payload();
    payload
        .downcast_ref::<&str>()
        .map(|text| (*text).to_string())
        .or_else(|| payload.downcast_ref::<String>().cloned())
        .unwrap_or_else(|| "panic".to_string())
}

fn location(info: &PanicHookInfo<'_>) -> String {
    info.location()
        .map(|at| format!("{}:{}:{}", at.file(), at.line(), at.column()))
        .unwrap_or_default()
}

fn backtrace() -> String {
    std::backtrace::Backtrace::force_capture().to_string()
}
