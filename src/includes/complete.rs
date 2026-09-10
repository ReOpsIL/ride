use std::collections::HashSet;
use std::path::{Path, PathBuf};

use crate::ffi::{CompletionHit, ItemKind};

use super::framework;
use super::listing;
use super::rank::{self, Tier};
use super::request::IncludeRequest;

struct Root<'a> {
    dir: &'a Path,
    tier: Tier,
}

struct Collector<'a> {
    sub_dir: &'a str,
    prefix: &'a str,
    seen: HashSet<String>,
    hits: Vec<CompletionHit>,
}

pub fn complete(req: &IncludeRequest<'_>) -> Vec<CompletionHit> {
    let (sub_dir, prefix) = req.split_typed();
    let mut collector = Collector {
        sub_dir,
        prefix,
        seen: HashSet::new(),
        hits: Vec::new(),
    };
    for root in roots(req) {
        match root.tier {
            Tier::Framework => collector.framework(&root),
            _ => collector.plain(&root, root.dir.join(sub_dir)),
        }
    }
    collector.finish(req.limit)
}

fn roots<'a>(req: &IncludeRequest<'a>) -> Vec<Root<'a>> {
    let mut out = Vec::new();
    if req.quoted
        && let Some(dir) = req.file.and_then(Path::parent)
    {
        out.push(Root {
            dir,
            tier: Tier::Project,
        });
    }
    out.extend(req.search_dirs.iter().map(|dir| Root {
        dir,
        tier: Tier::SearchDir,
    }));
    out.extend(req.system_dirs.iter().map(|(dir, is_framework)| Root {
        dir,
        tier: if *is_framework {
            Tier::Framework
        } else {
            Tier::System
        },
    }));
    out
}

impl Collector<'_> {
    fn plain(&mut self, root: &Root<'_>, dir: PathBuf) {
        let Some(entries) = listing::list(&dir) else {
            return;
        };
        for entry in entries.iter() {
            self.push(root, &entry.name, entry.is_dir, || entry.path.clone());
        }
    }

    fn framework(&mut self, root: &Root<'_>) {
        match framework::headers_dir(root.dir, self.sub_dir) {
            Some(dir) => self.plain(root, dir),
            None => self.framework_top(root),
        }
    }

    fn framework_top(&mut self, root: &Root<'_>) {
        let Some(entries) = listing::list(root.dir) else {
            return;
        };
        for entry in entries.iter() {
            if let Some(name) = framework::name_of(entry) {
                self.push(root, name, true, || framework::headers_of(entry));
            }
        }
    }

    fn push(&mut self, root: &Root<'_>, name: &str, is_dir: bool, path: impl FnOnce() -> PathBuf) {
        if !rank::matches(name, self.prefix) || self.seen.contains(name) {
            return;
        }
        self.seen.insert(name.to_string());
        let label = if is_dir {
            format!("{name}/")
        } else {
            name.to_string()
        };
        let kind = if is_dir {
            ItemKind::Mod
        } else {
            ItemKind::Header
        };
        let score = rank::score(root.tier, name, is_dir, self.prefix);
        let mut hit = CompletionHit::local(&label, kind, score, None);
        hit.path = if self.sub_dir.is_empty() {
            label
        } else {
            format!("{}/{label}", self.sub_dir)
        };
        hit.signature = root.dir.display().to_string();
        hit.source_path = Some(path().display().to_string());
        self.hits.push(hit);
    }

    fn finish(mut self, limit: usize) -> Vec<CompletionHit> {
        self.hits.sort_by(|a, b| {
            b.score
                .total_cmp(&a.score)
                .then_with(|| a.name.cmp(&b.name))
        });
        self.hits.truncate(limit);
        self.hits
    }
}
