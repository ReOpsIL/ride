#[derive(Debug, Clone, PartialEq, uniffi::Enum)]
pub enum AttachProcess {
    Pid { pid: u32, program: Option<String> },
    WaitFor { program: String },
}

#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct DebugAttach {
    pub process: AttachProcess,
    pub cwd: Option<String>,
    pub exception_filters: Vec<String>,
}

impl DebugAttach {
    pub fn pid(pid: u32) -> Self {
        Self::to(AttachProcess::Pid { pid, program: None })
    }

    pub fn wait_for(program: &str) -> Self {
        Self::to(AttachProcess::WaitFor {
            program: program.to_string(),
        })
    }

    fn to(process: AttachProcess) -> Self {
        Self {
            process,
            cwd: None,
            exception_filters: Vec::new(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct DebugProcess {
    pub pid: u32,
    pub parent: u32,
    pub name: String,
    pub path: String,
}
