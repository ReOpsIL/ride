use std::env;
use std::fs;
use std::path::{Path, PathBuf};

use ride_engine::{
    CompletionContext, CompletionQuery, CompletionSiteKind, EngineConfig, ItemKind, QueryMode,
    SystemIncludes, engine_start,
};

const MAIN_C: &str = "#include <stdio.h>\nint main(void) {\n    pri\n    return 0;\n}\n";
const MAIN_CPP: &str =
    "#include <vector>\nint main() {\n    std::vec\n    std::;\n    std::__\n    return 0;\n}\n";

fn clang_on_path() -> bool {
    env::var_os("PATH")
        .is_some_and(|path| env::split_paths(&path).any(|dir| dir.join("clang").is_file()))
}

fn system_header(lang: &str, name: &str) -> Option<PathBuf> {
    SystemIncludes::default()
        .dirs(lang, &[])
        .into_iter()
        .map(|d| d.join(name))
        .find(|p| p.is_file())
}

fn engine(index_dir: &Path) -> std::sync::Arc<ride_engine::Engine> {
    engine_start(EngineConfig {
        index_dir: index_dir.display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
    })
}

fn complete(
    engine: &ride_engine::Engine,
    path: &Path,
    text: &str,
    anchor: &str,
    back: usize,
) -> (CompletionSiteKind, Vec<(String, ItemKind, Option<String>)>) {
    let id = engine
        .open_session(
            "s".into(),
            Some(path.display().to_string()),
            text.into(),
            None,
        )
        .unwrap()
        .session_id;
    let at = text.find(anchor).expect(anchor) + anchor.len() - back;
    let resp = engine.query_completions(CompletionQuery {
        query_id: 1,
        session_id: id,
        prefix: String::new(),
        mode: QueryMode::BufferLocal,
        context: CompletionContext::Unknown,
        cursor_byte: at as u32,
        replace_start_byte: at as u32,
        current_crate: None,
        current_module: None,
        kind_filter: None,
        limit: 20,
    });
    (
        resp.site,
        resp.hits
            .into_iter()
            .map(|h| (h.name, h.item_kind, h.source_path))
            .collect(),
    )
}

#[test]
fn stdio_printf_is_reachable_through_the_probed_system_dirs() {
    if !clang_on_path() || system_header("c", "stdio.h").is_none() {
        eprintln!("skipping: clang or the SDK's stdio.h is not available");
        return;
    }
    let dir = tempfile::tempdir().unwrap();
    let engine = engine(&dir.path().join("index"));
    let (site, hits) = complete(&engine, &dir.path().join("main.c"), MAIN_C, "    pri", 0);
    assert_eq!(site, CompletionSiteKind::Identifier);
    let printf = hits
        .iter()
        .find(|(name, _, _)| name == "printf")
        .unwrap_or_else(|| panic!("printf missing in {hits:?}"));
    assert_eq!(printf.1, ItemKind::Fn);
    let system: Vec<PathBuf> = SystemIncludes::default()
        .dirs("c", &[])
        .into_iter()
        .filter_map(|d| d.canonicalize().ok())
        .collect();
    let under_system = printf
        .2
        .as_deref()
        .and_then(|p| Path::new(p).canonicalize().ok())
        .is_some_and(|p| system.iter().any(|d| p.starts_with(d)));
    assert!(under_system, "{printf:?} not under {system:?}");
}

#[test]
fn std_vector_completes_from_libcxx_and_summaries_persist_on_disk() {
    if !clang_on_path() || system_header("c++", "vector").is_none() {
        eprintln!("skipping: clang or the libc++ vector header is not available");
        return;
    }
    let dir = tempfile::tempdir().unwrap();
    let index_dir = dir.path().join("index");
    let main = dir.path().join("main.cpp");
    fs::write(&main, MAIN_CPP).unwrap();
    let first = engine(&index_dir);
    let (site, hits) = complete(&first, &main, MAIN_CPP, "std::vec", 0);
    assert_eq!(site, CompletionSiteKind::ScopedPath);
    let vector = hits
        .iter()
        .find(|(name, _, _)| name == "vector")
        .unwrap_or_else(|| panic!("vector missing in {hits:?}"));
    assert_eq!(vector.1, ItemKind::Class);
    assert!(
        vector.2.as_deref().is_some_and(|p| p.contains("c++")),
        "{vector:?}"
    );
    let (_, unfiltered) = complete(&first, &main, MAIN_CPP, "std::;", 1);
    assert!(!unfiltered.is_empty());
    assert!(
        unfiltered.iter().all(|(name, _, _)| !name.starts_with('_')),
        "{unfiltered:?}"
    );
    let (_, reserved) = complete(&first, &main, MAIN_CPP, "std::__", 0);
    assert!(
        reserved.iter().all(|(name, _, _)| name.starts_with("__")),
        "{reserved:?}"
    );
    let stored = fs::read_dir(index_dir.join("headers"))
        .unwrap()
        .filter_map(Result::ok)
        .filter(|e| e.path().extension().is_some_and(|x| x == "json"))
        .count();
    assert!(stored > 0);
    drop(first);
    let second = engine(&index_dir);
    let (_, again) = complete(&second, &main, MAIN_CPP, "std::vec", 0);
    assert!(
        again
            .iter()
            .any(|(name, kind, _)| name == "vector" && *kind == ItemKind::Class),
        "{again:?}"
    );
}
