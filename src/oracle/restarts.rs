use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

const WINDOW: Duration = Duration::from_secs(300);
const LIMIT: usize = 3;

#[derive(Default)]
pub struct Restarts {
    exits: HashMap<PathBuf, Vec<Instant>>,
}

impl Restarts {
    pub fn record(&mut self, root: &Path) {
        self.exits
            .entry(root.to_path_buf())
            .or_default()
            .push(Instant::now());
    }

    pub fn exhausted(&mut self, root: &Path) -> bool {
        let Some(exits) = self.exits.get_mut(root) else {
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
        let root = Path::new("/r");
        for _ in 0..LIMIT {
            assert!(!restarts.exhausted(root));
            restarts.record(root);
        }
        assert!(restarts.exhausted(root));
    }
}
