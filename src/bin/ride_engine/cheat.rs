use std::path::Path;
use std::process::ExitCode;

use ride_engine::{EngineConfig, engine_start};

use crate::cursor::{Cursor, place};

pub fn run(config: EngineConfig, file: &Path, cursor: Cursor, all: bool) -> ExitCode {
    let placed = match place(file, &cursor) {
        Ok(p) => p,
        Err(e) => {
            eprintln!("{e}");
            return ExitCode::from(2);
        }
    };
    let engine = engine_start(config);
    let Ok(open) = engine.open_session(
        "cli".into(),
        Some(file.display().to_string()),
        placed.text,
        None,
    ) else {
        eprintln!("cannot open session");
        return ExitCode::from(1);
    };
    let resp = engine.cheat_sheet(open.session_id, placed.at as u32, all);
    println!(
        "context {} prefix {:?} replace_start {}",
        resp.context, resp.prefix, resp.replace_start_byte
    );
    for section in &resp.sections {
        let tag = if section.matched { "" } else { "  (by prefix)" };
        println!("\n## {}{tag}", section.title);
        for entry in &section.entries {
            println!("- {}  — {}", entry.name, entry.doc);
            for line in entry.snippet.lines() {
                println!("    {line}");
            }
        }
    }
    ExitCode::SUCCESS
}
