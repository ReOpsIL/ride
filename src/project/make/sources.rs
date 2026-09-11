use std::io::{BufReader, Read};
use std::path::Path;
use std::process::{Child, Stdio};
use std::thread;
use std::time::{Duration, Instant};

use crate::toolchain::tool;

const LIMIT: Duration = Duration::from_secs(2);
const POLL: Duration = Duration::from_millis(20);
const EXTENSIONS: [&str; 3] = [".c", ".cpp", ".cc"];

pub fn of(root: &Path, target: &str) -> Vec<String> {
    let mut out: Vec<String> = Vec::new();
    for token in dry_run(root, target).split_whitespace() {
        let name = token.trim_matches(['"', '\'', '(', ')']);
        if EXTENSIONS.iter().any(|ext| name.ends_with(ext)) && !out.iter().any(|seen| seen == name)
        {
            out.push(name.to_string());
        }
    }
    out
}

fn dry_run(root: &Path, target: &str) -> String {
    let Ok(mut child) = tool("make")
        .arg("-n")
        .arg(target)
        .current_dir(root)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
    else {
        return String::new();
    };
    let Some(stdout) = child.stdout.take() else {
        return String::new();
    };
    let reader = thread::spawn(move || {
        let mut text = String::new();
        let _ = BufReader::new(stdout).read_to_string(&mut text);
        text
    });
    wait_bounded(&mut child);
    reader.join().unwrap_or_default()
}

fn wait_bounded(child: &mut Child) {
    let deadline = Instant::now() + LIMIT;
    loop {
        match child.try_wait() {
            Ok(Some(_)) | Err(_) => return,
            Ok(None) => {}
        }
        if Instant::now() >= deadline {
            let _ = child.kill();
            let _ = child.wait();
            return;
        }
        thread::sleep(POLL);
    }
}
