use std::collections::VecDeque;
use std::sync::Arc;
use std::sync::mpsc::{Receiver, Sender, channel};
use std::thread;
use std::time::{Duration, Instant};

use crate::ffi::OracleState;

use super::fleet::Key;
use super::job::{DocText, SiteJob};
use super::launch::Launcher;
use super::shared::Shared;
use super::sidecar::Sidecar;

const LOAD_TIMEOUT: Duration = Duration::from_secs(180);
const POLL: Duration = Duration::from_millis(100);

pub enum Msg {
    Complete(SiteJob),
    Warm(DocText),
    Close(u64),
    StopAll,
    Quit,
}

pub fn spawn(shared: Arc<Shared>) -> Option<Sender<Msg>> {
    let (sender, rx) = channel();
    let worker = Worker {
        launcher: Launcher::new(Arc::clone(&shared)),
        shared,
        rx,
        backlog: VecDeque::new(),
    };
    thread::Builder::new()
        .name("ride-oracle".into())
        .spawn(move || worker.run())
        .ok()?;
    Some(sender)
}

struct Worker {
    shared: Arc<Shared>,
    launcher: Launcher,
    rx: Receiver<Msg>,
    backlog: VecDeque<Msg>,
}

impl Worker {
    fn run(mut self) {
        while let Some(msg) = self.next() {
            match msg {
                Msg::Complete(job) => {
                    if !self.superseded(job.doc.session_id) {
                        self.complete(&job);
                    }
                    self.shared.done(&job.key);
                }
                Msg::Warm(doc) => {
                    if let Some(key) = self.shared.fleet.key_for(&doc) {
                        self.started(&key, doc.session_id);
                    }
                }
                Msg::Close(session_id) => self.shared.fleet.close(session_id),
                Msg::StopAll => self.launcher.reset(),
                Msg::Quit => return,
            }
        }
    }

    fn next(&mut self) -> Option<Msg> {
        self.backlog.pop_front().or_else(|| self.rx.recv().ok())
    }

    fn superseded(&mut self, session: u64) -> bool {
        while let Ok(msg) = self.rx.try_recv() {
            self.backlog.push_back(msg);
        }
        self.backlog.iter().any(|msg| match msg {
            Msg::Complete(next) => next.doc.session_id == session,
            Msg::Close(id) => *id == session,
            Msg::Warm(_) => false,
            Msg::StopAll | Msg::Quit => true,
        })
    }

    fn complete(&mut self, job: &SiteJob) {
        let Some(key) = self.shared.fleet.key_for(&job.doc) else {
            return;
        };
        let Some(sidecar) = self.started(&key, job.doc.session_id) else {
            return;
        };
        let shared = &self.shared;
        let answer = sidecar
            .sync_all(&job.doc, &job.stale, |id, version| {
                shared.mark_synced(id, version)
            })
            .and_then(|()| sidecar.complete(&job.doc, job.key.site, job.shape));
        match answer {
            Ok(hits) if !hits.is_empty() => self.shared.store(job.key, hits),
            Ok(_) => {}
            Err(_) => self.launcher.check_exit(&key),
        }
    }

    fn started(&mut self, key: &Key, session: u64) -> Option<Arc<Sidecar>> {
        match self.launcher.ensure(key) {
            Ok(_) if self.await_ready(key, session) => self.shared.fleet.get(key),
            Ok(_) => None,
            Err(err) => {
                self.shared.board.fail(&err);
                None
            }
        }
    }

    fn await_ready(&mut self, key: &Key, session: u64) -> bool {
        let started = Instant::now();
        loop {
            let Some(sidecar) = self.shared.fleet.get(key) else {
                return false;
            };
            if sidecar.failure().is_some() {
                self.launcher.check_exit(key);
                return false;
            }
            if sidecar.ready() {
                self.launcher.announce(OracleState::Ready, key.0);
                return true;
            }
            self.launcher.announce(OracleState::Starting, key.0);
            if started.elapsed() > LOAD_TIMEOUT || self.superseded(session) {
                return false;
            }
            thread::sleep(POLL);
        }
    }
}
