use std::env;

use ride_engine::system_includes::{SystemIncludes, probe_args};

fn clang_on_path() -> bool {
    env::var_os("PATH")
        .is_some_and(|path| env::split_paths(&path).any(|dir| dir.join("clang").is_file()))
}

fn args(list: &[&str]) -> Vec<String> {
    list.iter().map(|s| s.to_string()).collect()
}

#[test]
fn probed_system_dirs_exist_when_clang_is_on_path() {
    if !clang_on_path() {
        eprintln!("skipping: clang is not on PATH");
        return;
    }
    let probe = SystemIncludes::default();
    for lang in ["c", "c++"] {
        let dirs = probe.dirs(lang, &[]);
        assert!(dirs.iter().any(|d| d.is_dir()), "{lang}: {dirs:?}");
        let ranked = probe.dirs_ranked(lang, &[]);
        assert!(ranked.len() >= dirs.len());
        let first_framework = ranked.iter().position(|(_, fw)| *fw);
        if let Some(at) = first_framework {
            assert!(ranked[at..].iter().all(|(_, fw)| *fw), "{ranked:?}");
        }
        assert_eq!(probe.dirs(lang, &[]), dirs);
    }
}

#[test]
fn probe_args_keeps_only_sysroot_target_and_stdlib_flags() {
    let kept = probe_args(&args(&[
        "-std=c++20",
        "-Iinclude",
        "-isysroot",
        "/sdk",
        "--sysroot=/alt",
        "-target",
        "arm64-apple-macos",
        "--target=x86_64-linux-gnu",
        "-stdlib=libc++",
        "-DFOO=1",
        "-Wall",
    ]));
    assert_eq!(
        kept,
        args(&[
            "-isysroot",
            "/sdk",
            "--sysroot=/alt",
            "-target",
            "arm64-apple-macos",
            "--target=x86_64-linux-gnu",
            "-stdlib=libc++",
        ])
    );
}

#[test]
fn probe_args_drops_a_trailing_flag_without_value() {
    assert!(probe_args(&args(&["-Wall", "-isysroot"])).is_empty());
    assert!(probe_args(&[]).is_empty());
}
