use std::collections::BTreeMap;

use serde_json::Value;

use crate::error::EngineError;
use crate::ffi::{AttachProcess, DebugAttach, DebugLaunch};

use super::wire::arguments;
use crate::debug::protocol::{AttachArguments, LaunchArguments};
use crate::debug::target::DebugTarget;

pub fn start_request(
    target: &DebugTarget,
    init_commands: Vec<String>,
) -> Result<Value, EngineError> {
    match target {
        DebugTarget::Launch(launch) => {
            arguments(target.command(), &launch_arguments(launch, init_commands))
        }
        DebugTarget::Attach(attach) => {
            arguments(target.command(), &attach_arguments(attach, init_commands))
        }
    }
}

fn launch_arguments(launch: &DebugLaunch, init_commands: Vec<String>) -> LaunchArguments {
    LaunchArguments {
        program: launch.program.clone(),
        args: launch.args.clone(),
        cwd: launch.cwd.clone(),
        env: launch
            .env
            .iter()
            .map(|(name, value)| (name.clone(), value.clone()))
            .collect::<BTreeMap<String, String>>(),
        stop_on_entry: Some(launch.stop_on_entry),
        init_commands,
    }
}

fn attach_arguments(attach: &DebugAttach, init_commands: Vec<String>) -> AttachArguments {
    match &attach.process {
        AttachProcess::Pid { pid, .. } => AttachArguments {
            pid: Some(*pid),
            init_commands,
            ..AttachArguments::default()
        },
        AttachProcess::WaitFor { program } => AttachArguments {
            program: Some(program.clone()),
            wait_for: Some(true),
            init_commands,
            ..AttachArguments::default()
        },
    }
}
