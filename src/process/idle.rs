use std::io::Read;
use std::os::unix::process::CommandExt;
use std::process::{Child, ChildStderr, ChildStdout, Command, Output, Stdio};
use std::sync::mpsc::{self, Receiver, Sender};
use std::thread;
use std::time::Duration;

#[derive(Debug)]
pub enum IdleError {
    Io(std::io::Error),
    TimedOut,
}

enum Chunk {
    Out(Vec<u8>),
    Err(Vec<u8>),
}

pub fn output_idle(cmd: &mut Command, idle: Duration) -> Result<Output, IdleError> {
    let mut child = spawn(cmd)?;
    let (tx, rx) = mpsc::channel();
    drain(child.stdout.take(), child.stderr.take(), tx);
    collect(&mut child, rx, idle)
}

fn spawn(cmd: &mut Command) -> Result<Child, IdleError> {
    cmd.stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .process_group(0)
        .spawn()
        .map_err(IdleError::Io)
}

fn drain(stdout: Option<ChildStdout>, stderr: Option<ChildStderr>, tx: Sender<Chunk>) {
    let err_tx = tx.clone();
    thread::spawn(move || pump(stdout, tx, Chunk::Out));
    thread::spawn(move || pump(stderr, err_tx, Chunk::Err));
}

fn pump(pipe: Option<impl Read>, tx: Sender<Chunk>, wrap: fn(Vec<u8>) -> Chunk) {
    let Some(mut pipe) = pipe else {
        return;
    };
    let mut buf = [0u8; 8192];
    loop {
        match pipe.read(&mut buf) {
            Ok(0) | Err(_) => break,
            Ok(n) => {
                if tx.send(wrap(buf[..n].to_vec())).is_err() {
                    break;
                }
            }
        }
    }
}

fn collect(child: &mut Child, rx: Receiver<Chunk>, idle: Duration) -> Result<Output, IdleError> {
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    loop {
        match rx.recv_timeout(idle) {
            Ok(Chunk::Out(bytes)) => stdout.extend(bytes),
            Ok(Chunk::Err(bytes)) => stderr.extend(bytes),
            Err(mpsc::RecvTimeoutError::Timeout) => {
                stop(child);
                return Err(IdleError::TimedOut);
            }
            Err(mpsc::RecvTimeoutError::Disconnected) => {
                let status = child.wait().map_err(IdleError::Io)?;
                return Ok(Output {
                    status,
                    stdout,
                    stderr,
                });
            }
        }
    }
}

fn stop(child: &mut Child) {
    let pid = child.id();
    let _ = Command::new("/bin/kill")
        .args(["-KILL", &format!("-{pid}")])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
    let _ = child.kill();
    let _ = child.wait();
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sh(script: &str) -> Command {
        let mut cmd = Command::new("sh");
        cmd.args(["-c", script]);
        cmd
    }

    #[test]
    fn a_silent_child_stops_at_the_idle_bound() {
        let started = std::time::Instant::now();
        let err = output_idle(&mut sh("sleep 30"), Duration::from_millis(200)).unwrap_err();
        assert!(matches!(err, IdleError::TimedOut));
        assert!(started.elapsed() < Duration::from_secs(3));
    }

    #[test]
    fn output_resets_the_idle_bound() {
        let output = output_idle(
            &mut sh("printf a; sleep 0.25; printf b; sleep 0.25; printf c"),
            Duration::from_millis(500),
        )
        .unwrap();
        assert!(output.status.success());
        assert_eq!(output.stdout, b"abc");
    }

    #[test]
    fn a_quiet_success_returns_its_status() {
        let output = output_idle(&mut sh("exit 0"), Duration::from_millis(500)).unwrap();
        assert!(output.status.success());
        assert!(output.stdout.is_empty());
    }
}
