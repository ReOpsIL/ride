use std::fs;
use std::path::Path;
use std::time::SystemTime;

type Stamp = Option<(SystemTime, u64)>;

#[derive(Clone, Copy, PartialEq, Eq)]
pub struct DiskStamp {
    manifest: Stamp,
    status: Stamp,
}

impl DiskStamp {
    pub fn of(index_dir: &Path) -> Self {
        Self {
            manifest: stamp(&index_dir.join("manifest.json")),
            status: stamp(&index_dir.join("status.jsonl")),
        }
    }
}

fn stamp(path: &Path) -> Stamp {
    let meta = fs::metadata(path).ok()?;
    Some((meta.modified().ok()?, meta.len()))
}

#[derive(Default)]
pub struct IndexWatch {
    generation: Option<u32>,
    seen: Option<DiskStamp>,
}

impl IndexWatch {
    pub fn unchanged(&self, stamp: &DiskStamp) -> bool {
        self.seen.as_ref() == Some(stamp)
    }

    pub fn wants(&self, generation: u32) -> bool {
        self.generation != Some(generation)
    }

    pub fn opened(&mut self, generation: u32) {
        self.generation = Some(generation);
    }

    pub fn settle(&mut self, stamp: DiskStamp) {
        self.seen = Some(stamp);
    }

    pub fn invalidate(&mut self) {
        self.seen = None;
    }
}
