use std::collections::HashMap;

use super::item::{ItemDoc, Visibility};

#[derive(Default)]
pub struct External {
    by_path: HashMap<String, ItemDoc>,
}

impl External {
    pub fn absorb(&mut self, items: &[ItemDoc]) {
        for item in items.iter().filter(|i| i.visibility == Visibility::Pub) {
            self.by_path
                .entry(item.path.clone())
                .or_insert_with(|| item.clone());
        }
    }

    pub fn get(&self, path: &str) -> Option<&ItemDoc> {
        self.by_path.get(path)
    }

    pub fn len(&self) -> usize {
        self.by_path.len()
    }

    pub fn is_empty(&self) -> bool {
        self.by_path.is_empty()
    }
}
