use std::collections::HashMap;
use std::path::Path;
use std::sync::Arc;

use crate::debug::adapter::adapter_path;
use crate::debug::filters::exception_filters;
use crate::debug::processes::list_processes;
use crate::debug::registry::DebugRegistry;
use crate::debug::session::DebugSession;
use crate::debug::target::DebugTarget;
use crate::error::EngineError;
use crate::ffi::{
    Breakpoint, DebugAttach, DebugCommand, DebugEvaluateContext, DebugEvent, DebugLaunch,
    DebugListener, DebugProcess, DebugScope, DebugThread, ExceptionFilter, RemoteLink, StackFrame,
    Variable,
};

use super::Engine;

#[uniffi::export]
impl Engine {
    pub fn debug_launch(
        &self,
        launch: DebugLaunch,
        breakpoints: Vec<Breakpoint>,
        listener: Arc<dyn DebugListener>,
    ) -> Result<u64, EngineError> {
        self.debug_start(launch.into(), breakpoints, listener)
    }

    pub fn debug_attach(
        &self,
        attach: DebugAttach,
        breakpoints: Vec<Breakpoint>,
        listener: Arc<dyn DebugListener>,
    ) -> Result<u64, EngineError> {
        self.debug_start(attach.into(), breakpoints, listener)
    }

    pub fn debug_processes(&self) -> Result<Vec<DebugProcess>, EngineError> {
        list_processes()
    }

    pub fn debug_launch_remote(
        &self,
        target: RemoteLink,
        launch: DebugLaunch,
        breakpoints: Vec<Breakpoint>,
        listener: Arc<dyn DebugListener>,
    ) -> Result<u64, EngineError> {
        self.open_remote(&target, launch, breakpoints, Arc::clone(&listener))
            .inspect_err(|err| {
                listener.on_event(DebugEvent::Failed {
                    message: err.to_string(),
                });
            })
    }

    pub fn debug_exception_filters(&self) -> Vec<ExceptionFilter> {
        exception_filters()
    }

    pub fn debug_command(&self, session_id: u64, command: DebugCommand) -> Result<(), EngineError> {
        self.debug_session(session_id)?.command(command)
    }

    pub fn debug_threads(&self, session_id: u64) -> Result<Vec<DebugThread>, EngineError> {
        self.debug_session(session_id)?.threads()
    }

    pub fn debug_stack(
        &self,
        session_id: u64,
        thread_id: i64,
    ) -> Result<Vec<StackFrame>, EngineError> {
        self.debug_session(session_id)?.stack(thread_id)
    }

    pub fn debug_scopes(
        &self,
        session_id: u64,
        frame_id: i64,
    ) -> Result<Vec<DebugScope>, EngineError> {
        self.debug_session(session_id)?.scopes(frame_id)
    }

    pub fn debug_variables(
        &self,
        session_id: u64,
        variables_reference: i64,
        start: u32,
        count: u32,
    ) -> Result<Vec<Variable>, EngineError> {
        self.debug_session(session_id)?
            .variables(variables_reference, start, count)
    }

    pub fn debug_evaluate(
        &self,
        session_id: u64,
        frame_id: i64,
        expression: String,
        context: DebugEvaluateContext,
    ) -> Result<Variable, EngineError> {
        self.debug_session(session_id)?
            .evaluate(frame_id, &expression, context)
    }

    pub fn debug_set_breakpoints(
        &self,
        session_id: u64,
        path: String,
        breakpoints: Vec<Breakpoint>,
    ) -> Result<Vec<Breakpoint>, EngineError> {
        self.debug_session(session_id)?
            .set_breakpoints(&path, breakpoints)
    }
}

impl Engine {
    fn debug_start(
        &self,
        target: DebugTarget,
        breakpoints: Vec<Breakpoint>,
        listener: Arc<dyn DebugListener>,
    ) -> Result<u64, EngineError> {
        let adapter = adapter_path()?;
        let registry = self.debug_registry()?;
        let sysroot = self.read(|i| i.sysroot.clone())?;
        registry
            .start(
                &adapter,
                &[],
                target,
                sysroot,
                breakpoints,
                Arc::clone(&listener),
            )
            .inspect_err(|err| {
                listener.on_event(DebugEvent::Failed {
                    message: err.to_string(),
                });
            })
    }

    fn open_remote(
        &self,
        target: &RemoteLink,
        launch: DebugLaunch,
        breakpoints: Vec<Breakpoint>,
        listener: Arc<dyn DebugListener>,
    ) -> Result<u64, EngineError> {
        let endpoint = crate::remote::from_link(target).map_err(as_remote)?;
        let launch = crate::remote::map_launch(&endpoint, launch).map_err(as_remote)?;
        let owned = env_pairs(&launch.env);
        let pairs = pair_refs(&owned);
        let cwd = launch
            .cwd
            .clone()
            .unwrap_or_else(|| endpoint.remote_root().display().to_string());
        let invocation = endpoint
            .invocation(Path::new(&cwd), &pairs, &["lldb-dap"])
            .map_err(as_remote)?;
        self.debug_registry()?.start_mapped(
            Path::new(&invocation.program),
            &invocation.args,
            launch,
            breakpoints,
            listener,
            endpoint.path_map(),
        )
    }

    fn debug_registry(&self) -> Result<Arc<DebugRegistry>, EngineError> {
        self.read(|i| Arc::clone(&i.debug_sessions))
    }

    fn debug_session(&self, session_id: u64) -> Result<Arc<DebugSession>, EngineError> {
        self.debug_registry()?
            .get(session_id)
            .ok_or(EngineError::SessionNotFound { session_id })
    }
}

fn env_pairs(env: &HashMap<String, String>) -> Vec<(String, String)> {
    env.iter()
        .map(|(key, value)| (key.clone(), value.clone()))
        .collect()
}

fn pair_refs(pairs: &[(String, String)]) -> Vec<(&str, &str)> {
    pairs
        .iter()
        .map(|(key, value)| (key.as_str(), value.as_str()))
        .collect()
}

fn as_remote(err: crate::remote::RemoteError) -> EngineError {
    EngineError::remote(err.to_string())
}
