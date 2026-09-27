use std::path::PathBuf;
use std::process::ExitCode;

use clap::{Parser, Subcommand};

mod cheat;
mod complete;
mod cursor;
mod index;
mod out;
mod query;
mod timing;

use ride_engine::EngineConfig;

#[derive(Parser, Debug)]
#[command(name = "ride-engine", version)]
struct Cli {
    #[arg(long, global = true)]
    project_path: Option<String>,
    #[arg(long, global = true)]
    index_dir: Option<String>,
    #[command(subcommand)]
    command: Command,
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
    Cheat {
        file: PathBuf,
        #[arg(long)]
        byte: Option<usize>,
        #[arg(long)]
        find: Option<String>,
        #[arg(long)]
        typed: Option<String>,
        #[arg(long)]
        all: bool,
    },
    Status,
    Tools,
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    let config = config(cli.index_dir.clone());
    match cli.command {
        Command::Index { force } => index::run(cli.project_path, cli.index_dir, force, config),
        Command::Query { query, repeat } => {
            query::run(config, query, repeat);
            ExitCode::SUCCESS
        }
        Command::Complete {
            file,
            byte,
            find,
            typed,
            repeat,
        } => complete::run(config, &file, cursor::Cursor { byte, find, typed }, repeat),
        Command::Cheat {
            file,
            byte,
            find,
            typed,
            all,
        } => cheat::run(config, &file, cursor::Cursor { byte, find, typed }, all),
        Command::Status => {
            index::status(cli.index_dir.as_deref(), config);
            ExitCode::SUCCESS
        }
        Command::Tools => {
            index::tools();
            ExitCode::SUCCESS
        }
    }
}

fn config(index_dir: Option<String>) -> EngineConfig {
    EngineConfig {
        index_dir: index_dir.unwrap_or_else(|| ".".into()),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
        refs_dir: None,
        report_dir: None,
    }
}
