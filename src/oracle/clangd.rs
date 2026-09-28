use std::path::Path;

use serde_json::{Value, json};

use crate::highlight::Lang;

pub fn compile_settings(path: &Path, lang: Lang) -> Option<Value> {
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
