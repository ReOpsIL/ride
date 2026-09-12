use serde::Serialize;
use serde::de::DeserializeOwned;
use serde_json::Value;

use crate::error::EngineError;
use crate::ffi::{DebugEvaluateContext, DebugThread, Scope, StackFrame, Variable};

use crate::debug::protocol::{self, EvaluateContext};

pub fn arguments<T: Serialize>(command: &str, value: &T) -> Result<Value, EngineError> {
    serde_json::to_value(value)
        .map_err(|err| EngineError::debug(format!("{command} arguments: {err}")))
}

pub fn body<T: DeserializeOwned>(command: &str, value: Value) -> Result<T, EngineError> {
    serde_json::from_value(value)
        .map_err(|err| EngineError::debug(format!("{command} body: {err}")))
}

pub fn thread(source: protocol::Thread) -> DebugThread {
    DebugThread {
        id: source.id,
        name: source.name,
    }
}

pub fn frame(source: protocol::StackFrame) -> StackFrame {
    StackFrame {
        path: source.path().map(str::to_string),
        id: source.id,
        name: source.name,
        line: source.line,
        column: source.column,
    }
}

pub fn scope(source: protocol::Scope) -> Scope {
    Scope {
        name: source.name,
        variables_reference: source.variables_reference,
        expensive: source.expensive.unwrap_or(false),
    }
}

pub fn variable(source: protocol::Variable) -> Variable {
    Variable {
        children_count: source.children_count(),
        name: source.name,
        value: source.value,
        type_name: source.type_name,
        variables_reference: source.variables_reference,
    }
}

pub fn evaluated(source: protocol::EvaluateResponseBody, expression: &str) -> Variable {
    let children = source.named_variables.unwrap_or(0) + source.indexed_variables.unwrap_or(0);
    Variable {
        name: expression.to_string(),
        value: source.result,
        type_name: source.type_name,
        variables_reference: source.variables_reference,
        children_count: children,
    }
}

pub fn context(source: DebugEvaluateContext) -> EvaluateContext {
    match source {
        DebugEvaluateContext::Watch => EvaluateContext::Watch,
        DebugEvaluateContext::Hover => EvaluateContext::Hover,
        DebugEvaluateContext::Repl => EvaluateContext::Repl,
        DebugEvaluateContext::Variables => EvaluateContext::Variables,
    }
}
