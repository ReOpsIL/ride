use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct SiteKey {
    pub session_id: u64,
    pub site: usize,
    before: u64,
}

impl SiteKey {
    pub fn new(session_id: u64, text: &str, site: usize) -> Option<Self> {
        let mut hasher = DefaultHasher::new();
        text.get(..site)?.hash(&mut hasher);
        Some(Self {
            session_id,
            site,
            before: hasher.finish(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn typing_after_the_dot_keeps_the_key() {
        let a = SiteKey::new(1, "s.split('.').", 13);
        let b = SiteKey::new(1, "s.split('.').co", 13);
        assert_eq!(a, b);
    }

    #[test]
    fn an_edit_before_the_dot_changes_the_key() {
        let a = SiteKey::new(1, "s.split('.').", 13);
        let b = SiteKey::new(1, "t.split('.').", 13);
        assert_ne!(a, b);
    }

    #[test]
    fn a_site_off_a_char_boundary_has_no_key() {
        assert_eq!(SiteKey::new(1, "é", 1), None);
    }
}
