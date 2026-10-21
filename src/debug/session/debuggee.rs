use std::sync::atomic::{AtomicBool, Ordering};

#[derive(Default)]
pub struct Debuggee {
    present: AtomicBool,
}

impl Debuggee {
    pub fn mark(&self) {
        self.present.store(true, Ordering::SeqCst);
    }

    pub fn present(&self) -> bool {
        self.present.load(Ordering::SeqCst)
    }
}
