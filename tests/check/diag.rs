use std::path::PathBuf;

use ride_engine::Diagnostic;

pub fn fixtures() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures")
}

pub fn src(diag: &Diagnostic) -> &str {
    &diag.primary.path
}
