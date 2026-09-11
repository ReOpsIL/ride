use std::collections::{HashSet, VecDeque};
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, mpsc};
use std::thread;

use crate::error::EngineError;
use crate::ffi::{CheckResult, Diagnostic};

use super::clang::run_clang_check;
use super::compile_db;
use super::output::stderr_tail;

const WORKERS: usize = 4;

pub fn run_check_c_project(root: &Path) -> Result<CheckResult, EngineError> {
    let files = compile_db::sources_in(root);
    if files.is_empty() {
        return Err(EngineError::Tool {
            message: format!("clang: no compile_commands.json under {}", root.display()),
        });
    }
    gather(files)
}

fn gather(files: Vec<PathBuf>) -> Result<CheckResult, EngineError> {
    let (rx, threads) = start_pool(files);
    let mut merged = Merge::default();
    let mut first_err = None;
    for item in rx {
        match item {
            Ok(check) => merged.push(check),
            Err(e) if first_err.is_none() => first_err = Some(e),
            Err(_) => {}
        }
    }
    for handle in threads {
        let _ = handle.join();
    }
    match first_err {
        Some(e) => Err(e),
        None => Ok(merged.finish()),
    }
}

fn start_pool(
    files: Vec<PathBuf>,
) -> (
    mpsc::Receiver<Result<CheckResult, EngineError>>,
    Vec<thread::JoinHandle<()>>,
) {
    let jobs = files.len().min(WORKERS);
    let (tx, rx) = mpsc::channel();
    let work = Arc::new(Mutex::new(VecDeque::from(files)));
    let mut threads = Vec::new();
    for i in 0..jobs {
        let work = Arc::clone(&work);
        let tx = tx.clone();
        if let Ok(handle) = thread::Builder::new()
            .name(format!("ride-clang-{i}"))
            .spawn(move || drain(work, tx))
        {
            threads.push(handle);
        }
    }
    if threads.is_empty() {
        drain(Arc::clone(&work), tx);
    } else {
        drop(tx);
    }
    (rx, threads)
}

fn drain(work: Arc<Mutex<VecDeque<PathBuf>>>, tx: mpsc::Sender<Result<CheckResult, EngineError>>) {
    loop {
        let next = work.lock().ok().and_then(|mut q| q.pop_front());
        let Some(file) = next else {
            break;
        };
        if tx.send(run_clang_check(&file)).is_err() {
            break;
        }
    }
}

struct Merge {
    success: bool,
    diagnostics: Vec<Diagnostic>,
    seen: HashSet<(String, u32, String)>,
    tails: String,
}

impl Default for Merge {
    fn default() -> Self {
        Self {
            success: true,
            diagnostics: Vec::new(),
            seen: HashSet::new(),
            tails: String::new(),
        }
    }
}

impl Merge {
    fn push(&mut self, check: CheckResult) {
        self.success &= check.success;
        for d in check.diagnostics {
            if self
                .seen
                .insert((d.path.clone(), d.byte_start, d.message.clone()))
            {
                self.diagnostics.push(d);
            }
        }
        if !check.stderr_tail.is_empty() {
            if !self.tails.is_empty() {
                self.tails.push('\n');
            }
            self.tails.push_str(&check.stderr_tail);
        }
    }

    fn finish(self) -> CheckResult {
        CheckResult {
            success: self.success,
            diagnostics: self.diagnostics,
            stderr_tail: stderr_tail(&self.tails),
        }
    }
}
