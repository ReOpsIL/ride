use std::path::{Path, PathBuf};
use std::sync::Weak;
use std::thread;
use std::time::Duration;

use tantivy::Index;

use crate::ffi::{IndexState, IndexStatus};
use crate::index::{
    Manifest, SCHEMA_VERSION, last_status, live_index_dir, prune_generations, read_manifest,
};

use super::{Engine, Inner};

const POLL: Duration = Duration::from_millis(250);

struct Tick {
    reopen: bool,
    notify: bool,
    generation: u32,
}

pub fn spawn(engine: Weak<Engine>) {
    thread::Builder::new()
        .name("ride-index-watch".into())
        .spawn(move || {
            while let Some(engine) = engine.upgrade() {
                engine.poll_index();
                drop(engine);
                thread::sleep(POLL);
            }
        })
        .ok();
}

impl Engine {
    pub(crate) fn poll_index(&self) {
        let Ok(index_dir) = self.read(|i| PathBuf::from(&i.config.index_dir)) else {
            return;
        };
        let manifest = read_manifest(&index_dir);
        let disk_status = last_status(&index_dir);
        let Ok(tick) = self.write(|i| apply(i, manifest.as_ref(), disk_status)) else {
            return;
        };
        if tick.reopen {
            open_reader(self, &index_dir);
            prune_generations(&index_dir, tick.generation);
        }
        if tick.notify {
            let Ok((status, listener)) = self.read(|i| (i.last_status.clone(), i.listener.clone()))
            else {
                return;
            };
            if let Some(listener) = listener {
                listener.on_status(status);
            }
        }
    }
}

fn apply(i: &mut Inner, manifest: Option<&Manifest>, disk_status: Option<IndexStatus>) -> Tick {
    let reopen = manifest.is_some_and(|m| m.generation != i.generation);
    if let Some(m) = manifest.filter(|_| reopen) {
        i.generation = m.generation;
        i.overlay.clear();
    }
    let mut status = disk_status.unwrap_or_else(|| i.last_status.clone());
    if i.workspace.as_ref().is_some_and(|w| w.rust_src_available) {
        status.rust_src_available = true;
    }
    if manifest.is_some_and(|m| m.schema_version != SCHEMA_VERSION) {
        status.state = IndexState::Rebuilding;
        status.message = Some("Index outdated — rebuilding".into());
    }
    let notify = reopen || status != i.last_status;
    i.last_status = status;
    Tick {
        reopen,
        notify,
        generation: i.generation,
    }
}

fn open_reader(engine: &Engine, index_dir: &Path) {
    let Some(live) = live_index_dir(index_dir) else {
        return;
    };
    let Ok(index) = Index::open_in_dir(live) else {
        return;
    };
    let Ok(reader) = index.reader() else {
        return;
    };
    let _ = engine.write(|i| {
        i.index = Some(index);
        i.reader = Some(reader);
    });
}
