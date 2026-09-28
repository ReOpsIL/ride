use std::sync::mpsc::{Receiver, Sender, channel};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use ride_engine::{Engine, OracleListener, OracleStatus};

const WAIT: Duration = Duration::from_secs(180);

pub struct Ready {
    rx: Receiver<u64>,
}

impl Ready {
    pub fn enable(engine: &Engine) -> Self {
        let (tx, rx) = channel();
        engine.set_oracle_listener(Arc::new(Forward { tx: Mutex::new(tx) }));
        engine.set_oracle_enabled(true);
        Self { rx }
    }

    pub fn wait(&self, session_id: u64) -> bool {
        while let Ok(id) = self.rx.recv_timeout(WAIT) {
            if id == session_id {
                return true;
            }
        }
        false
    }
}

struct Forward {
    tx: Mutex<Sender<u64>>,
}

impl OracleListener for Forward {
    fn on_members_ready(&self, session_id: u64) {
        if let Ok(tx) = self.tx.lock() {
            let _ = tx.send(session_id);
        }
    }

    fn on_oracle_status(&self, status: OracleStatus) {
        eprintln!(
            "oracle {:?} {}",
            status.state,
            status.message.unwrap_or_default()
        );
    }
}
