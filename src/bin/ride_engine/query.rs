use ride_engine::{CompletionContext, CompletionQuery, EngineConfig, QueryMode, engine_start};

use crate::out;
use crate::timing::timed;

pub fn run(config: EngineConfig, query: String, repeat: u32) {
    let engine = engine_start(config);
    let mode = if query.contains(' ') {
        QueryMode::Phrase
    } else {
        QueryMode::Items
    };
    let request = |id: u64| CompletionQuery {
        query_id: id,
        session_id: 0,
        prefix: query.clone(),
        mode,
        context: CompletionContext::Unknown,
        cursor_byte: 0,
        replace_start_byte: 0,
        current_crate: None,
        current_module: None,
        kind_filter: None,
        limit: 20,
    };
    let resp = timed(repeat, |id| engine.query_completions(request(id)));
    out::print(&resp);
}
