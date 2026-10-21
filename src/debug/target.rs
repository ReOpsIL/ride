use std::time::Duration;

use crate::ffi::{AttachProcess, DebugAttach, DebugLaunch};

const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(30);
const WAIT_FOR_TIMEOUT: Duration = Duration::from_secs(24 * 60 * 60);

#[derive(Debug, Clone, PartialEq)]
pub enum DebugTarget {
    Launch(DebugLaunch),
    Attach(DebugAttach),
}

impl DebugTarget {
    pub fn command(&self) -> &'static str {
        match self {
            Self::Launch(_) => "launch",
            Self::Attach(_) => "attach",
        }
    }

    pub fn program(&self) -> Option<&str> {
        match self {
            Self::Launch(launch) => Some(&launch.program),
            Self::Attach(attach) => match &attach.process {
                AttachProcess::Pid { program, .. } => program.as_deref(),
                AttachProcess::WaitFor { program } => Some(program),
            },
        }
    }

    pub fn cwd(&self) -> Option<&str> {
        match self {
            Self::Launch(launch) => launch.cwd.as_deref(),
            Self::Attach(attach) => attach.cwd.as_deref(),
        }
    }

    pub fn exception_filters(&self) -> &[String] {
        match self {
            Self::Launch(launch) => &launch.exception_filters,
            Self::Attach(attach) => &attach.exception_filters,
        }
    }

    pub fn owns_debuggee(&self) -> bool {
        matches!(self, Self::Launch(_))
    }

    pub fn handshake_timeout(&self) -> Duration {
        match self {
            Self::Attach(DebugAttach {
                process: AttachProcess::WaitFor { .. },
                ..
            }) => WAIT_FOR_TIMEOUT,
            _ => HANDSHAKE_TIMEOUT,
        }
    }
}

impl From<DebugLaunch> for DebugTarget {
    fn from(launch: DebugLaunch) -> Self {
        Self::Launch(launch)
    }
}

impl From<DebugAttach> for DebugTarget {
    fn from(attach: DebugAttach) -> Self {
        Self::Attach(attach)
    }
}
