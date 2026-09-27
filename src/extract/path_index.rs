use std::collections::HashMap;

use super::item::{ItemDoc, join_path};

pub struct PathIndex<'a> {
    items: HashMap<&'a str, &'a ItemDoc>,
    extra: HashMap<String, usize>,
    synced: usize,
}

impl<'a> PathIndex<'a> {
    pub fn new(items: &'a [ItemDoc]) -> Self {
        let mut map = HashMap::with_capacity(items.len());
        for item in items {
            map.entry(item.path.as_str()).or_insert(item);
        }
        Self {
            items: map,
            extra: HashMap::new(),
            synced: 0,
        }
    }

    pub fn sync(&mut self, extra: &[ItemDoc]) {
        for (n, doc) in extra.iter().enumerate().skip(self.synced) {
            self.extra.entry(doc.path.clone()).or_insert(n);
        }
        self.synced = extra.len();
    }

    pub fn find<'b>(
        &self,
        extra: &'b [ItemDoc],
        module: &[String],
        target: &[String],
    ) -> Option<&'b ItemDoc>
    where
        'a: 'b,
    {
        let paths = candidates(module, target);
        paths
            .iter()
            .find_map(|p| self.items.get(p.as_str()).copied())
            .or_else(|| {
                paths
                    .iter()
                    .find_map(|p| self.extra.get(p).and_then(|&n| extra.get(n)))
            })
    }
}

fn candidates(module: &[String], target: &[String]) -> Vec<String> {
    let joined = target.join("::");
    let mut out = vec![join_path(module, &joined)];
    if let Some(root) = module.first() {
        out.push(format!("{root}::{joined}"));
    }
    out.insert(0, joined);
    out
}
