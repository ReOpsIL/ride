use std::fs;
use std::path::Path;

pub fn prune_generations(index_dir: &Path, live: u32) {
    let Ok(entries) = fs::read_dir(index_dir) else {
        return;
    };
    for entry in entries.flatten() {
        let name = entry.file_name();
        let Some(generation) = generation_of(&name.to_string_lossy()) else {
            continue;
        };
        if generation != live && generation + 1 != live {
            let _ = fs::remove_dir_all(entry.path());
        }
    }
}

pub fn clean_stagings(index_dir: &Path) {
    let Ok(entries) = fs::read_dir(index_dir) else {
        return;
    };
    for entry in entries.flatten() {
        let name = entry.file_name();
        if name.to_string_lossy().starts_with("staging-") {
            let _ = fs::remove_dir_all(entry.path());
        }
    }
}

fn generation_of(name: &str) -> Option<u32> {
    name.strip_prefix("gen-")?.parse().ok()
}
