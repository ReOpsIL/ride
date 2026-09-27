use std::path::{Path, PathBuf};
use std::sync::Weak;
use std::thread;
use std::time::Duration;

use tantivy::Index;

use crate::ffi::{IndexState, IndexStatus};
use crate::index::{
    Manifest, SCHEMA_VERSION, last_status, live_index_dir, prune_generations, read_manifest,
};

use super::index_watch::DiskStamp;
use super::{Engine, Inner};

const POLL: Duration = Duration::from_millis(250);

struct Tick {
    reopen: Option<u32>,
    changed: bool,
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
        let stamp = DiskStamp::of(&index_dir);
        if self.read(|i| i.watch.unchanged(&stamp)).unwrap_or(false) {
            return;
        }
        let manifest = read_manifest(&index_dir);
        let disk_status = last_status(&index_dir);
        let Ok(tick) = self.write(|i| apply(i, manifest.as_ref(), disk_status)) else {
            return;
        };
        let reopened = tick
            .reopen
            .is_some_and(|generation| open_reader(self, &index_dir, generation));
        if tick.reopen.is_none() || reopened {
            let _ = self.write(|i| i.watch.settle(stamp));
        }
        if tick.changed || reopened {
            self.notify();
        }
    }

    fn notify(&self) {
        let Ok((status, listener)) = self.read(|i| (i.last_status.clone(), i.listener.clone()))
        else {
            return;
        };
        if let Some(listener) = listener {
            listener.on_status(status);
        }
    }
}

fn apply(i: &mut Inner, manifest: Option<&Manifest>, disk_status: Option<IndexStatus>) -> Tick {
    let reopen = manifest
        .map(|m| m.generation)
        .filter(|generation| i.watch.wants(*generation));
    let mut status = disk_status.unwrap_or_else(|| i.last_status.clone());
    if i.workspace
        .as_ref()
        .is_some_and(|w| w.info.rust_src_available)
    {
        status.rust_src_available = true;
    }
    if manifest.is_some_and(|m| m.schema_version != SCHEMA_VERSION) {
        status.state = IndexState::Rebuilding;
        status.message = Some("Index outdated — rebuilding".into());
    }
    let changed = status != i.last_status;
    i.last_status = status;
    Tick { reopen, changed }
}

fn open_reader(engine: &Engine, index_dir: &Path, generation: u32) -> bool {
    let Some(live) = live_index_dir(index_dir) else {
        return false;
    };
    let Ok(index) = Index::open_in_dir(live) else {
        return false;
    };
    let Ok(reader) = index.reader() else {
        return false;
    };
    let _ = engine.write(|i| {
        i.index = Some(index);
        i.reader = Some(reader);
        i.overlay.clear();
        i.watch.opened(generation);
    });
    prune_generations(index_dir, generation);
    true
}
