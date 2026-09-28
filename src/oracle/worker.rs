use std::collections::{HashMap, VecDeque};
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::sync::mpsc::{Receiver, Sender, channel};
use std::thread;
use std::time::{Duration, Instant};

use crate::ffi::{CompletionHit, OracleState};

use super::discover;
use super::error::OracleError;
use super::job::MemberJob;
use super::restarts::Restarts;
use super::roots::Roots;
use super::shared::Shared;
use super::sidecar::Sidecar;

const LOAD_TIMEOUT: Duration = Duration::from_secs(180);
const POLL: Duration = Duration::from_millis(100);

pub enum Msg {
    Members(MemberJob),
    Close(u64),
    StopAll,
    Quit,
}

pub fn spawn(shared: Arc<Shared>) -> Option<Sender<Msg>> {
    let (sender, rx) = channel();
    let worker = Worker {
        shared,
        rx,
        backlog: VecDeque::new(),
        sidecars: HashMap::new(),
        roots: Roots::default(),
        restarts: Restarts::default(),
    };
    thread::Builder::new()
        .name("ride-oracle".into())
        .spawn(move || worker.run())
        .ok()?;
    Some(sender)
}

struct Worker {
    shared: Arc<Shared>,
    rx: Receiver<Msg>,
    backlog: VecDeque<Msg>,
    sidecars: HashMap<PathBuf, Sidecar>,
    roots: Roots,
    restarts: Restarts,
}

impl Worker {
    fn run(mut self) {
        while let Some(msg) = self.next() {
            match msg {
                Msg::Members(job) => {
                    let key = job.key;
                    if !self.superseded(&job) {
                        self.members(&job);
                    }
                    self.shared.done(&key);
                }
                Msg::Close(session_id) => self.close(session_id),
                Msg::StopAll => {
                    self.sidecars.clear();
                    self.restarts.clear();
                    self.shared.board.set(OracleState::Idle, None);
                }
                Msg::Quit => return,
            }
        }
    }

    fn next(&mut self) -> Option<Msg> {
        self.backlog.pop_front().or_else(|| self.rx.recv().ok())
    }

    fn superseded(&mut self, job: &MemberJob) -> bool {
        while let Ok(msg) = self.rx.try_recv() {
            self.backlog.push_back(msg);
        }
        let session = job.doc.session_id;
        self.backlog.iter().any(|msg| match msg {
            Msg::Members(next) => next.doc.session_id == session,
            Msg::Close(id) => *id == session,
            Msg::StopAll | Msg::Quit => true,
        })
    }

    fn close(&mut self, session_id: u64) {
        for sidecar in self.sidecars.values_mut() {
            sidecar.close(session_id);
        }
    }

    fn members(&mut self, job: &MemberJob) {
        let Some(root) = self.roots.of(&job.doc.path) else {
            return;
        };
        if let Err(err) = self.ensure(&root) {
            self.shared.board.fail(&err);
            return;
        }
        if !self.await_ready(&root, job) {
            return;
        }
        match self.query(&root, job) {
            Ok(hits) if !hits.is_empty() => self.shared.store(job.key, hits),
            Ok(_) => {}
            Err(_) => self.check_exit(&root),
        }
    }

    fn ensure(&mut self, root: &Path) -> Result<(), OracleError> {
        if self.sidecars.contains_key(root) {
            return Ok(());
        }
        if self.restarts.exhausted(root) {
            return Err(OracleError::GaveUp(root.display().to_string()));
        }
        self.shared.board.set(OracleState::Starting, None);
        let program = discover::rust_analyzer()?;
        let sidecar = Sidecar::start(&program, root).inspect_err(|_| self.restarts.record(root))?;
        self.sidecars.insert(root.to_path_buf(), sidecar);
        Ok(())
    }

    fn await_ready(&mut self, root: &Path, job: &MemberJob) -> bool {
        let started = Instant::now();
        loop {
            let Some(sidecar) = self.sidecars.get(root) else {
                return false;
            };
            if sidecar.failure().is_some() {
                self.check_exit(root);
                return false;
            }
            if sidecar.ready() {
                self.shared.board.set(OracleState::Ready, None);
                return true;
            }
            self.shared.board.set(OracleState::Starting, None);
            if started.elapsed() > LOAD_TIMEOUT || self.superseded(job) {
                return false;
            }
            thread::sleep(POLL);
        }
    }

    fn query(&mut self, root: &Path, job: &MemberJob) -> Result<Vec<CompletionHit>, OracleError> {
        let sidecar = self
            .sidecars
            .get_mut(root)
            .ok_or_else(|| OracleError::GaveUp(root.display().to_string()))?;
        for doc in &job.stale {
            if !sidecar.holds(doc.session_id) {
                continue;
            }
            sidecar.sync(doc)?;
            self.shared.mark_synced(doc.session_id, doc.version);
        }
        sidecar.sync(&job.doc)?;
        self.shared.mark_synced(job.doc.session_id, job.doc.version);
        sidecar.members(&job.doc, job.key.site)
    }

    fn check_exit(&mut self, root: &Path) {
        let Some(exit) = self.sidecars.get(root).and_then(Sidecar::failure) else {
            return;
        };
        if let Some(sidecar) = self.sidecars.remove(root) {
            for session_id in sidecar.sessions() {
                self.shared.unmark(session_id);
            }
        }
        self.restarts.record(root);
        self.shared.board.set(OracleState::Failed, Some(exit));
    }
}
