use std::fs;
use std::path::PathBuf;

fn root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
}

fn cargo_package_version(text: &str) -> String {
    for line in text.lines() {
        let Some(rest) = line.strip_prefix("version = \"") else {
            continue;
        };
        return rest.trim_end_matches('"').to_string();
    }
    panic!("Cargo.toml has no package version");
}

fn marketing_versions(text: &str) -> Vec<String> {
    let mut out = Vec::new();
    for line in text.lines() {
        let line = line.trim();
        let Some(rest) = line.strip_prefix("MARKETING_VERSION = ") else {
            continue;
        };
        out.push(rest.trim_end_matches(';').to_string());
    }
    out
}

#[test]
fn cargo_and_marketing_version_agree() {
    let cargo = cargo_package_version(&fs::read_to_string(root().join("Cargo.toml")).unwrap());
    let marketing = marketing_versions(
        &fs::read_to_string(root().join("app/Ride.xcodeproj/project.pbxproj")).unwrap(),
    );
    assert!(
        !marketing.is_empty(),
        "project.pbxproj has no MARKETING_VERSION"
    );
    for version in &marketing {
        assert_eq!(version, &cargo);
    }
}
