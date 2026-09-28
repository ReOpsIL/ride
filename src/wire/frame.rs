use std::io::{BufRead, Read, Write};

use serde_json::Value;

const MAX_BODY: usize = 64 * 1024 * 1024;
const MAX_HEADER_LINE: u64 = 1024;

#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum FrameError {
    #[error("truncated frame: {0}")]
    Truncated(String),
    #[error("truncated header")]
    TruncatedHeader,
    #[error("frame without content length")]
    MissingLength,
    #[error("header line too long")]
    HeaderTooLong,
    #[error("content length: {0}")]
    BadLength(String),
    #[error("content length {0} exceeds {MAX_BODY} bytes")]
    Oversized(usize),
    #[error("frame json: {0}")]
    Json(String),
    #[error("read header: {0}")]
    Read(String),
    #[error("encode: {0}")]
    Encode(String),
    #[error("write: {0}")]
    Write(String),
}

pub fn read_frame<R: BufRead>(reader: &mut R) -> Result<Option<Value>, FrameError> {
    let Some(length) = read_headers(reader)? else {
        return Ok(None);
    };
    let mut body = vec![0u8; length];
    reader
        .read_exact(&mut body)
        .map_err(|err| FrameError::Truncated(err.to_string()))?;
    serde_json::from_slice(&body).map_err(|err| FrameError::Json(err.to_string()))
}

pub fn write_frame<W: Write>(writer: &mut W, message: &Value) -> Result<(), FrameError> {
    let body = serde_json::to_vec(message).map_err(|err| FrameError::Encode(err.to_string()))?;
    let header = format!("Content-Length: {}\r\n\r\n", body.len());
    writer
        .write_all(header.as_bytes())
        .and_then(|()| writer.write_all(&body))
        .and_then(|()| writer.flush())
        .map_err(|err| FrameError::Write(err.to_string()))
}

fn read_headers<R: BufRead>(reader: &mut R) -> Result<Option<usize>, FrameError> {
    let mut length: Option<usize> = None;
    loop {
        let Some(line) = header_line(reader)? else {
            return match length {
                Some(_) => Err(FrameError::TruncatedHeader),
                None => Ok(None),
            };
        };
        let header = line.trim_end_matches(['\r', '\n']);
        if header.is_empty() {
            return length.map(Some).ok_or(FrameError::MissingLength);
        }
        if let Some((name, value)) = header.split_once(':')
            && name.trim().eq_ignore_ascii_case("content-length")
        {
            length = Some(content_length(value)?);
        }
    }
}

fn header_line<R: BufRead>(reader: &mut R) -> Result<Option<String>, FrameError> {
    let mut line = String::new();
    let read = reader
        .by_ref()
        .take(MAX_HEADER_LINE)
        .read_line(&mut line)
        .map_err(|err| FrameError::Read(err.to_string()))?;
    if read == 0 {
        return Ok(None);
    }
    if !line.ends_with('\n') && read as u64 == MAX_HEADER_LINE {
        return Err(FrameError::HeaderTooLong);
    }
    Ok(Some(line))
}

fn content_length(value: &str) -> Result<usize, FrameError> {
    let length = value
        .trim()
        .parse::<usize>()
        .map_err(|err| FrameError::BadLength(err.to_string()))?;
    if length > MAX_BODY {
        return Err(FrameError::Oversized(length));
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
