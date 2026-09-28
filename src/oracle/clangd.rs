use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
use std::path::{Path, PathBuf};

use serde_json::{Value, json};

use crate::highlight::Lang;

pub fn database_dir(cache: &Path, root: &Path) -> Option<PathBuf> {
    let mut hasher = DefaultHasher::new();
    root.hash(&mut hasher);
    let dir = cache
        .join("clangd")
        .join(format!("{:016x}", hasher.finish()));
    std::fs::create_dir_all(&dir).ok()?;
    let entries = Value::Array(crate::check::normalized(root));
    std::fs::write(dir.join("compile_commands.json"), entries.to_string()).ok()?;
    Some(dir)
}

pub fn compile_settings(path: &Path, lang: Lang) -> Option<Value> {
    if crate::check::project_root(path).is_some() {
        return None;
    }
    let invocation = crate::check::invocation(path, lang)?;
    let file = path.display().to_string();
    let mut command = vec!["clang".to_string()];
    command.extend(invocation.args);
    command.push(file.clone());
    Some(json!({
        "settings": {
            "compilationDatabaseChanges": {
                file: {
                    "workingDirectory": invocation.directory,
                    "compilationCommand": command
                }
            }
        }
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_file_under_a_database_is_left_to_it() {
        let dir = tempfile::tempdir().expect("tempdir");
        let file = dir.path().join("a.cpp");
        std::fs::write(&file, "int main() {}\n").expect("write");
        std::fs::write(dir.path().join("compile_commands.json"), "[]").expect("db");
        assert_eq!(compile_settings(&file, Lang::Cpp), None);
    }

    #[test]
    fn a_file_without_a_database_gets_the_default_flags() {
        let dir = tempfile::tempdir().expect("tempdir");
        let file = dir.path().join("a.cpp");
        std::fs::write(&file, "int main() {}\n").expect("write");
        let settings = compile_settings(&file, Lang::Cpp).expect("settings");
        let key = file.display().to_string();
        let command =
            &settings["settings"]["compilationDatabaseChanges"][&key]["compilationCommand"];
        let args: Vec<&str> = command
            .as_array()
            .expect("array")
            .iter()
            .filter_map(Value::as_str)
            .collect();
        assert_eq!(args.first(), Some(&"clang"));
        assert!(args.contains(&"c++"));
        assert_eq!(args.last(), Some(&key.as_str()));
    }
}
