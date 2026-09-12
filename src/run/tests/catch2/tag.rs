use quick_xml::escape::unescape;
use quick_xml::events::{BytesRef, BytesStart};

use crate::ffi::TestStatus;

pub fn entity(reference: &BytesRef) -> String {
    let Ok(name) = reference.decode() else {
        return String::new();
    };
    match unescape(&format!("&{name};")) {
        Ok(text) => text.into_owned(),
        Err(_) => String::new(),
    }
}

pub fn location(tag: &BytesStart) -> String {
    let file = attr(tag, "filename").unwrap_or_default();
    match attr(tag, "line") {
        Some(line) => format!("{file}:{line}"),
        None => file,
    }
}

pub fn status(tag: &BytesStart) -> TestStatus {
    if attr(tag, "skips").is_some_and(|skips| skips != "0") {
        return TestStatus::Ignored;
    }
    match attr(tag, "success").as_deref() {
        Some("true") => TestStatus::Passed,
        _ => TestStatus::Failed,
    }
}

pub fn attr(tag: &BytesStart, name: &str) -> Option<String> {
    tag.attributes()
        .flatten()
        .find(|a| a.key.as_ref() == name.as_bytes())
        .and_then(|a| a.unescape_value().ok())
        .map(|value| value.into_owned())
}
