use std::collections::{BTreeMap, HashSet, VecDeque};
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, mpsc};
use std::thread;

use crate::error::EngineError;
use crate::ffi::{CheckResult, Diagnostic};

use super::clang::run_clang_check;
use super::compile_db;
use super::output::stderr_tail;

const WORKERS: usize = 4;

type IndexedFile = (usize, PathBuf);
type IndexedResult = (usize, Result<CheckResult, EngineError>);

pub fn run_check_c_project(root: &Path) -> Result<CheckResult, EngineError> {
    let files = compile_db::sources_in(root);
    if files.is_empty() {
        return Err(EngineError::Tool {
            message: format!("clang: no compile_commands.json under {}", root.display()),
        });
    }
    gather(files)
}

pub fn merge_indexed(jobs: impl IntoIterator<Item = (usize, CheckResult)>) -> CheckResult {
    let mut merged = Merge::default();
    for (index, check) in jobs {
        merged.push(index, check);
    }
    merged.finish()
}

fn gather(files: Vec<PathBuf>) -> Result<CheckResult, EngineError> {
    let (rx, threads) = start_pool(files);
    let mut merged = Merge::default();
    let mut first_err = None;
    for (index, item) in rx {
        match item {
            Ok(check) => merged.push(index, check),
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

fn start_pool(files: Vec<PathBuf>) -> (mpsc::Receiver<IndexedResult>, Vec<thread::JoinHandle<()>>) {
    let jobs = files.len().min(WORKERS);
    let (tx, rx) = mpsc::channel();
    let work = Arc::new(Mutex::new(
        files.into_iter().enumerate().collect::<VecDeque<_>>(),
    ));
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

fn drain(work: Arc<Mutex<VecDeque<IndexedFile>>>, tx: mpsc::Sender<IndexedResult>) {
    loop {
        let next = work.lock().ok().and_then(|mut q| q.pop_front());
        let Some((index, file)) = next else {
            break;
        };
        if tx.send((index, run_clang_check(&file))).is_err() {
            break;
        }
    }
}

#[derive(Default)]
struct Merge {
    jobs: BTreeMap<usize, CheckResult>,
}

impl Merge {
    fn push(&mut self, index: usize, check: CheckResult) {
        self.jobs.insert(index, check);
    }

    fn finish(self) -> CheckResult {
        let mut success = true;
        let mut diagnostics = Vec::new();
        let mut seen = HashSet::new();
        let mut tails = String::new();
        for check in self.jobs.into_values() {
            success &= check.success;
            take_diagnostics(&mut diagnostics, &mut seen, check.diagnostics);
            take_tail(&mut tails, &check.stderr_tail);
        }
        CheckResult {
            success,
            diagnostics,
            stderr_tail: stderr_tail(&tails),
        }
    }
}

fn take_diagnostics(
    diagnostics: &mut Vec<Diagnostic>,
    seen: &mut HashSet<(String, u32, String)>,
    incoming: Vec<Diagnostic>,
) {
    for d in incoming {
        if seen.insert((d.path.clone(), d.byte_start, d.message.clone())) {
            diagnostics.push(d);
        }
    }
}

fn take_tail(tails: &mut String, tail: &str) {
    if tail.is_empty() {
        return;
    }
    if !tails.is_empty() {
        tails.push('\n');
    }
    tails.push_str(tail);
}
