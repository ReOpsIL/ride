use std::panic::{AssertUnwindSafe, catch_unwind};

use ride_engine::install_panic_hook;

#[test]
fn a_caught_panic_appends_one_json_line() {
    let dir = tempfile::tempdir().unwrap();
    install_panic_hook(dir.path());
    let log = dir.path().join("panics.jsonl");

    let outcome = catch_unwind(AssertUnwindSafe(|| panic!("report probe")));
    assert!(outcome.is_err());

    let text = std::fs::read_to_string(&log).unwrap();
    let lines: Vec<&str> = text.lines().collect();
    assert_eq!(lines.len(), 1, "{text}");
    let value: serde_json::Value = serde_json::from_str(lines[0]).unwrap();
    assert_eq!(value["message"], "report probe");
    assert!(
        value["location"]
            .as_str()
            .unwrap()
            .contains("tests/report.rs"),
        "{value}"
    );
    assert!(value["time"].as_u64().unwrap() > 0);
    assert!(!value["backtrace"].as_str().unwrap().is_empty());
}
