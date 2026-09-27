use std::io::Write;
use std::process::{ChildStdin, Command, Output, Stdio};
use std::thread;

use crate::error::EngineError;

pub fn run_piped(cmd: &mut Command, name: &str, input: &str) -> Result<Output, EngineError> {
    cmd.stdin(Stdio::piped());
    let mut child = cmd.spawn().map_err(|e| tool(name, e))?;
    let stdin = child.stdin.take();
    let (fed, output) = thread::scope(|scope| {
        let writer = scope.spawn(|| feed(stdin, input));
        let output = child.wait_with_output();
        let fed = writer
            .join()
            .unwrap_or_else(|_| Err(std::io::Error::other("stdin writer panicked")));
        (fed, output)
    });
    let output = output.map_err(|e| tool(name, e))?;
    match fed {
        Err(e) if output.status.success() => Err(tool(&format!("{name} stdin"), e)),
        _ => Ok(output),
    }
}

fn feed(stdin: Option<ChildStdin>, input: &str) -> std::io::Result<()> {
    let Some(mut stdin) = stdin else {
        return Ok(());
    };
    stdin.write_all(input.as_bytes())?;
    stdin.flush()
}

fn tool(name: &str, err: std::io::Error) -> EngineError {
    EngineError::Tool {
        message: format!("{name}: {err}"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_child_that_exits_early_reports_its_own_failure() {
        let mut cmd = Command::new("sh");
        cmd.args(["-c", "echo broken >&2; exit 3"])
            .stdout(Stdio::null())
            .stderr(Stdio::piped());
        let input = "x".repeat(4 * 1024 * 1024);
        let output = run_piped(&mut cmd, "sh", &input).expect("output");
        assert_eq!(output.status.code(), Some(3));
        assert_eq!(String::from_utf8_lossy(&output.stderr).trim(), "broken");
    }

    #[test]
    fn a_successful_child_that_ignores_stdin_is_an_error() {
        let mut cmd = Command::new("sh");
        cmd.args(["-c", "exit 0"])
            .stdout(Stdio::null())
            .stderr(Stdio::null());
        let input = "x".repeat(4 * 1024 * 1024);
        let err = run_piped(&mut cmd, "sh", &input).expect_err("unread input");
        assert!(err.to_string().contains("sh stdin"), "{err}");
    }

    #[test]
    fn large_output_and_input_do_not_deadlock() {
        let mut cmd = Command::new("cat");
        cmd.stdout(Stdio::piped()).stderr(Stdio::null());
        let input = "y".repeat(8 * 1024 * 1024);
        let output = run_piped(&mut cmd, "cat", &input).expect("output");
        assert_eq!(output.stdout.len(), input.len());
    }

    #[test]
    fn output_of_a_reading_child_comes_back() {
        let mut cmd = Command::new("cat");
        cmd.stdout(Stdio::piped()).stderr(Stdio::null());
        let output = run_piped(&mut cmd, "cat", "hello").unwrap();
        assert!(output.status.success());
        assert_eq!(String::from_utf8_lossy(&output.stdout), "hello");
    }
}
