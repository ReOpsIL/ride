use std::io::Write;
use std::process::{Child, Command, Output, Stdio};

use crate::error::EngineError;

pub fn run_piped(cmd: &mut Command, name: &str, input: &str) -> Result<Output, EngineError> {
    cmd.stdin(Stdio::piped());
    let mut child = cmd.spawn().map_err(|e| tool(name, e))?;
    if let Err(e) = feed(&mut child, input) {
        let _ = child.kill();
        let _ = child.wait();
        return Err(tool(&format!("{name} stdin"), e));
    }
    child.wait_with_output().map_err(|e| tool(name, e))
}

fn feed(child: &mut Child, input: &str) -> std::io::Result<()> {
    let Some(mut stdin) = child.stdin.take() else {
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
    fn closed_stdin_surfaces_as_an_error_and_reaps_the_child() {
        let mut cmd = Command::new("sh");
        cmd.args(["-c", "exit 3"])
            .stdout(Stdio::null())
            .stderr(Stdio::null());
        let input = "x".repeat(4 * 1024 * 1024);
        let err = run_piped(&mut cmd, "sh", &input).expect_err("write must fail");
        assert!(err.to_string().contains("sh stdin"), "{err}");
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
