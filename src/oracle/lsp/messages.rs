use std::path::Path;

use serde_json::{Value, json};

use super::uri::file_uri;

pub fn initialize(root: &Path, options: Value) -> Value {
    let uri = file_uri(root);
    let name = root
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_default();
    json!({
        "processId": std::process::id(),
        "rootUri": uri,
        "workspaceFolders": [{ "uri": uri, "name": name }],
        "capabilities": {
            "general": { "positionEncodings": ["utf-8", "utf-16"] },
            "textDocument": {
                "completion": { "completionItem": { "snippetSupport": true } }
            },
            "experimental": { "serverStatusNotification": true }
        },
        "initializationOptions": options
    })
}

pub fn did_open(uri: &str, language: &str, version: i32, text: &str) -> Value {
    json!({
        "textDocument": { "uri": uri, "languageId": language, "version": version, "text": text }
    })
}

pub fn did_change(uri: &str, version: i32, text: &str) -> Value {
    json!({
        "textDocument": { "uri": uri, "version": version },
        "contentChanges": [{ "text": text }]
    })
}

pub fn did_close(uri: &str) -> Value {
    json!({ "textDocument": { "uri": uri } })
}

pub fn completion(uri: &str, position: Value) -> Value {
    json!({ "textDocument": { "uri": uri }, "position": position })
}
