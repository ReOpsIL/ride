use std::path::PathBuf;
use std::sync::Arc;

use ride_engine::{
    Engine, EngineConfig, Target, TargetKind, TestEvent, TestFramework, TestStatus, engine_start,
};

fn fixture(name: &str) -> String {
    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures/tests")
        .join(name);
    std::fs::read_to_string(&path).unwrap()
}

fn engine() -> Arc<Engine> {
    engine_start(EngineConfig {
        index_dir: tempfile::tempdir().unwrap().path().display().to_string(),
        cargo_home: None,
        sysroot: None,
        offline_metadata: true,
    })
}

fn named<'a>(events: &'a [TestEvent], name: &str) -> &'a TestEvent {
    events
        .iter()
        .find(|e| e.name == name && e.status != TestStatus::Started)
        .unwrap()
}

fn target(name: &str, kind: TargetKind, run: Option<Vec<String>>) -> Target {
    Target {
        name: name.to_string(),
        kind,
        build: Vec::new(),
        run,
        sources: Vec::new(),
        working_dir: "/project".to_string(),
    }
}

#[test]
fn cargo_list_yields_names_and_modules() {
    let cases = engine().list_tests(TestFramework::Cargo, fixture("cargo-list.txt"));
    assert_eq!(cases.len(), 3);
    assert_eq!(
        cases[0].name,
        "util::runner_fixture_tests::adds_two_numbers"
    );
    assert_eq!(
        cases[0].suite.as_deref(),
        Some("util::runner_fixture_tests")
    );
    assert!(cases[0].file.is_none());
}

#[test]
fn cargo_output_carries_status_and_failure_text() {
    let events = engine().parse_test_output(TestFramework::Cargo, fixture("cargo-run.txt"));
    assert_eq!(events.len(), 3);
    let passed = named(&events, "adds_two_numbers");
    assert_eq!(passed.status, TestStatus::Passed);
    assert_eq!(passed.suite.as_deref(), Some("util::runner_fixture_tests"));
    assert!(passed.output.is_empty());
    let ignored = named(&events, "skipped_for_now");
    assert_eq!(ignored.status, TestStatus::Ignored);
    let failed = named(&events, "compares_wrong_sum");
    assert_eq!(failed.status, TestStatus::Failed);
    assert!(failed.output.contains("arithmetic drifted"));
    assert!(failed.output.contains("src/util.rs:40"));
}

#[test]
fn cargo_output_keeps_one_block_per_binary() {
    let events =
        engine().parse_test_output(TestFramework::Cargo, fixture("cargo-run-two-binaries.txt"));
    assert_eq!(events.len(), 2);
    assert!(events.iter().all(|e| e.name == "shared_name"));
    assert!(events[0].output.contains("lib arithmetic drifted"));
    assert!(!events[0].output.contains("integration arithmetic drifted"));
    assert!(events[1].output.contains("integration arithmetic drifted"));
    assert!(!events[1].output.contains("lib arithmetic drifted"));
}

#[test]
fn gtest_list_groups_cases_by_suite() {
    let cases = engine().list_tests(TestFramework::GoogleTest, fixture("gtest-list.txt"));
    assert_eq!(cases.len(), 3);
    assert_eq!(cases[0].suite.as_deref(), Some("GeoSuite"));
    assert_eq!(cases[0].name, "AddsPoints");
    assert_eq!(cases[2].suite.as_deref(), Some("TextSuite"));
    assert_eq!(cases[2].name, "TrimsBlanks");
}

#[test]
fn gtest_output_pairs_run_with_result() {
    let events = engine().parse_test_output(TestFramework::GoogleTest, fixture("gtest-run.txt"));
    assert_eq!(
        events
            .iter()
            .filter(|e| e.status == TestStatus::Started)
            .count(),
        3
    );
    let failed = named(&events, "DetectsDrift");
    assert_eq!(failed.status, TestStatus::Failed);
    assert_eq!(failed.suite.as_deref(), Some("GeoSuite"));
    assert_eq!(failed.duration_ms, Some(1));
    assert!(failed.output.contains("arithmetic drifted"));
    assert_eq!(named(&events, "AddsPoints").status, TestStatus::Passed);
    assert_eq!(named(&events, "TrimsBlanks").duration_ms, Some(0));
}

#[test]
fn catch2_list_carries_tags_and_locations() {
    let cases = engine().list_tests(TestFramework::Catch2, fixture("catch2-list.xml"));
    assert_eq!(cases.len(), 6);
    assert_eq!(cases[1].name, "detects drift");
    assert_eq!(cases[1].suite.as_deref(), Some("[geo]"));
    assert_eq!(cases[1].file.as_deref(), Some("c2.cpp"));
    assert_eq!(cases[1].line, Some(5));
    assert_eq!(cases[4].name, "skips slow path");
    assert_eq!(cases[5].name, "counts twice");
    assert_eq!(cases[5].line, Some(15));
}

