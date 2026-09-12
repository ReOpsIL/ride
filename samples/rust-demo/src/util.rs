use std::collections::HashMap;

/// Counts named events.
#[derive(Default)]
pub struct Counter {
    counts: HashMap<String, u32>,
}

pub trait Recorder {
    fn record(&mut self, name: &str);
}

impl Recorder for Counter {
    fn record(&mut self, name: &str) {
        *self.counts.entry(name.to_string()).or_insert(0) += 1;
    }
}

impl Counter {
    /// Creates an empty counter.
    pub fn new() -> Self {
        Self::default()
    }

    /// Returns how often `name` was recorded.
    pub fn count(&self, name: &str) -> u32 {
        self.counts.get(name).copied().unwrap_or(0)
    }
}

#[test]
fn counts_one() {
    let mut counter = Counter::new();
    counter.record("ride");
    assert_eq!(counter.count("ride"), 1);
}
