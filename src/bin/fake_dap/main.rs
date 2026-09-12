mod data;
mod script;

use std::io::{self, BufRead, BufReader, Write};

use serde_json::Value;

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    announce_pid(&args);
    let stdin = io::stdin();
    let mut reader = BufReader::new(stdin.lock());
    let mut out = io::stdout();
    let mut state = script::State::from_args(&args);
    while let Ok(Some(message)) = read_frame(&mut reader) {
        let command = message
            .get("command")
            .and_then(Value::as_str)
            .unwrap_or("")
            .to_string();
        if command == "truncate" {
            let _ = out.write_all(b"Content-Length: 4096\r\n\r\n{\"type\":\"resp");
            let _ = out.flush();
            return;
        }
        let (messages, stop) = script::reply(&mut state, &command, &message);
        for message in messages {
            let response = message.get("type").and_then(Value::as_str) == Some("response");
            write_frame(&mut out, &message, response);
        }
        if stop {
            return;
        }
    }
}

fn announce_pid(args: &[String]) {
    let Some(index) = args.iter().position(|arg| arg == script::PID_FILE) else {
        return;
    };
    let Some(path) = args.get(index + 1) else {
        return;
    };
    let _ = std::fs::write(path, std::process::id().to_string());
}

fn write_frame(out: &mut impl Write, message: &Value, extra_headers: bool) {
    let Ok(body) = serde_json::to_vec(message) else {
        return;
    };
    let header = if extra_headers {
        format!(
            "Content-Length: {}\r\nContent-Type: application/vnd.dap+json; charset=utf-8\r\n\r\n",
            body.len()
        )
    } else {
        format!("content-length: {}\n\n", body.len())
    };
    let _ = out.write_all(header.as_bytes());
    let _ = out.write_all(&body);
    let _ = out.flush();
}

fn read_frame<R: BufRead>(reader: &mut R) -> io::Result<Option<Value>> {
    let mut length: Option<usize> = None;
    loop {
        let mut line = String::new();
        if reader.read_line(&mut line)? == 0 {
            return Ok(None);
        }
        let header = line.trim_end_matches(['\r', '\n']);
        if header.is_empty() {
            break;
        }
        if let Some((name, value)) = header.split_once(':')
            && name.trim().eq_ignore_ascii_case("content-length")
        {
            length = value.trim().parse::<usize>().ok();
        }
    }
    let Some(length) = length else {
        return Ok(None);
    };
    let mut body = vec![0u8; length];
    reader.read_exact(&mut body)?;
    Ok(serde_json::from_slice(&body).ok())
}
