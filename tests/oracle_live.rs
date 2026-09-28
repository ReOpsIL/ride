use std::fs;
use std::path::Path;
use std::process::Command;
use std::sync::mpsc::{Receiver, Sender, channel};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use ride_engine::{
    CompletionContext, CompletionQuery, CompletionResponse, Engine, EngineConfig, OracleListener,
    OracleState, OracleStatus, QueryMode, engine_start,
};

const SOURCE: &str = "fn main() {\n    let parts: Vec<&str> = probe(\"a.b\");\n    println!(\"{}\", parts.len());\n}\n\nfn probe(s: &str) -> Vec<&str> {\n    s.split('.').co\n}\n";

struct Forward(Mutex<Sender<u64>>);

impl OracleListener for Forward {
    fn on_completions_ready(&self, session_id: u64) {
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

fn write_crate(root: &Path, source: &str) {
    fs::create_dir_all(root.join("src")).expect("src");
    fs::write(
        root.join("Cargo.toml"),
        "[package]\nname = \"oracle-probe\"\nversion = \"0.1.0\"\nedition = \"2021\"\n",
    )
    .expect("manifest");
    fs::write(root.join("src/main.rs"), source).expect("main");
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

struct Probe {
    engine: Arc<Engine>,
    ready: Receiver<u64>,
    session_id: u64,
    text: String,
    next_id: u64,
    _dir: tempfile::TempDir,
}

impl Probe {
    fn open(source: &str) -> Option<Self> {
        if !installed() {
            eprintln!("skipped: rust-analyzer not installed");
            return None;
        }
        let dir = tempfile::tempdir().expect("tempdir");
        write_crate(dir.path(), source);
        let engine = engine_start(EngineConfig {
            index_dir: dir.path().join("index").display().to_string(),
            cargo_home: None,
            sysroot: None,
            offline_metadata: true,
            refs_dir: None,
            report_dir: None,
        });
        let (tx, ready) = channel();
        engine.set_oracle_listener(Arc::new(Forward(Mutex::new(tx))));
        engine.set_oracle_enabled(true);
        let file = dir.path().join("src/main.rs");
        let open = engine
            .open_session(
                "b".into(),
                Some(file.display().to_string()),
                source.into(),
                None,
            )
            .expect("session");
        Some(Self {
            engine,
            ready,
            session_id: open.session_id,
            text: source.to_string(),
            next_id: 0,
            _dir: dir,
        })
    }

    fn at(&mut self, anchor: &str) -> CompletionResponse {
        let cursor = self.text.find(anchor).expect("anchor") + anchor.len();
        self.next_id += 1;
        query(&self.engine, self.session_id, self.next_id, cursor)
    }

    fn answered(&mut self, anchor: &str) -> CompletionResponse {
        self.at(anchor);
        let ready = self
            .ready
            .recv_timeout(Duration::from_secs(120))
            .expect("ready");
        assert_eq!(ready, self.session_id);
        self.at(anchor)
    }
}

#[test]
fn a_split_chain_completes_iterator_methods_once_rust_analyzer_answers() {
    let Some(mut probe) = Probe::open(SOURCE) else {
        return;
    };
    let anchor = "split('.').co";
    assert!(!names(&probe.at(anchor)).contains(&"collect".to_string()));
    let answered = probe.answered(anchor);
    assert_eq!(names(&answered), ["collect", "copied", "count"]);
    let collect = &answered.hits[0];
    assert!(collect.snippet);
    assert_eq!(collect.insert_text, "collect()$0");
    assert_eq!(collect.detail, "Iterator");
    assert_eq!(probe.engine.oracle_status().state, OracleState::Ready);

    probe.engine.set_oracle_enabled(false);
    assert_eq!(probe.engine.oracle_status().state, OracleState::Off);
    assert!(!names(&probe.at(anchor)).contains(&"collect".to_string()));
}

#[test]
fn an_identifier_lists_what_is_in_scope() {
    let source = "use std::collections::HashMap;\n\nfn main() {\n    let total_count = 1;\n    let m: Ha\n    let t = tot\n}\n";
    let Some(mut probe) = Probe::open(source) else {
        return;
    };
    let answered = probe.answered("let m: Ha");
    assert!(
        names(&answered).contains(&"HashMap".to_string()),
        "{:?}",
        names(&answered)
    );
    let local = probe.at("let t = tot");
    assert_eq!(
        names(&local).first().map(String::as_str),
        Some("total_count")
    );
}

#[test]
fn a_type_path_and_a_use_path_list_their_children() {
    let source = "use std::coll\n\nfn main() {\n    let v: Vec<u8> = Vec::with\n}\n";
    let Some(mut probe) = Probe::open(source) else {
        return;
    };
    let path = probe.answered("Vec::with");
    assert!(
        names(&path).contains(&"with_capacity".to_string()),
        "{:?}",
        names(&path)
    );
    let use_path = probe.at("use std::coll");
    let deadline = std::time::Instant::now() + Duration::from_secs(60);
    let mut got = names(&use_path);
    while !got.contains(&"collections".to_string()) && std::time::Instant::now() < deadline {
        let _ = probe.ready.recv_timeout(Duration::from_secs(5));
        got = names(&probe.at("use std::coll"));
    }
    assert!(got.contains(&"collections".to_string()), "{got:?}");
}
