use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::error::EngineError;

pub const REQUEST: &str = "request";
pub const RESPONSE: &str = "response";
pub const EVENT: &str = "event";

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Request {
    pub seq: i64,
    #[serde(rename = "type")]
    pub kind: String,
    pub command: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub arguments: Option<Value>,
}

impl Request {
    pub fn new(seq: i64, command: &str, arguments: Option<Value>) -> Self {
        Self {
            seq,
            kind: REQUEST.to_string(),
            command: command.to_string(),
            arguments,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Response {
    pub seq: i64,
    #[serde(rename = "type")]
    pub kind: String,
    #[serde(rename = "request_seq")]
    pub request_seq: i64,
    pub success: bool,
    pub command: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub body: Option<Value>,
}

impl Response {
    pub fn body_as<T: DeserializeOwned>(&self) -> Result<T, EngineError> {
        let body = self.body.clone().unwrap_or(Value::Null);
        serde_json::from_value(body).map_err(|err| EngineError::Tool {
            message: format!("dap {} body: {err}", self.command),
        })
    }

    pub fn failure(&self) -> Option<String> {
        if self.success {
            return None;
        }
        let detail = self
            .body_as::<ErrorBody>()
            .ok()
            .and_then(|body| body.error)
            .map(|error| error.format);
        Some(
            detail
                .or_else(|| self.message.clone())
                .unwrap_or_else(|| self.command.clone()),
        )
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Event {
    pub seq: i64,
    #[serde(rename = "type")]
    pub kind: String,
    pub event: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub body: Option<Value>,
}

impl Event {
    pub fn body_as<T: DeserializeOwned>(&self) -> Result<T, EngineError> {
        let body = self.body.clone().unwrap_or(Value::Null);
        serde_json::from_value(body).map_err(|err| EngineError::Tool {
            message: format!("dap {} event: {err}", self.event),
        })
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ErrorBody {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<ErrorMessage>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ErrorMessage {
    pub id: i64,
    pub format: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_user: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub send_telemetry: Option<bool>,
}
