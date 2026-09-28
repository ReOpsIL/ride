use std::collections::{HashMap, VecDeque};
use std::path::PathBuf;
use std::sync::Arc;
use std::sync::mpsc::{Receiver, Sender, channel};
use std::thread;
use std::time::{Duration, Instant};

use crate::ffi::{CompletionHit, OracleState};

use super::discover;
use super::error::OracleError;
use super::job::SiteJob;
use super::restarts::Restarts;
use super::roots::Roots;
use super::server::Server;
use super::shared::Shared;
use super::sidecar::Sidecar;

type Key = (Server, PathBuf);

const LOAD_TIMEOUT: Duration = Duration::from_secs(180);
const POLL: Duration = Duration::from_millis(100);

pub enum Msg {
    Complete(SiteJob),
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
    sidecars: HashMap<Key, Sidecar>,
    roots: Roots,
    restarts: Restarts<Key>,
}

impl Worker {
    fn run(mut self) {
        while let Some(msg) = self.next() {
            match msg {
                Msg::Complete(job) => {
                    let key = job.key;
                    if !self.superseded(&job) {
                        self.complete(&job);
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

    fn superseded(&mut self, job: &SiteJob) -> bool {
        while let Ok(msg) = self.rx.try_recv() {
            self.backlog.push_back(msg);
        }
        let session = job.doc.session_id;
        self.backlog.iter().any(|msg| match msg {
            Msg::Complete(next) => next.doc.session_id == session,
            Msg::Close(id) => *id == session,
            Msg::StopAll | Msg::Quit => true,
        })
    }

    fn close(&mut self, session_id: u64) {
        for sidecar in self.sidecars.values_mut() {
            sidecar.close(session_id);
        }
    }

    fn complete(&mut self, job: &SiteJob) {
        let Some(server) = Server::for_lang(job.doc.lang) else {
            return;
        };
        let Some(root) = self.roots.of(server, &job.doc.path) else {
            return;
        };
        let key = (server, root);
        if let Err(err) = self.ensure(&key) {
            self.shared.board.fail(&err);
            return;
        }
        if !self.await_ready(&key, job) {
            return;
        }
        match self.query(&key, job) {
            Ok(hits) if !hits.is_empty() => self.shared.store(job.key, hits),
            Ok(_) => {}
            Err(_) => self.check_exit(&key),
        }
    }

    fn ensure(&mut self, key: &Key) -> Result<(), OracleError> {
        if self.sidecars.contains_key(key) {
            return Ok(());
        }
        let (server, root) = key;
        if self.restarts.exhausted(key) {
            return Err(OracleError::GaveUp(format!(
                "{} in {}",
                server.name(),
                root.display()
            )));
        }
        self.announce(OracleState::Starting, *server);
        let program = discover::program(*server)?;
        let sidecar =
            Sidecar::start(*server, &program, root).inspect_err(|_| self.restarts.record(key))?;
        self.sidecars.insert(key.clone(), sidecar);
        Ok(())
    }

    fn await_ready(&mut self, key: &Key, job: &SiteJob) -> bool {
        let started = Instant::now();
        loop {
            let Some(sidecar) = self.sidecars.get(key) else {
                return false;
            };
            if sidecar.failure().is_some() {
                self.check_exit(key);
                return false;
            }
            if sidecar.ready() {
                self.announce(OracleState::Ready, key.0);
                return true;
            }
            self.announce(OracleState::Starting, key.0);
            if started.elapsed() > LOAD_TIMEOUT || self.superseded(job) {
                return false;
            }
            thread::sleep(POLL);
        }
    }

    fn query(&mut self, key: &Key, job: &SiteJob) -> Result<Vec<CompletionHit>, OracleError> {
        let sidecar = self
            .sidecars
            .get_mut(key)
            .ok_or_else(|| OracleError::GaveUp(key.1.display().to_string()))?;
        for doc in &job.stale {
            if !sidecar.holds(doc.session_id) {
                continue;
            }
            sidecar.sync(doc)?;
            self.shared.mark_synced(doc.session_id, doc.version);
        }
        sidecar.sync(&job.doc)?;
        self.shared.mark_synced(job.doc.session_id, job.doc.version);
        sidecar.complete(&job.doc, job.key.site, job.shape)
    }

    fn check_exit(&mut self, key: &Key) {
        let Some(exit) = self.sidecars.get(key).and_then(Sidecar::failure) else {
            return;
        };
        if let Some(sidecar) = self.sidecars.remove(key) {
            for session_id in sidecar.sessions() {
                self.shared.unmark(session_id);
            }
        }
        self.restarts.record(key);
        let message = format!("{}: {exit}", key.0.name());
        self.shared.board.set(OracleState::Failed, Some(message));
    }

    fn announce(&self, state: OracleState, server: Server) {
        self.shared
            .board
            .set(state, Some(server.name().to_string()));
    }
}
