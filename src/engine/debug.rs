use std::sync::Arc;

use crate::debug::adapter::adapter_path;
use crate::debug::filters::exception_filters;
use crate::debug::registry::DebugRegistry;
use crate::debug::session::DebugSession;
use crate::error::EngineError;
use crate::ffi::{
    Breakpoint, DebugCommand, DebugEvaluateContext, DebugEvent, DebugLaunch, DebugListener,
    DebugScope, DebugState, DebugThread, ExceptionFilter, StackFrame, Variable,
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
        let adapter = adapter_path()?;
        let registry = self.debug_registry()?;
        let sysroot = self.read(|i| i.sysroot.clone())?;
        registry
            .start(
                &adapter,
                &[],
                launch,
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

    pub fn debug_exception_filters(&self) -> Vec<ExceptionFilter> {
        exception_filters()
    }

    pub fn debug_state(&self, session_id: u64) -> DebugState {
        match self.debug_session(session_id) {
            Ok(session) => session.state(),
            Err(_) => DebugState::Idle,
        }
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
    fn debug_registry(&self) -> Result<Arc<DebugRegistry>, EngineError> {
        self.read(|i| Arc::clone(&i.debug_sessions))
    }

    fn debug_session(&self, session_id: u64) -> Result<Arc<DebugSession>, EngineError> {
        self.debug_registry()?
            .get(session_id)
            .ok_or(EngineError::SessionNotFound { session_id })
    }
}
