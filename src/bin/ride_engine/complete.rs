use std::path::Path;
use std::process::ExitCode;
use std::time::Instant;

use ride_engine::{CompletionContext, CompletionQuery, EngineConfig, QueryMode, engine_start};

use crate::cursor::{Cursor, place};
use crate::out;

pub fn run(config: EngineConfig, file: &Path, cursor: Cursor, repeat: u32) -> ExitCode {
    let placed = match place(file, &cursor) {
        Ok(p) => p,
        Err(e) => {
            eprintln!("{e}");
            return ExitCode::from(2);
        }
    };
    let (text, at) = (placed.text, placed.at);
    let engine = engine_start(config);
    if let Some(parent) = file.parent()
        && let Ok(root) = std::fs::canonicalize(parent)
    {
        let _ = engine.open_workspace(root.display().to_string());
    }
    std::thread::sleep(std::time::Duration::from_millis(300));
    let Ok(open) = engine.open_session("cli".into(), Some(file.display().to_string()), text, None)
    else {
        eprintln!("cannot open session");
        return ExitCode::from(1);
    };
    let request = |id: u64| CompletionQuery {
        query_id: id,
        session_id: open.session_id,
        prefix: String::new(),
        mode: QueryMode::BufferLocal,
        context: CompletionContext::Unknown,
        cursor_byte: at as u32,
        replace_start_byte: at as u32,
        current_crate: None,
        current_module: None,
        kind_filter: None,
        limit: 20,
    };
    let mut resp = engine.query_completions(request(1));
    let mut timings = Vec::new();
    for i in 2..=repeat.max(1) {
        let start = Instant::now();
        resp = engine.query_completions(request(u64::from(i)));
        timings.push(start.elapsed());
    }
    if !timings.is_empty() {
        timings.sort();
        let p50 = timings[timings.len() / 2];
        let p95 = timings[(timings.len() * 95 / 100).min(timings.len() - 1)];
        eprintln!("p50 {p50:?} p95 {p95:?} over {} runs", timings.len());
    }
    out::print(&resp);
    ExitCode::SUCCESS
}
