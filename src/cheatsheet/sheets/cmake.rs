use super::super::load::Files;

pub const FILES: Files = &[
    (
        "project",
        include_str!("../../../cheatsheets/cmake/project.toml"),
    ),
    (
        "targets",
        include_str!("../../../cheatsheets/cmake/targets.toml"),
    ),
    (
        "variables-and-options",
        include_str!("../../../cheatsheets/cmake/variables-and-options.toml"),
    ),
    (
        "find-and-link",
        include_str!("../../../cheatsheets/cmake/find-and-link.toml"),
    ),
    (
        "control-flow",
        include_str!("../../../cheatsheets/cmake/control-flow.toml"),
    ),
    (
        "functions-and-macros",
        include_str!("../../../cheatsheets/cmake/functions-and-macros.toml"),
    ),
    (
        "install-and-test",
        include_str!("../../../cheatsheets/cmake/install-and-test.toml"),
    ),
];
