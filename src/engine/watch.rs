use std::path::{Path, PathBuf};
use std::sync::Weak;
use std::thread;
use std::time::Duration;

use tantivy::Index;

use crate::ffi::IndexState;
use crate::index::{SCHEMA_VERSION, last_status, live_index_dir, read_manifest};

use super::Engine;

const POLL: Duration = Duration::from_millis(250);

struct Tick {
    reopen: bool,
    notify: bool,
    index_dir: PathBuf,
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
        let Ok(tick) = self.write(|i| {
            let index_dir = PathBuf::from(&i.config.index_dir);
            let manifest = read_manifest(&index_dir);
            let disk_status = last_status(&index_dir);
            let mut reopen = false;
            if let Some(m) = &manifest {
                if m.generation != i.generation {
                    i.generation = m.generation;
                    i.overlay.clear();
                    reopen = true;
                }
                if m.schema_version != SCHEMA_VERSION {
                    i.last_status.state = IndexState::Rebuilding;
                    i.last_status.message = Some("Index outdated — rebuilding".into());
                }
            }
            let mut notify = reopen;
            if let Some(mut status) = disk_status {
                if i.workspace.as_ref().is_some_and(|w| w.rust_src_available) {
                    status.rust_src_available = true;
                }
                if status != i.last_status {
                    i.last_status = status;
                    notify = true;
                }
            }
            Tick {
                reopen,
                notify,
                index_dir,
            }
        }) else {
            return;
        };
        if tick.reopen {
            open_reader(self, &tick.index_dir);
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
