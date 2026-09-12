use crate::error::EngineError;
use crate::ffi::{Target, TargetKind, TestCommands, TestFramework};

pub fn test_commands(
    target: &Target,
    framework: TestFramework,
) -> Result<TestCommands, EngineError> {
    match framework {
        TestFramework::Cargo => Ok(cargo(target)),
        TestFramework::GoogleTest => binary(target, &["--gtest_list_tests"], &["--gtest_color=no"]),
        TestFramework::Catch2 => binary(
            target,
            &["--reporter", "xml", "--list-tests"],
            &["--reporter", "xml", "--durations", "yes"],
        ),
        TestFramework::CTest => Ok(ctest()),
    }
}

fn cargo(target: &Target) -> TestCommands {
    let mut run = vec!["cargo".to_string(), "test".to_string()];
    run.extend(selector(target));
    let mut list = run.clone();
    list.push("--".to_string());
    list.push("--list".to_string());
    TestCommands { list, run }
}

fn selector(target: &Target) -> Vec<String> {
    let named = |flag: &str| vec![flag.to_string(), target.name.clone()];
    match target.kind {
        TargetKind::Lib => vec!["--lib".to_string()],
        TargetKind::Bin => named("--bin"),
        TargetKind::Test => named("--test"),
        TargetKind::Bench => named("--bench"),
        TargetKind::Example => named("--example"),
        TargetKind::Custom => Vec::new(),
    }
}

fn binary(
    target: &Target,
    list_args: &[&str],
    run_args: &[&str],
) -> Result<TestCommands, EngineError> {
    let base = target.run.clone().ok_or_else(|| EngineError::Tool {
        message: format!("target {} has no run command", target.name),
    })?;
    if base.is_empty() {
        return Err(EngineError::Tool {
            message: format!("target {} has an empty run command", target.name),
        });
    }
    Ok(TestCommands {
        list: with(&base, list_args),
        run: with(&base, run_args),
    })
}

fn with(base: &[String], args: &[&str]) -> Vec<String> {
    let mut argv = base.to_vec();
    argv.extend(args.iter().map(|a| (*a).to_string()));
    argv
}

fn ctest() -> TestCommands {
    TestCommands {
        list: vec!["ctest".to_string(), "--show-only=json-v1".to_string()],
        run: vec!["ctest".to_string(), "--output-on-failure".to_string()],
    }
}
