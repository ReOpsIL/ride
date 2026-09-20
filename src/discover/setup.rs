use std::path::PathBuf;
use std::process::Command;

use crate::ffi::ToolInfo;

use super::sysroot::{rust_src_available, rustc_sysroot};

pub const RUSTUP_INSTALL: &str =
    "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y";

pub fn setup_status() -> Vec<ToolInfo> {
    vec![command_line_tools(), rust_src()]
}

fn command_line_tools() -> ToolInfo {
    ToolInfo {
        name: "command-line-tools".into(),
        purpose: "Apple clang, headers and git".into(),
        path: developer_dir().map(|p| p.display().to_string()),
        install: Some("xcode-select --install".into()),
        hint: "run xcode-select --install and accept the dialog".into(),
        manual: false,
    }
}

fn rust_src() -> ToolInfo {
    let sysroot = rustc_sysroot().ok().flatten();
    let available = rust_src_available(sysroot.as_deref());
    ToolInfo {
        name: "rust-src".into(),
        purpose: "completion and docs from the standard library".into(),
        path: available
            .then(|| sysroot.map(|s| super::sysroot::rust_src_library(&s).display().to_string()))
            .flatten(),
        install: Some("rustup component add rust-src".into()),
        hint: "rustup component add rust-src".into(),
        manual: false,
    }
}

fn developer_dir() -> Option<PathBuf> {
    let output = Command::new("/usr/bin/xcode-select")
        .arg("-p")
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let dir = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if dir.is_empty() {
        return None;
    }
    Some(PathBuf::from(dir))
}
