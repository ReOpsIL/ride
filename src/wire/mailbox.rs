use std::collections::{HashMap, HashSet};
use std::sync::{Condvar, Mutex, MutexGuard};
use std::time::{Duration, Instant};

use serde_json::Value;

#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum MailboxError {
    #[error("timed out")]
    TimedOut,
    #[error("{0}")]
    Failed(String),
    #[error("transport poisoned")]
    Poisoned,
}

#[derive(Default)]
struct Slots {
    responses: HashMap<i64, Value>,
    abandoned: HashSet<i64>,
    failure: Option<String>,
}

#[derive(Default)]
pub struct Mailbox {
    slots: Mutex<Slots>,
    signal: Condvar,
}

impl Mailbox {
    pub fn deliver(&self, id: i64, message: Value) {
        let Ok(mut slots) = self.slots.lock() else {
            return;
        };
        if !slots.abandoned.remove(&id) {
            slots.responses.insert(id, message);
        }
        self.signal.notify_all();
    }

    pub fn fail(&self, reason: &str) {
        let Ok(mut slots) = self.slots.lock() else {
            return;
        };
        slots.failure = Some(reason.to_string());
        self.signal.notify_all();
    }

    pub fn failure(&self) -> Option<String> {
        self.slots.lock().ok().and_then(|s| s.failure.clone())
    }

    pub fn wait(&self, id: i64, timeout: Duration) -> Result<Value, MailboxError> {
        let deadline = Instant::now() + timeout;
        let mut slots = self.lock()?;
        loop {
            if let Some(message) = slots.responses.remove(&id) {
                return Ok(message);
            }
            if let Some(failure) = &slots.failure {
                return Err(MailboxError::Failed(failure.clone()));
            }
            let left = deadline.saturating_duration_since(Instant::now());
            if left.is_zero() {
                slots.abandoned.insert(id);
                return Err(MailboxError::TimedOut);
            }
            slots = self
                .signal
                .wait_timeout(slots, left)
                .map_err(|_| MailboxError::Poisoned)?
                .0;
        }
    }

    fn lock(&self) -> Result<MutexGuard<'_, Slots>, MailboxError> {
        self.slots.lock().map_err(|_| MailboxError::Poisoned)
    }
}

#[cfg(test)]
mod tests {
    use std::sync::Arc;
    use std::thread;

    use serde_json::json;

    use super::*;

    #[test]
    fn a_delivered_response_is_returned_to_its_waiter() {
        let mailbox = Arc::new(Mailbox::default());
        let sender = Arc::clone(&mailbox);
        thread::spawn(move || sender.deliver(7, json!({"ok": true})));
        let got = mailbox.wait(7, Duration::from_secs(5)).expect("response");
        assert_eq!(got, json!({"ok": true}));
    }

    #[test]
    fn a_late_response_after_a_timeout_is_dropped() {
        let mailbox = Mailbox::default();
        assert_eq!(
            mailbox.wait(3, Duration::from_millis(1)),
            Err(MailboxError::TimedOut)
        );
        mailbox.deliver(3, json!(1));
        assert!(mailbox.slots.lock().expect("lock").responses.is_empty());
    }

    #[test]
    fn a_failure_wakes_every_waiter() {
        let mailbox = Mailbox::default();
        mailbox.fail("closed");
        assert_eq!(
            mailbox.wait(1, Duration::from_secs(5)),
            Err(MailboxError::Failed("closed".into()))
        );
    }
}
