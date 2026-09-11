use std::collections::HashMap;

/// Counts named events.
#[derive(Default)]
pub struct Counter {
    counts: HashMap<String, u32>,
}

/// Records a named event.
pub trait Recorder {
    fn record(&mut self, name: &str);
}

impl Counter {
    /// Creates an empty counter.
    pub fn new() -> Self {
        Self::default()
    }

    /// Adds one occurrence of `name`.
    pub fn record(&mut self, name: &str) {
        *self.counts.entry(name.to_string()).or_insert(0) += 1;
    }

    /// Returns how often `name` was recorded.
    pub fn count(&self, name: &str) -> u32 {
        self.counts.get(name).copied().unwrap_or(0)
    }
}
