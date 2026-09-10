use crate::ffi::ToolInfo;
use crate::toolchain::{find_tool, install_hint};

const TOOLS: &[(&str, &str)] = &[
    ("rustfmt", "formats Rust files"),
    ("cargo-clippy", "extra Rust lints for Check"),
    ("clang", "C and C++ diagnostics"),
    ("clang-format", "formats C and C++ files"),
    ("taplo", "formats TOML files"),
    ("cmake-format", "formats CMake files (gersemi also works)"),
    ("git", "branch and change badges"),
];

pub fn tool_status() -> Vec<ToolInfo> {
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
            "rustfmt" => self.rustup.then(|| "rustup component add rustfmt".into()),
            "cargo-clippy" => self.rustup.then(|| "rustup component add clippy".into()),
            "clang" | "git" => Some("xcode-select --install".into()),
            "clang-format" => {
                brew("clang-format").or_else(|| Some("xcode-select --install".into()))
            }
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
