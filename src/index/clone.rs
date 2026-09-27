use std::fs;
use std::io;
use std::path::Path;

use crate::error::EngineError;

pub fn clone_generation(from: &Path, to: &Path) -> Result<(), EngineError> {
    if to.exists() {
        fs::remove_dir_all(to).map_err(|e| EngineError::io(to, e))?;
    }
    fs::create_dir_all(to).map_err(|e| EngineError::io(to, e))?;
    let entries = fs::read_dir(from).map_err(|e| EngineError::io(from, e))?;
    for entry in entries.flatten() {
        let src = entry.path();
        let dest = to.join(entry.file_name());
        let name = entry.file_name();
        let name = name.to_string_lossy();
        if name.ends_with(".lock") {
            continue;
        }
        let cloned = if entry.file_type().is_ok_and(|t| t.is_dir()) {
            clone_generation(&src, &dest)
        } else {
            clone_file(&src, &dest, rewritten(&name)).map_err(|e| EngineError::io(&src, e))
        };
        cloned?;
    }
    Ok(())
}

fn rewritten(name: &str) -> bool {
    name.ends_with(".json")
}

fn clone_file(src: &Path, dest: &Path, rewritten: bool) -> io::Result<()> {
    if !rewritten && fs::hard_link(src, dest).is_ok() {
        return Ok(());
    }
    fs::copy(src, dest).map(|_| ())
}
