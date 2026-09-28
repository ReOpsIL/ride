use std::fs;
use std::path::Path;
use std::process::Command;
use std::sync::mpsc::{Sender, channel};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use ride_engine::{
    CompletionContext, CompletionQuery, CompletionResponse, Engine, EngineConfig, OracleListener,
    OracleState, OracleStatus, QueryMode, engine_start,
};

const SOURCE: &str = "fn main() {\n    let parts: Vec<&str> = probe(\"a.b\");\n    println!(\"{}\", parts.len());\n}\n\nfn probe(s: &str) -> Vec<&str> {\n    s.split('.').co\n}\n";

struct Forward(Mutex<Sender<u64>>);

impl OracleListener for Forward {
    fn on_members_ready(&self, session_id: u64) {
        let _ = self.0.lock().expect("sender").send(session_id);
    }

    fn on_oracle_status(&self, _status: OracleStatus) {}
}

fn installed() -> bool {
    let home = std::env::var("HOME").unwrap_or_default();
    [
        "rust-analyzer".to_string(),
        format!("{home}/.cargo/bin/rust-analyzer"),
    ]
    .iter()
    .any(|p| {
        Command::new(p)
            .arg("--version")
            .output()
            .is_ok_and(|o| o.status.success())
    })
}

fn write_crate(root: &Path) {
    fs::create_dir_all(root.join("src")).expect("src");
    fs::write(
        root.join("Cargo.toml"),
        "[package]\nname = \"oracle-probe\"\nversion = \"0.1.0\"\nedition = \"2021\"\n",
    )
    .expect("manifest");
    fs::write(root.join("src/main.rs"), SOURCE).expect("main");
}

fn query(engine: &Engine, session_id: u64, id: u64, cursor: usize) -> CompletionResponse {
    engine.query_completions(CompletionQuery {
        query_id: id,
        session_id,
        prefix: String::new(),
        mode: QueryMode::BufferLocal,
        context: CompletionContext::Unknown,
        cursor_byte: cursor as u32,
        replace_start_byte: cursor as u32,
        current_crate: None,
        current_module: None,
        kind_filter: None,
        limit: 50,
    })
}

fn names(resp: &CompletionResponse) -> Vec<String> {
    resp.hits.iter().map(|h| h.name.clone()).collect()
}

#[test]
fn a_split_chain_completes_iterator_methods_once_rust_analyzer_answers() {
    if !installed() {
        eprintln!("skipped: rust-analyzer not installed");
        return;
    }
    let dir = tempfile::tempdir().expect("tempdir");
    write_crate(dir.path());
    let file = dir.path().join("src/main.rs");
    let engine = engine_start(EngineConfig {
        index_dir: dir.path().join("index").display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
        refs_dir: None,
        report_dir: None,
    });
    let (tx, rx) = channel();
    engine.set_oracle_listener(Arc::new(Forward(Mutex::new(tx))));
    engine.set_oracle_enabled(true);
    let open = engine
        .open_session(
            "b".into(),
            Some(file.display().to_string()),
            SOURCE.into(),
            None,
        )
        .expect("session");
    let cursor = SOURCE.find("split('.').co").expect("anchor") + "split('.').co".len();

    let first = query(&engine, open.session_id, 1, cursor);
    assert!(
        !names(&first).contains(&"collect".to_string()),
        "{:?}",
        names(&first)
    );

    let ready = rx
        .recv_timeout(Duration::from_secs(120))
        .expect("members ready");
    assert_eq!(ready, open.session_id);
    assert_eq!(engine.oracle_status().state, OracleState::Ready);

    let second = query(&engine, open.session_id, 2, cursor);
    assert_eq!(names(&second), ["collect", "copied", "count"]);
    let collect = &second.hits[0];
    assert!(collect.snippet);
    assert_eq!(collect.insert_text, "collect()$0");
    assert_eq!(collect.detail, "Iterator");

    engine.set_oracle_enabled(false);
    assert_eq!(engine.oracle_status().state, OracleState::Off);
    let off = query(&engine, open.session_id, 3, cursor);
    assert!(!names(&off).contains(&"collect".to_string()));
}
