use std::process::ChildStdin;
use std::sync::Mutex;

use serde_json::Value;

use crate::oracle::error::OracleError;
use crate::wire::{FrameError, write_frame};

pub fn write(stdin: &Mutex<ChildStdin>, message: &Value) -> Result<(), OracleError> {
    let mut stdin = stdin
        .lock()
        .map_err(|_| FrameError::Write("stdin poisoned".into()))?;
    Ok(write_frame(&mut *stdin, message)?)
}
