use std::path::Path;
use std::process::ExitCode;
use std::time::Instant;

use ride_engine::{CompletionContext, CompletionQuery, EngineConfig, QueryMode, engine_start};

use crate::out;

pub struct Cursor {
    pub byte: Option<usize>,
    pub find: Option<String>,
    pub typed: Option<String>,
}

pub fn run(config: EngineConfig, file: &Path, cursor: Cursor, repeat: u32) -> ExitCode {
    let Ok(mut text) = std::fs::read_to_string(file) else {
        eprintln!("cannot read {}", file.display());
        return ExitCode::from(2);
    };
    let mut at = match (&cursor.byte, &cursor.find) {
        (Some(b), _) => *b,
        (None, Some(anchor)) => match text.find(anchor.as_str()) {
            Some(i) => i + anchor.len(),
            None => {
                eprintln!("anchor not found: {anchor}");
                return ExitCode::from(2);
            }
        },
        (None, None) => text.len(),
    };
    if let Some(typed) = &cursor.typed {
        text.insert_str(at, typed);
        at += typed.len();
    }
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
