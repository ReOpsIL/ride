use std::path::Path;

use crate::ffi::CompletionHit;
use crate::highlight::{BufferSession, Lang};

pub struct Buffer {
    pub replica: String,
    pub lang: Lang,
    pub path: Option<String>,
}

impl Buffer {
    pub fn of(session: &BufferSession) -> Self {
        Self {
            replica: session.replica().to_string(),
            lang: session.lang(),
            path: session.path().map(|p| p.display().to_string()),
        }
    }
}

pub struct Loaded {
    pub text: String,
    pub lang: Lang,
    pub path: String,
}

pub fn file_of<'a>(hit: &'a CompletionHit, buffer: Option<&Buffer>) -> Option<&'a str> {
    let file = hit.source_path.as_deref();
    let Some(buffer) = buffer else {
        return Some(file.unwrap_or_default());
    };
    match (file, buffer.path.as_deref()) {
        (None, _) => None,
        (Some(a), Some(b)) if Path::new(a) == Path::new(b) => None,
        (Some(a), _) => Some(a),
    }
}

pub fn load(file: Option<&str>, buffer: Option<&Buffer>) -> Loaded {
    match (file, buffer) {
        (None, Some(buffer)) => Loaded {
            text: buffer.replica.clone(),
            lang: buffer.lang,
            path: buffer.path.clone().unwrap_or_default(),
        },
        (file, _) => {
            let path = file.unwrap_or_default().to_string();
            let text = std::fs::read_to_string(&path).unwrap_or_default();
            let lang = Lang::for_buffer(Some(&path), &text);
            Loaded { text, lang, path }
        }
    }
}
