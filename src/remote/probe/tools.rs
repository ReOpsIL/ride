use std::path::Path;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Tool {
    pub name: &'static str,
    pub purpose: &'static str,
    pub required: bool,
}

const TAR: Tool = Tool {
    name: "tar",
    purpose: "copies the project to Remote Root",
    required: true,
};

const CARGO: Tool = Tool {
    name: "cargo",
    purpose: "builds, runs, and tests Rust",
    required: true,
};

const CMAKE: Tool = Tool {
    name: "cmake",
    purpose: "configures and builds C and C++",
    required: true,
};

const LLDB_DAP: Tool = Tool {
    name: "lldb-dap",
    purpose: "debugs on the remote",
    required: false,
};

pub fn needed(local_root: &Path) -> Vec<Tool> {
    let cargo = local_root.join("Cargo.toml").is_file();
    let cmake = local_root.join("CMakeLists.txt").is_file();
    let mut tools = vec![TAR];
    match (cargo, cmake) {
        (false, false) => {
            tools.push(optional(CARGO));
            tools.push(optional(CMAKE));
        }
        _ => {
            if cargo {
                tools.push(CARGO);
            }
            if cmake {
                tools.push(CMAKE);
            }
        }
    }
    tools.push(LLDB_DAP);
    tools
}

pub fn names(tools: &[Tool]) -> Vec<&'static str> {
    tools.iter().map(|tool| tool.name).collect()
}

fn optional(tool: Tool) -> Tool {
    Tool {
        required: false,
        ..tool
    }
}
