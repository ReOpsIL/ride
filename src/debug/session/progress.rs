use std::sync::{Condvar, Mutex};
use std::time::{Duration, Instant};

#[derive(Default)]
pub struct Progress {
    processed: Mutex<u64>,
    signal: Condvar,
}

impl Progress {
    pub fn mark(&self, stamp: u64) {
        if let Ok(mut processed) = self.processed.lock()
            && *processed < stamp
        {
            *processed = stamp;
        }
        self.signal.notify_all();
    }

    pub fn wait(&self, mark: u64, timeout: Duration) -> bool {
        let deadline = Instant::now() + timeout;
        let Ok(mut processed) = self.processed.lock() else {
            return false;
        };
        while *processed < mark {
            let left = deadline.saturating_duration_since(Instant::now());
            if left.is_zero() {
                return false;
            }
            let Ok((next, _)) = self.signal.wait_timeout(processed, left) else {
                return false;
            };
            processed = next;
        }
        true
    }
}
