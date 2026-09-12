use std::collections::HashMap;

#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct DebugLaunch {
    pub program: String,
    pub args: Vec<String>,
    pub cwd: Option<String>,
    pub env: HashMap<String, String>,
    pub stop_on_entry: bool,
}

impl DebugLaunch {
    pub fn program(program: &str) -> Self {
        Self {
            program: program.to_string(),
            args: Vec::new(),
            cwd: None,
            env: HashMap::new(),
            stop_on_entry: false,
        }
    }
}

#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct Breakpoint {
    pub path: String,
    pub line: u32,
    pub condition: Option<String>,
    pub hit_condition: Option<String>,
    pub verified: bool,
}

impl Breakpoint {
    pub fn at(path: &str, line: u32) -> Self {
        Self {
            path: path.to_string(),
            line,
            condition: None,
            hit_condition: None,
            verified: false,
        }
    }
}

#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct DebugThread {
    pub id: i64,
    pub name: String,
}

#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct StackFrame {
    pub id: i64,
    pub name: String,
    pub path: Option<String>,
    pub line: u32,
    pub column: u32,
}

#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct DebugScope {
    pub name: String,
    pub variables_reference: i64,
    pub expensive: bool,
}

#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct Variable {
    pub name: String,
    pub value: String,
    pub type_name: Option<String>,
    pub variables_reference: i64,
    pub children_count: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum DebugCommand {
    Continue,
    Next,
    StepIn,
    StepOut,
    Pause,
    Disconnect,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum DebugEvaluateContext {
    Watch,
    Hover,
    Repl,
    Variables,
}

#[derive(Debug, Clone, PartialEq, uniffi::Enum)]
pub enum DebugState {
    Idle,
    Launching,
    Running,
    Stopped { thread_id: i64, reason: String },
    Exited { code: i64 },
    Terminated,
}

#[derive(Debug, Clone, PartialEq, uniffi::Enum)]
pub enum DebugEvent {
    Launching,
    Running,
    Stopped {
        thread_id: i64,
        reason: String,
        description: Option<String>,
        hit_breakpoint_ids: Vec<i64>,
    },
    Continued {
        thread_id: i64,
    },
    Breakpoints {
        path: String,
        breakpoints: Vec<Breakpoint>,
    },
    Exited {
        code: i64,
    },
    Terminated,
    Failed {
        message: String,
    },
}

#[uniffi::export(with_foreign)]
pub trait DebugListener: Send + Sync {
    fn on_event(&self, event: DebugEvent);
    fn on_output(&self, category: String, text: String);
}
