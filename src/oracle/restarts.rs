use std::collections::HashMap;
use std::hash::Hash;
use std::time::{Duration, Instant};

const WINDOW: Duration = Duration::from_secs(300);
const LIMIT: usize = 3;

pub struct Restarts<K> {
    exits: HashMap<K, Vec<Instant>>,
}

impl<K> Default for Restarts<K> {
    fn default() -> Self {
        Self {
            exits: HashMap::new(),
        }
    }
}

impl<K: Eq + Hash + Clone> Restarts<K> {
    pub fn record(&mut self, key: &K) {
        self.exits
            .entry(key.clone())
            .or_default()
            .push(Instant::now());
    }

    pub fn exhausted(&mut self, key: &K) -> bool {
        let Some(exits) = self.exits.get_mut(key) else {
            return false;
        };
        exits.retain(|at| at.elapsed() < WINDOW);
        exits.len() >= LIMIT
    }

    pub fn clear(&mut self) {
        self.exits.clear();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn three_exits_in_the_window_stop_restarts() {
        let mut restarts = Restarts::default();
        let key = "root".to_string();
        for _ in 0..LIMIT {
            assert!(!restarts.exhausted(&key));
            restarts.record(&key);
        }
        assert!(restarts.exhausted(&key));
    }
}
