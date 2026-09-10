use super::super::load::Files;

pub const FILES: Files = &[
    (
        "cargo-package",
        include_str!("../../../cheatsheets/toml/cargo-package.toml"),
    ),
    (
        "cargo-dependencies",
        include_str!("../../../cheatsheets/toml/cargo-dependencies.toml"),
    ),
    (
        "cargo-features-and-profiles",
        include_str!("../../../cheatsheets/toml/cargo-features-and-profiles.toml"),
    ),
    (
        "cargo-workspace",
        include_str!("../../../cheatsheets/toml/cargo-workspace.toml"),
    ),
    (
        "toml-syntax",
        include_str!("../../../cheatsheets/toml/toml-syntax.toml"),
    ),
];
