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
        if generation + 1 < live {
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

#[cfg(test)]
mod tests {
    use super::prune_generations;

    #[test]
    fn pruning_keeps_the_live_generation_its_predecessor_and_anything_newer() {
        let Ok(dir) = tempfile::tempdir() else {
            return;
        };
        for generation in 1..=5 {
            let _ = std::fs::create_dir(dir.path().join(format!("gen-{generation}")));
        }
        prune_generations(dir.path(), 3);
        let mut left: Vec<String> = std::fs::read_dir(dir.path())
            .into_iter()
            .flatten()
            .flatten()
            .map(|e| e.file_name().to_string_lossy().into_owned())
            .collect();
        left.sort();
        assert_eq!(left, ["gen-2", "gen-3", "gen-4", "gen-5"]);
    }
}
