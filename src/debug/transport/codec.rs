use std::io::{BufRead, Read, Write};

use serde_json::Value;

use crate::error::EngineError;

const MAX_BODY: usize = 64 * 1024 * 1024;
const MAX_HEADER_LINE: u64 = 1024;

pub fn read_frame<R: BufRead>(reader: &mut R) -> Result<Option<Value>, EngineError> {
    let Some(length) = read_headers(reader)? else {
        return Ok(None);
    };
    let mut body = vec![0u8; length];
    reader
        .read_exact(&mut body)
        .map_err(|err| EngineError::debug(format!("truncated frame: {err}")))?;
    serde_json::from_slice(&body).map_err(|err| EngineError::debug(format!("frame json: {err}")))
}

pub fn write_frame<W: Write>(writer: &mut W, message: &Value) -> Result<(), EngineError> {
    let body =
        serde_json::to_vec(message).map_err(|err| EngineError::debug(format!("encode: {err}")))?;
    let header = format!("Content-Length: {}\r\n\r\n", body.len());
    writer
        .write_all(header.as_bytes())
        .and_then(|()| writer.write_all(&body))
        .and_then(|()| writer.flush())
        .map_err(|err| EngineError::debug(format!("write: {err}")))
}

fn read_headers<R: BufRead>(reader: &mut R) -> Result<Option<usize>, EngineError> {
    let mut length: Option<usize> = None;
    loop {
        let Some(line) = header_line(reader)? else {
            return match length {
                Some(_) => Err(EngineError::debug("truncated header")),
                None => Ok(None),
            };
        };
        let header = line.trim_end_matches(['\r', '\n']);
        if header.is_empty() {
            return length
                .map(Some)
                .ok_or_else(|| EngineError::debug("frame without content length"));
        }
        if let Some((name, value)) = header.split_once(':')
            && name.trim().eq_ignore_ascii_case("content-length")
        {
            length = Some(content_length(value)?);
        }
    }
}

fn header_line<R: BufRead>(reader: &mut R) -> Result<Option<String>, EngineError> {
    let mut line = String::new();
    let read = reader
        .by_ref()
        .take(MAX_HEADER_LINE)
        .read_line(&mut line)
        .map_err(|err| EngineError::debug(format!("read header: {err}")))?;
    if read == 0 {
        return Ok(None);
    }
    if !line.ends_with('\n') && read as u64 == MAX_HEADER_LINE {
        return Err(EngineError::debug("header line too long"));
    }
    Ok(Some(line))
}

fn content_length(value: &str) -> Result<usize, EngineError> {
    let length = value
        .trim()
        .parse::<usize>()
        .map_err(|err| EngineError::debug(format!("content length: {err}")))?;
    if length > MAX_BODY {
        return Err(EngineError::debug(format!(
            "content length {length} exceeds {MAX_BODY} bytes"
        )));
    }
    Ok(length)
}

#[cfg(test)]
mod tests {
    use std::io::Cursor;

    use super::*;

    #[test]
    fn an_oversized_content_length_is_refused_before_allocating() {
        let mut input = Cursor::new(b"Content-Length: 99999999999\r\n\r\n".to_vec());
        let err = read_frame(&mut input).expect_err("oversized");
        assert!(err.to_string().contains("exceeds"), "{err}");
    }

    #[test]
    fn an_endless_header_line_is_refused() {
        let mut input = Cursor::new(vec![b'x'; 10_000]);
        let err = read_frame(&mut input).expect_err("endless header");
        assert!(err.to_string().contains("too long"), "{err}");
    }

    #[test]
    fn a_written_frame_reads_back() {
        let mut wire = Vec::new();
        write_frame(&mut wire, &serde_json::json!({"seq": 1})).expect("write");
        let back = read_frame(&mut Cursor::new(wire)).expect("read");
        assert_eq!(back, Some(serde_json::json!({"seq": 1})));
    }
}
