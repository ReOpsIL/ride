use serde_json::Value;

use crate::error::EngineError;
use crate::ffi::{DebugCommand, DebugEvaluateContext, DebugThread, Scope, StackFrame, Variable};

use super::DebugSession;
use super::wire::{arguments, body, context, evaluated, frame, scope, thread, variable};
use crate::debug::protocol::{
    CONTINUE, ContinueArguments, DisconnectArguments, EvaluateArguments, EvaluateResponseBody,
    NEXT, PAUSE, PauseArguments, STEP_IN, STEP_OUT, ScopesArguments, ScopesResponseBody,
    StackTraceArguments, StackTraceResponseBody, StepArguments, ThreadsResponseBody,
    VariablesArguments, VariablesResponseBody,
};

const THREADS: &str = "threads";
const STACK_TRACE: &str = "stackTrace";
const SCOPES: &str = "scopes";
const VARIABLES: &str = "variables";
const EVALUATE: &str = "evaluate";
const DISCONNECT: &str = "disconnect";
const STACK_LEVELS: u32 = 64;

impl DebugSession {
    pub fn threads(&self) -> Result<Vec<DebugThread>, EngineError> {
        let response = self.transport.request(THREADS, Value::Null)?;
        let listed = body::<ThreadsResponseBody>(THREADS, response)?;
        let threads: Vec<DebugThread> = listed.threads.into_iter().map(thread).collect();
        if let Ok(mut cached) = self.threads.lock() {
            *cached = threads.clone();
        }
        Ok(threads)
    }

    pub fn stack(&self, thread_id: i64) -> Result<Vec<StackFrame>, EngineError> {
        let request = StackTraceArguments::thread(thread_id, STACK_LEVELS);
        let response = self
            .transport
            .request(STACK_TRACE, arguments(STACK_TRACE, &request)?)?;
        let listed = body::<StackTraceResponseBody>(STACK_TRACE, response)?;
        Ok(listed.stack_frames.into_iter().map(frame).collect())
    }

    pub fn scopes(&self, frame_id: i64) -> Result<Vec<Scope>, EngineError> {
        let request = ScopesArguments { frame_id };
        let response = self
            .transport
            .request(SCOPES, arguments(SCOPES, &request)?)?;
        let listed = body::<ScopesResponseBody>(SCOPES, response)?;
        Ok(listed.scopes.into_iter().map(scope).collect())
    }

    pub fn variables(
        &self,
        variables_reference: i64,
        start: u32,
        count: u32,
    ) -> Result<Vec<Variable>, EngineError> {
        let request = if count == 0 {
            VariablesArguments {
                variables_reference,
                filter: None,
                start: None,
                count: None,
            }
        } else {
            VariablesArguments::page(variables_reference, start, count)
        };
        let response = self
            .transport
            .request(VARIABLES, arguments(VARIABLES, &request)?)?;
        let listed = body::<VariablesResponseBody>(VARIABLES, response)?;
        Ok(listed.variables.into_iter().map(variable).collect())
    }

    pub fn evaluate(
        &self,
        frame_id: i64,
        expression: &str,
        evaluate_context: DebugEvaluateContext,
    ) -> Result<Variable, EngineError> {
        let request = EvaluateArguments::in_frame(expression, frame_id, context(evaluate_context));
        let response = self
            .transport
            .request(EVALUATE, arguments(EVALUATE, &request)?)?;
        let result = body::<EvaluateResponseBody>(EVALUATE, response)?;
        Ok(evaluated(result, expression))
    }

    pub fn command(&self, command: DebugCommand) -> Result<(), EngineError> {
        let thread_id = self.stopped_thread().unwrap_or_default();
        match command {
            DebugCommand::Continue => self.send(
                CONTINUE,
                arguments(
                    CONTINUE,
                    &ContinueArguments {
                        thread_id,
                        single_thread: None,
                    },
                )?,
            ),
            DebugCommand::Next => self.step(NEXT, thread_id),
            DebugCommand::StepIn => self.step(STEP_IN, thread_id),
            DebugCommand::StepOut => self.step(STEP_OUT, thread_id),
            DebugCommand::Pause => {
                self.send(PAUSE, arguments(PAUSE, &PauseArguments { thread_id })?)
            }
            DebugCommand::Disconnect => self.disconnect(),
        }
    }

    pub(super) fn refresh_threads(&self) {
        let _ = self.threads();
    }

    fn step(&self, command: &str, thread_id: i64) -> Result<(), EngineError> {
        let request = if command == NEXT {
            StepArguments::by_statement(thread_id)
        } else {
            StepArguments::thread(thread_id)
        };
        self.send(command, arguments(command, &request)?)
    }

    fn disconnect(&self) -> Result<(), EngineError> {
        let request = DisconnectArguments {
            restart: Some(false),
            terminate_debuggee: Some(true),
            suspend_debuggee: None,
        };
        self.send(DISCONNECT, arguments(DISCONNECT, &request)?)
    }

    fn send(&self, command: &str, request: Value) -> Result<(), EngineError> {
        self.transport.request(command, request).map(|_| ())
    }
}
