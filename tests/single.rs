use std::fs;
use std::path::Path;
use std::process::Command;
use std::sync::Arc;

use ride_engine::{Engine, EngineConfig, engine_start};

fn engine() -> Arc<Engine> {
    let index = tempfile::tempdir().unwrap();
    engine_start(EngineConfig {
        index_dir: index.path().display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
    })
}

fn run(argv: &[String], expected: &str) {
    let output = Command::new(&argv[0]).args(&argv[1..]).output().unwrap();
    assert!(
        output.status.success(),
        "{} failed: {}",
        argv[0],
        String::from_utf8_lossy(&output.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&output.stdout).trim(), expected);
}

fn compile_and_run(name: &str, source: &str, tool: &str) {
    if which(tool).is_none() {
        eprintln!("skipping {name}: {tool} not found");
        return;
    }
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join(name);
    fs::write(&path, source).unwrap();
    let out = dir.path().join("out");
    let single = engine()
        .single_file_command(path.display().to_string(), out.display().to_string())
        .unwrap();
    assert!(single.compile[0].ends_with(tool), "{:?}", single.compile);
    assert!(single.compile.contains(&"-o".to_string()));
    assert_eq!(single.run, vec![single.output.clone()]);
    run(&single.compile, "");
    assert!(Path::new(&single.output).is_file());
    run(&single.run, "hello");
}

fn which(tool: &str) -> Option<std::path::PathBuf> {
    let path = std::env::var_os("PATH")?;
    std::env::split_paths(&path)
        .map(|d| d.join(tool))
        .find(|p| p.is_file())
}

#[test]
fn c_file_compiles_and_runs() {
    compile_and_run(
        "hello.c",
        "#include <stdio.h>\nint main(void){puts(\"hello\");return 0;}\n",
        "clang",
    );
}

#[test]
fn cpp_file_compiles_and_runs() {
    compile_and_run(
        "hello.cpp",
        "#include <iostream>\nint main(){std::cout << \"hello\\n\";}\n",
        "clang++",
    );
}

#[test]
fn rust_file_compiles_and_runs() {
    compile_and_run("hello.rs", "fn main() { println!(\"hello\"); }\n", "rustc");
}

#[test]
fn cpp_command_sets_the_standard() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("a.cc");
    fs::write(&path, "int main(){}\n").unwrap();
    if which("clang++").is_none() {
        eprintln!("skipping: clang++ not found");
        return;
    }
    let single = engine()
        .single_file_command(
            path.display().to_string(),
            dir.path().join("out").display().to_string(),
        )
        .unwrap();
    assert!(single.compile.contains(&"-std=c++20".to_string()));
    assert!(single.output.ends_with("/a"));
}

#[test]
fn unknown_extension_is_an_error() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("notes.txt");
    fs::write(&path, "hello\n").unwrap();
    let err = engine().single_file_command(
        path.display().to_string(),
        dir.path().join("out").display().to_string(),
    );
    assert!(err.is_err());
}

#[test]
fn recompile_command_comes_from_the_database() {
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path().canonicalize().unwrap();
    fs::create_dir_all(root.join("src")).unwrap();
    fs::write(root.join("src/a.c"), "int main(void){return 0;}\n").unwrap();
    let db = format!(
        r#"[{{"directory": "{}", "file": "src/a.c", "command": "cc -I include -c src/a.c -o a.o"}}]"#,
        root.display()
    );
    fs::write(root.join("compile_commands.json"), db).unwrap();
    let command = engine()
        .recompile_command(root.join("src/a.c").display().to_string())
        .unwrap();
    assert_eq!(
        command.argv,
        vec!["cc", "-I", "include", "-c", "src/a.c", "-o", "a.o"]
    );
    assert_eq!(command.directory, root.display().to_string());
    assert!(
        engine()
            .recompile_command(root.join("src/missing.c").display().to_string())
            .is_none()
    );
}

fn copy_tree(src: &Path, dst: &Path) {
    fs::create_dir_all(dst).unwrap();
    for entry in fs::read_dir(src).unwrap() {
        let entry = entry.unwrap();
        let to = dst.join(entry.file_name());
        if entry.file_type().unwrap().is_dir() {
            copy_tree(&entry.path(), &to);
        } else {
            fs::copy(entry.path(), &to).unwrap();
        }
    }
}

#[test]
fn project_source_uses_the_database_flags() {
    if which("clang++").is_none() {
        eprintln!("skipping: clang++ not found");
        return;
    }
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path().join("cpp-demo");
    copy_tree(Path::new("samples/cpp-demo"), &root);
    let source = root.join("src/main.cpp");
    let out = dir.path().join("out");
    let single = engine()
        .single_file_command(source.display().to_string(), out.display().to_string())
        .unwrap();
    let include = root
        .join("include")
        .canonicalize()
        .unwrap()
        .display()
        .to_string();
    assert!(
        single.compile.contains(&format!("-I{include}")),
        "{:?}",
        single.compile
    );
    assert!(
        !single.compile.iter().any(|a| a == "-c"),
        "{:?}",
        single.compile
    );
    assert!(
        !single.compile.iter().any(|a| a.ends_with("main.o")),
        "{:?}",
        single.compile
    );
    let output = Command::new(&single.compile[0])
        .args(&single.compile[1..])
        .output()
        .unwrap();
    assert!(!output.status.success(), "expected a link failure");
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        !stderr.contains("file not found"),
        "include stage failed: {stderr}"
    );
    assert!(
        stderr.contains("Undefined symbols") || stderr.contains("undefined symbol"),
        "{stderr}"
    );
}
