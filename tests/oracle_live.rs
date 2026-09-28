mod oracle_support;

use oracle_support::{Probe, names};
use ride_engine::OracleState;

const MANIFEST: &str =
    "[package]\nname = \"oracle-probe\"\nversion = \"0.1.0\"\nedition = \"2021\"\n";

fn open(source: &str) -> Option<Probe> {
    Probe::open(
        "rust-analyzer",
        &[("Cargo.toml", MANIFEST), ("src/main.rs", source)],
        "src/main.rs",
    )
}

#[test]
fn a_split_chain_completes_iterator_methods_once_rust_analyzer_answers() {
    let source = "fn main() {\n    let parts: Vec<&str> = probe(\"a.b\");\n    println!(\"{}\", parts.len());\n}\n\nfn probe(s: &str) -> Vec<&str> {\n    s.split('.').co\n}\n";
    let Some(mut probe) = open(source) else {
        return;
    };
    let anchor = "split('.').co";
    assert!(!names(&probe.at(anchor)).contains(&"collect".to_string()));
    let answered = probe.answered(anchor);
    assert_eq!(names(&answered), ["collect", "copied", "count"]);
    let collect = &answered.hits[0];
    assert!(collect.snippet);
    assert_eq!(collect.insert_text, "collect()$0");
    assert_eq!(collect.detail, "Iterator");
    assert_eq!(probe.engine.oracle_status().state, OracleState::Ready);

    probe.engine.set_oracle_enabled(false);
    assert_eq!(probe.engine.oracle_status().state, OracleState::Off);
    assert!(!names(&probe.at(anchor)).contains(&"collect".to_string()));
}

#[test]
fn an_identifier_lists_what_is_in_scope() {
    let source = "use std::collections::HashMap;\n\nfn main() {\n    let total_count = 1;\n    let m: Ha\n    let t = tot\n}\n";
    let Some(mut probe) = open(source) else {
        return;
    };
    let answered = probe.answered("let m: Ha");
    assert!(
        names(&answered).contains(&"HashMap".to_string()),
        "{:?}",
        names(&answered)
    );
    let local = probe.at("let t = tot");
    assert_eq!(
        names(&local).first().map(String::as_str),
        Some("total_count")
    );
}

#[test]
fn a_type_path_and_a_use_path_list_their_children() {
    let source = "use std::coll\n\nfn main() {\n    let v: Vec<u8> = Vec::with\n}\n";
    let Some(mut probe) = open(source) else {
        return;
    };
    let path = probe.answered("Vec::with");
    assert!(
        names(&path).contains(&"with_capacity".to_string()),
        "{:?}",
        names(&path)
    );
    let got = probe.until("use std::coll", "collections");
    assert!(got.contains(&"collections".to_string()), "{got:?}");
}

#[test]
fn a_method_in_a_chain_goes_to_its_trait_definition() {
    let source = "fn main() {\n    let parts: Vec<&str> = \"a.b\".split('.').collect();\n    println!(\"{}\", parts.len());\n}\n";
    let Some(probe) = open(source) else {
        return;
    };
    let hit = probe
        .definition_until(".collect", |h| {
            h.source_path
                .as_deref()
                .is_some_and(|p| p.ends_with("iterator.rs"))
        })
        .expect("collect resolves into core's iterator.rs");
    assert!(hit.signature.contains("fn collect"), "{}", hit.signature);
    let cursor = source.find(".collect").expect("anchor") as u32 + 2;
    let doc = probe
        .engine
        .quick_doc(probe.session_id, cursor)
        .expect("quick doc");
    assert_eq!(doc.title, "collect");
    assert!(
        doc.origin_path.ends_with("iterator.rs"),
        "{}",
        doc.origin_path
    );
    assert!(
        doc.html.contains("collection"),
        "{}",
        &doc.html[..doc.html.len().min(200)]
    );
}

#[test]
fn type_info_names_the_inferred_type_of_a_binding() {
    let source = "fn main() {\n    let parts = \"a.b\".split('.').collect::<Vec<_>>();\n    println!(\"{}\", parts.len());\n}\n";
    let Some(probe) = open(source) else {
        return;
    };
    let cursor = source.find("parts").expect("anchor") as u32 + 1;
    let deadline = std::time::Instant::now() + std::time::Duration::from_secs(120);
    let mut info = None;
    while info.is_none() && std::time::Instant::now() < deadline {
        info = probe.engine.type_info(probe.session_id, cursor);
        std::thread::sleep(std::time::Duration::from_millis(300));
    }
    let info = info.expect("type info");
    assert_eq!(info.title, "parts");
    assert!(info.signature.contains("Vec<&str>"), "{}", info.signature);
}

#[test]
fn a_trait_method_lists_its_workspace_implementations() {
    let source = "trait Recorder {\n    fn record(&mut self);\n}\n\nstruct Counter;\n\nimpl Recorder for Counter {\n    fn record(&mut self) {}\n}\n\nfn main() {\n    Counter.record();\n}\n";
    let Some(probe) = open(source) else {
        return;
    };
    let implementation = source.rfind("fn record").expect("impl") as u32 + 3;
    let hit = probe
        .definition_until("    fn rec", |h| h.byte_start == Some(implementation))
        .expect("the impl next to the trait declaration");
    assert!(hit.source_path.is_none());
}
