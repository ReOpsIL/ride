use std::path::Path;
use std::process::ExitCode;

use ride_engine::{CompletionContext, CompletionQuery, EngineConfig, QueryMode, engine_start};

use crate::cursor::{Cursor, place};
use crate::out;
use crate::timing::timed;

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
    let resp = timed(repeat, |id| engine.query_completions(request(id)));
    out::print(&resp);
    ExitCode::SUCCESS
}
