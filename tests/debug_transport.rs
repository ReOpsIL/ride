use std::path::Path;
use std::time::Duration;

use ride_engine::{Transport, find_adapter};
use serde_json::{Value, json};

fn fake() -> Transport {
    Transport::spawn(Path::new(env!("CARGO_BIN_EXE_fake-dap")), &[])
        .expect("spawn the fake adapter")
        .with_timeout(Duration::from_secs(5))
}

#[test]
fn initialize_round_trips_and_emits_an_event() {
    let transport = fake();
    let body = transport
        .request("initialize", json!({ "adapterID": "fake" }))
        .expect("initialize response");
    assert_eq!(body["supportsConfigurationDoneRequest"], json!(true));
    let event = transport
        .next_event(Duration::from_secs(5))
        .expect("output event");
    assert_eq!(event["event"], json!("output"));
    assert_eq!(event["body"]["category"], json!("console"));
    assert!(transport.events().next().is_none());
}

#[test]
fn responses_correlate_across_several_requests() {
    let transport = fake();
    transport
        .request("threads", Value::Null)
        .expect("threads response");
    let body = transport
        .request("initialize", json!({ "adapterID": "fake" }))
        .expect("initialize response");
    assert_eq!(body["supportsConfigurationDoneRequest"], json!(true));
    let first = transport
        .next_event(Duration::from_secs(5))
        .expect("output event");
    assert_eq!(first["event"], json!("output"));
}

#[test]
fn a_truncated_frame_is_an_error() {
    let transport = fake();
    let err = transport
        .request("truncate", json!({}))
        .expect_err("a truncated frame must fail");
    assert!(err.to_string().contains("truncate"), "{err}");
}

#[test]
fn a_failed_response_is_an_error() {
    let transport = fake();
    let err = transport
        .request("fail", json!({}))
        .expect_err("an unsuccessful response must fail");
    assert!(err.to_string().contains("fake failure"), "{err}");
}

#[test]
fn a_closed_adapter_is_an_error() {
    let transport = fake();
    transport
        .request("disconnect", Value::Null)
        .expect("disconnect response");
    let err = transport
        .request("threads", Value::Null)
        .expect_err("a closed adapter must fail");
    assert!(err.to_string().contains("threads"), "{err}");
}

#[test]
fn a_missing_program_is_an_error() {
    let err = Transport::spawn(Path::new("/nonexistent/lldb-dap"), &[])
        .err()
        .expect("spawning a missing adapter must fail");
    assert!(err.to_string().contains("spawn"), "{err}");
}

#[test]
fn finding_the_adapter_never_panics() {
    if let Some(path) = find_adapter() {
        assert!(path.is_file());
    }
}
