use std::path::PathBuf;
use std::process::ExitCode;

use clap::{Parser, Subcommand};

mod complete;
mod out;
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
        #[arg(long, default_value_t = 1)]
        repeat: u32,
    },
    Complete {
        file: PathBuf,
        #[arg(long)]
        byte: Option<usize>,
        #[arg(long)]
        find: Option<String>,
        #[arg(long)]
        typed: Option<String>,
        #[arg(long, default_value_t = 1)]
        repeat: u32,
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
        Some(Command::Query { query, repeat }) => {
            query_cmd(query, cli.index_dir, repeat);
            ExitCode::SUCCESS
        }
        Some(Command::Complete {
            file,
            byte,
            find,
            typed,
            repeat,
        }) => complete::run(
            config(cli.index_dir),
            &file,
            complete::Cursor { byte, find, typed },
            repeat,
        ),
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

fn query_cmd(query: String, index_dir: Option<String>, repeat: u32) {
    let engine = engine_start(config(index_dir));
    let mode = if query.contains(' ') {
        ride_engine::QueryMode::Phrase
    } else {
        ride_engine::QueryMode::Items
    };
    let request = |id: u64| ride_engine::CompletionQuery {
        query_id: id,
        session_id: 0,
        prefix: query.clone(),
        mode,
        context: ride_engine::CompletionContext::Unknown,
        cursor_byte: 0,
        replace_start_byte: 0,
        current_crate: None,
        current_module: None,
        kind_filter: None,
        limit: 20,
    };
    let mut timings = Vec::new();
    let mut resp = engine.query_completions(request(1));
    for i in 2..=repeat.max(1) {
        let start = std::time::Instant::now();
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
