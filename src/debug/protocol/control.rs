use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum SteppingGranularity {
    Statement,
    Line,
    Instruction,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ContinueArguments {
    pub thread_id: i64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub single_thread: Option<bool>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ContinueResponseBody {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub all_threads_continued: Option<bool>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StepArguments {
    pub thread_id: i64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub single_thread: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub granularity: Option<SteppingGranularity>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub target_id: Option<i64>,
}

impl StepArguments {
    pub fn thread(thread_id: i64) -> Self {
        Self {
            thread_id,
            single_thread: None,
            granularity: None,
            target_id: None,
        }
    }

    pub fn by_statement(thread_id: i64) -> Self {
        Self {
            granularity: Some(SteppingGranularity::Statement),
            ..Self::thread(thread_id)
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PauseArguments {
    pub thread_id: i64,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ConfigurationDoneArguments {}

pub const CONTINUE: &str = "continue";
pub const NEXT: &str = "next";
pub const STEP_IN: &str = "stepIn";
pub const STEP_OUT: &str = "stepOut";
pub const PAUSE: &str = "pause";
pub const CONFIGURATION_DONE: &str = "configurationDone";