#[test]
fn catch2_xml_reports_one_event_per_test_case() {
    let events = engine().parse_test_output(TestFramework::Catch2, fixture("catch2-run.xml"));
    assert_eq!(events.len(), 6);
    assert_eq!(events[0].name, "adds points");
    assert_eq!(events[0].suite.as_deref(), Some("[geo]"));
    assert_eq!(events[0].status, TestStatus::Passed);
    assert!(events[0].output.is_empty());
    assert_eq!(events[1].name, "detects drift");
    assert_eq!(events[1].status, TestStatus::Failed);
    assert_eq!(
        events[1].output,
        "sum: c2.cpp:6: REQUIRE(2 + 2 == 5)\nwith expansion: 4 == 5"
    );
    assert_eq!(
        events[2].output,
        "c2.cpp:9: REQUIRE(2 < 1)\nwith expansion: 2 < 1"
    );
    assert_eq!(events[3].status, TestStatus::Passed);
    assert_eq!(events[4].name, "skips slow path");
    assert_eq!(events[4].status, TestStatus::Ignored);
    assert_eq!(events[4].output, "needs a fixture");
}

#[test]
fn catch2_lists_every_failed_check_of_one_case() {
    let events = engine().parse_test_output(TestFramework::Catch2, fixture("catch2-run.xml"));
    let failed = named(&events, "counts twice");
    assert_eq!(failed.status, TestStatus::Failed);
    assert_eq!(
        failed.output,
        "c2.cpp:16: CHECK(1 == 2)\nwith expansion: 1 == 2\nc2.cpp:17: CHECK(3 == 4)\nwith expansion: 3 == 4"
    );
}

#[test]
fn catch2_durations_come_from_the_run() {
    let events = engine().parse_test_output(TestFramework::Catch2, fixture("catch2-run.xml"));
    assert!(events.iter().all(|e| e.duration_ms.is_some()));
    assert_eq!(events[0].duration_ms, Some(0));
}

#[test]
fn catch2_truncated_output_keeps_earlier_events() {
    let text = fixture("catch2-run.xml");
    let cut = text.find("compares sizes").unwrap();
    let events = engine().parse_test_output(TestFramework::Catch2, text[..cut].to_string());
    assert_eq!(events.len(), 2);
    assert_eq!(events[0].name, "adds points");
    assert_eq!(events[1].name, "detects drift");
    assert_eq!(events[1].status, TestStatus::Failed);
}

#[test]
fn ctest_list_reads_json_with_source_lines() {
    let cases = engine().list_tests(TestFramework::CTest, fixture("ctest-list.json"));
    assert_eq!(cases.len(), 3);
    assert_eq!(cases[0].name, "geo.adds_points");
    assert_eq!(cases[0].suite.as_deref(), Some("geo"));
    assert_eq!(cases[0].file.as_deref(), Some("/project/CMakeLists.txt"));
    assert_eq!(cases[0].line, Some(5));
}

#[test]
fn ctest_output_attaches_failure_text() {
    let events = engine().parse_test_output(TestFramework::CTest, fixture("ctest-run.txt"));
    assert_eq!(
        events
            .iter()
            .filter(|e| e.status == TestStatus::Started)
            .count(),
        3
    );
    let failed = named(&events, "geo.detects_drift");
    assert_eq!(failed.status, TestStatus::Failed);
    assert_eq!(failed.output, "arithmetic drifted");
    assert_eq!(failed.duration_ms, Some(10));
    assert_eq!(
        named(&events, "text.trims_blanks").status,
        TestStatus::Passed
    );
}

#[test]
fn cargo_commands_select_the_target() {
    let engine = engine();
    let commands = engine
        .test_commands(target("demo", TargetKind::Lib, None), TestFramework::Cargo)
        .unwrap();
    assert_eq!(commands.run, ["cargo", "test", "--lib"]);
    assert_eq!(commands.list, ["cargo", "test", "--lib", "--", "--list"]);
    let commands = engine
        .test_commands(target("geo", TargetKind::Test, None), TestFramework::Cargo)
        .unwrap();
    assert_eq!(commands.run, ["cargo", "test", "--test", "geo"]);
}

#[test]
fn binary_commands_extend_the_run_argv() {
    let engine = engine();
    let exe = Some(vec!["/project/build/geo_tests".to_string()]);
    let commands = engine
        .test_commands(
            target("geo_tests", TargetKind::Bin, exe.clone()),
            TestFramework::GoogleTest,
        )
        .unwrap();
    assert_eq!(
        commands.list,
        ["/project/build/geo_tests", "--gtest_list_tests"]
    );
    assert_eq!(
        commands.run,
        ["/project/build/geo_tests", "--gtest_color=no"]
    );
    let commands = engine
        .test_commands(
            target("geo_tests", TargetKind::Bin, exe),
            TestFramework::Catch2,
        )
        .unwrap();
    assert_eq!(
        commands.list,
        [
            "/project/build/geo_tests",
            "--reporter",
            "xml",
            "--list-tests"
        ]
    );
    assert_eq!(
        commands.run,
        [
            "/project/build/geo_tests",
            "--reporter",
            "xml",
            "--durations",
            "yes"
        ]
    );
}

#[test]
fn ctest_commands_are_fixed_and_missing_binaries_error() {
    let engine = engine();
    let commands = engine
        .test_commands(
            target("all", TargetKind::Custom, None),
            TestFramework::CTest,
        )
        .unwrap();
    assert_eq!(commands.list, ["ctest", "--show-only=json-v1"]);
    assert_eq!(commands.run, ["ctest", "--output-on-failure"]);
    assert!(
        engine
            .test_commands(
                target("geo_tests", TargetKind::Bin, None),
                TestFramework::Catch2
            )
            .is_err()
    );
}
