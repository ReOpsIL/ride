use std::path::PathBuf;
use std::process::ExitCode;

use clap::{Parser, Subcommand};
use ride_engine::{EngineConfig, engine_start, last_status, rebuild_index, write_index};

#[derive(Parser, Debug)]
#[command(name = "ride-engine", version)]
struct Cli {
    #[arg(long, global = true)]
    project_path: Option<String>,
    #[arg(long, global = true)]
    index_dir: Option<String>,
    #[command(subcommand)]
    command: Option<Command>,
}

#[derive(Subcommand, Debug)]
enum Command {
    Index {
        #[arg(long)]
        force: bool,
    },
    Query {
        query: String,
    },
    Status,
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    match cli.command {
        None => {
            if let Some(path) = cli.project_path {
                println!("Project root folder: {path}");
            }
            ExitCode::SUCCESS
        }
        Some(Command::Index { force }) => index_cmd(cli.project_path, cli.index_dir, force),
        Some(Command::Query { query }) => {
            query_cmd(query, cli.index_dir);
            ExitCode::SUCCESS
        }
        Some(Command::Status) => {
            status_cmd(cli.index_dir);
            ExitCode::SUCCESS
        }
    }
}

fn index_cmd(project_path: Option<String>, index_dir: Option<String>, force: bool) -> ExitCode {
    let Some(project) = project_path else {
        eprintln!("index requires --project-path");
        return ExitCode::from(2);
    };
    let Some(index_dir) = index_dir else {
        eprintln!("index requires --index-dir");
        return ExitCode::from(2);
    };
    let config = config(Some(index_dir.clone()));
    let run = if force { rebuild_index } else { write_index };
    match run(
        PathBuf::from(project).as_path(),
        PathBuf::from(index_dir).as_path(),
        &config,
    ) {
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

fn query_cmd(query: String, index_dir: Option<String>) {
    let engine = engine_start(config(index_dir));
    let mode = if query.contains(' ') {
        ride_engine::QueryMode::Phrase
    } else {
        ride_engine::QueryMode::Items
    };
    let resp = engine.query_completions(ride_engine::CompletionQuery {
        query_id: 1,
        session_id: 0,
        prefix: query,
        mode,
        cursor_byte: 0,
        replace_start_byte: 0,
        current_crate: None,
        current_module: None,
        kind_filter: None,
        limit: 20,
    });
    let hits: Vec<HitOut> = resp
        .hits
        .iter()
        .map(|h| HitOut {
            name: h.name.clone(),
            path: h.path.clone(),
            kind: format!("{:?}", h.item_kind),
            crate_name: h.crate_name.clone(),
            score: h.score,
        })
        .collect();
    match serde_json::to_string(&QueryOut {
        query_id: resp.query_id,
        truncated: resp.truncated,
        hits,
    }) {
        Ok(s) => println!("{s}"),
        Err(e) => eprintln!("{e}"),
    }
}

fn status_cmd(index_dir: Option<String>) {
    if let Some(dir) = &index_dir
        && let Some(status) = last_status(PathBuf::from(dir).as_path())
    {
        println!(
            "{:?} docs={} crates={}/{} warnings={}",
            status.state, status.docs, status.crates_done, status.crates_total, status.warnings
        );
        return;
    }
    let engine = engine_start(config(index_dir));
    let s = engine.status();
    println!("{:?}", s.state);
}

fn config(index_dir: Option<String>) -> EngineConfig {
    EngineConfig {
        index_dir: index_dir.unwrap_or_else(|| ".".into()),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
    }
}

#[derive(serde::Serialize)]
struct QueryOut {
    query_id: u64,
    truncated: bool,
    hits: Vec<HitOut>,
}

#[derive(serde::Serialize)]
struct HitOut {
    name: String,
    path: String,
    kind: String,
    crate_name: String,
    score: f32,
}
