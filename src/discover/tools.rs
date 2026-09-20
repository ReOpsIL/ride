use crate::ffi::ToolInfo;
use crate::toolchain::{find_tool, install_hint};

use super::setup::{RUSTUP_INSTALL, setup_status};

const TOOLS: &[(&str, &str)] = &[
    ("rustup", "installs and updates Rust toolchains"),
    ("rustfmt", "formats Rust files"),
    ("cargo-clippy", "extra Rust lints for Check"),
    ("clang", "C and C++ diagnostics"),
    ("clang-format", "formats C and C++ files"),
    ("cmake", "configures and builds CMake projects"),
    ("taplo", "formats TOML files"),
    ("cmake-format", "formats CMake files (gersemi also works)"),
    ("git", "branch and change badges"),
];

const MANUAL: &[&str] = &["rustup"];

pub fn tool_status() -> Vec<ToolInfo> {
    setup_status().into_iter().chain(probed()).collect()
}

fn probed() -> Vec<ToolInfo> {
    let installers = Installers::probe();
    TOOLS
        .iter()
        .map(|(name, purpose)| {
            let path = find_tool(name).or_else(|| {
                (*name == "cmake-format")
                    .then(|| find_tool("gersemi"))
                    .flatten()
            });
            ToolInfo {
                name: (*name).into(),
                purpose: (*purpose).into(),
                path: path.map(|p| p.display().to_string()),
                install: installers.command(name),
                hint: install_hint(name).into(),
                manual: MANUAL.contains(name),
            }
        })
        .collect()
}

struct Installers {
    brew: bool,
    rustup: bool,
    cargo: bool,
    pipx: bool,
}

impl Installers {
    fn probe() -> Self {
        Self {
            brew: find_tool("brew").is_some(),
            rustup: find_tool("rustup").is_some(),
            cargo: find_tool("cargo").is_some(),
            pipx: find_tool("pipx").is_some(),
        }
    }

    fn command(&self, name: &str) -> Option<String> {
        let brew = |pkg: &str| self.brew.then(|| format!("brew install {pkg}"));
        match name {
            "rustup" => Some(RUSTUP_INSTALL.into()),
            "rustfmt" => self.rustup.then(|| "rustup component add rustfmt".into()),
            "cargo-clippy" => self.rustup.then(|| "rustup component add clippy".into()),
            "clang" | "git" => Some("xcode-select --install".into()),
            "clang-format" => {
                brew("clang-format").or_else(|| Some("xcode-select --install".into()))
            }
            "cmake" => brew("cmake").or_else(|| Some("brew install cmake".into())),
            "taplo" => {
                brew("taplo").or_else(|| self.cargo.then(|| "cargo install taplo-cli".into()))
            }
            "cmake-format" => {
                brew("gersemi").or_else(|| self.pipx.then(|| "pipx install cmakelang".into()))
            }
            _ => None,
        }
    }
}
