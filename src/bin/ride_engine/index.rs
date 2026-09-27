use std::path::Path;
use std::process::ExitCode;

use ride_engine::{EngineConfig, engine_start, last_status, rebuild_index, write_index};

pub fn run(
    project_path: Option<String>,
    index_dir: Option<String>,
    force: bool,
    config: EngineConfig,
) -> ExitCode {
    let Some(project) = project_path else {
        eprintln!("index requires --project-path");
        return ExitCode::from(2);
    };
    let Some(index_dir) = index_dir else {
        eprintln!("index requires --index-dir");
        return ExitCode::from(2);
    };
    let run = if force { rebuild_index } else { write_index };
    match run(Path::new(&project), Path::new(&index_dir), &config) {
        Ok(status) => {
            println!(
                "{} docs {} crates {} warnings",
                status.docs, status.crates_done, status.warnings
            );
            ExitCode::SUCCESS
        }
        Err(e) => {
            eprintln!("{e}");
            ExitCode::from(1)
        }
    }
}

pub fn status(index_dir: Option<&str>, config: EngineConfig) {
    if let Some(status) = index_dir.and_then(|dir| last_status(Path::new(dir))) {
        println!(
            "{:?} docs={} crates={}/{} warnings={}",
            status.state, status.docs, status.crates_done, status.crates_total, status.warnings
        );
        return;
    }
    println!("{:?}", engine_start(config).status().state);
}

pub fn tools() {
    for tool in ride_engine::tool_status() {
        match tool.path {
            Some(path) => println!("{:<14} {path}", tool.name),
            None => println!(
                "{:<14} missing  ({}; {})",
                tool.name,
                tool.install.unwrap_or_else(|| "no installer found".into()),
                tool.hint
            ),
        }
    }
}
