use std::fs;
use std::path::Path;
use std::process::Command;
use std::sync::mpsc::{Receiver, Sender, channel};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use ride_engine::{
    CompletionContext, CompletionQuery, CompletionResponse, Engine, EngineConfig, OracleListener,
    OracleStatus, QueryMode, engine_start,
};

struct Forward(Mutex<Sender<u64>>);

impl OracleListener for Forward {
    fn on_completions_ready(&self, session_id: u64) {
        let _ = self.0.lock().expect("sender").send(session_id);
    }

    fn on_oracle_status(&self, _status: OracleStatus) {}
}

pub fn installed(tool: &str) -> bool {
    let home = std::env::var("HOME").unwrap_or_default();
    [tool.to_string(), format!("{home}/.cargo/bin/{tool}")]
        .iter()
        .any(|p| {
            Command::new(p)
                .arg("--version")
                .output()
                .is_ok_and(|o| o.status.success())
        })
}

pub fn names(resp: &CompletionResponse) -> Vec<String> {
    resp.hits.iter().map(|h| h.name.clone()).collect()
}

pub struct Probe {
    pub engine: Arc<Engine>,
    pub ready: Receiver<u64>,
    pub session_id: u64,
    text: String,
    next_id: u64,
    _dir: tempfile::TempDir,
}

impl Probe {
    pub fn open(tool: &str, files: &[(&str, &str)], main: &str) -> Option<Self> {
        if !installed(tool) {
            eprintln!("skipped: {tool} not installed");
            return None;
        }
        let dir = tempfile::tempdir().expect("tempdir");
        for (path, body) in files {
            write(dir.path(), path, body);
        }
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
        let text = files
            .iter()
            .find(|(path, _)| *path == main)
            .map(|(_, body)| body.to_string())
            .expect("main file");
        let file = dir.path().join(main);
        let open = engine
            .open_session(
                "b".into(),
                Some(file.display().to_string()),
                text.clone(),
                None,
            )
            .expect("session");
        Some(Self {
            engine,
            ready,
            session_id: open.session_id,
            text,
            next_id: 0,
            _dir: dir,
        })
    }

    pub fn at(&mut self, anchor: &str) -> CompletionResponse {
        let cursor = self.text.find(anchor).expect("anchor") + anchor.len();
        self.next_id += 1;
        self.engine.query_completions(CompletionQuery {
            query_id: self.next_id,
            session_id: self.session_id,
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

    pub fn answered(&mut self, anchor: &str) -> CompletionResponse {
        self.at(anchor);
        let ready = self
            .ready
            .recv_timeout(Duration::from_secs(120))
            .expect("ready");
        assert_eq!(ready, self.session_id);
        self.at(anchor)
    }

    pub fn until(&mut self, anchor: &str, wanted: &str) -> Vec<String> {
        let deadline = Instant::now() + Duration::from_secs(120);
        let mut got = names(&self.at(anchor));
        while !got.iter().any(|n| n == wanted) && Instant::now() < deadline {
            let _ = self.ready.recv_timeout(Duration::from_secs(5));
            got = names(&self.at(anchor));
        }
        got
    }
}

fn write(root: &Path, path: &str, body: &str) {
    let file = root.join(path);
    if let Some(parent) = file.parent() {
        fs::create_dir_all(parent).expect("dirs");
    }
    fs::write(file, body).expect("write");
}
