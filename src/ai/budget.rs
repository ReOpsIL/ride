#[derive(Debug, Clone, Copy)]
pub struct Budget {
    remaining: usize,
}

impl Budget {
    pub fn new(chars: usize) -> Self {
        Self { remaining: chars }
    }

    pub fn take(&mut self, text: &str) -> Option<(String, bool)> {
        if self.remaining == 0 || text.is_empty() {
            return None;
        }
        let (kept, truncated) = clip_lines(text, self.remaining);
        if kept.is_empty() {
            return None;
        }
        self.remaining -= kept.len();
        Some((kept, truncated))
    }

    pub fn remaining(&self) -> usize {
        self.remaining
    }
}

pub fn clip_lines(text: &str, limit: usize) -> (String, bool) {
    if text.len() <= limit {
        return (text.to_string(), false);
    }
    let mut end = 0;
    for line in text.split_inclusive('\n') {
        if end + line.len() > limit {
            break;
        }
        end += line.len();
    }
    (text[..end].to_string(), true)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn clips_on_whole_lines_and_spends_the_budget() {
        let mut budget = Budget::new(12);
        assert_eq!(
            budget.take("aaaa\nbbbb\ncccc\n"),
            Some(("aaaa\nbbbb\n".to_string(), true))
        );
        assert_eq!(budget.remaining(), 2);
        assert_eq!(budget.take("dddd\n"), None);
    }

    #[test]
    fn short_text_is_kept_whole() {
        assert_eq!(clip_lines("x\ny", 10), ("x\ny".to_string(), false));
    }
}
