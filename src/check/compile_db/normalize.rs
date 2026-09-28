use std::path::{Path, PathBuf};

use serde_json::{Value, json};

use super::{Entry, databases_in};

pub fn normalized(root: &Path) -> Vec<Value> {
    let root = root.canonicalize().unwrap_or_else(|_| root.to_path_buf());
    databases_in(&root)
        .find_map(|db| entries(&db))
        .unwrap_or_default()
}

fn entries(db: &Path) -> Option<Vec<Value>> {
    let text = std::fs::read_to_string(db).ok()?;
    let entries: Vec<Entry> = serde_json::from_str(&text).ok()?;
    let base = db.parent().unwrap_or(Path::new("."));
    let out: Vec<Value> = entries
        .iter()
        .filter_map(|entry| {
            let directory = real(base.join(&entry.directory));
            let file = real(directory.join(&entry.file));
            Some(json!({
                "directory": directory,
                "file": file,
                "arguments": entry.argv()?,
            }))
        })
        .collect();
    (!out.is_empty()).then_some(out)
}

fn real(path: PathBuf) -> PathBuf {
    path.canonicalize().unwrap_or(path)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn relative_directories_become_absolute() {
        let dir = tempfile::tempdir().expect("tempdir");
        let root = dir.path().canonicalize().expect("root");
        std::fs::create_dir_all(root.join("build")).expect("build");
        std::fs::create_dir_all(root.join("src")).expect("src");
        std::fs::write(root.join("src/main.cpp"), "int main() {}\n").expect("main");
        std::fs::write(
            root.join("build/compile_commands.json"),
            r#"[{"directory": "..", "file": "src/main.cpp", "command": "clang++ -Iinclude -c src/main.cpp"}]"#,
        )
        .expect("db");
        let got = normalized(&root);
        assert_eq!(got.len(), 1);
        assert_eq!(got[0]["directory"], json!(root));
        assert_eq!(got[0]["file"], json!(root.join("src/main.cpp")));
        assert_eq!(got[0]["arguments"][0], json!("clang++"));
    }
}
