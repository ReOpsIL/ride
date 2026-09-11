use std::fs;
use std::path::{Path, PathBuf};

use serde::Deserialize;

use crate::error::EngineError;

const QUERY: &str = r#"{"requests":[{"kind":"codemodel","version":2}]}"#;
const CLIENT: &str = "client-ride";

#[derive(Deserialize)]
pub struct Artifact {
    pub path: String,
}

#[derive(Deserialize)]
pub struct Source {
    pub path: String,
}

#[derive(Deserialize)]
pub struct TargetJson {
    pub name: String,
    #[serde(rename = "type")]
    pub kind: String,
    #[serde(default)]
    pub artifacts: Vec<Artifact>,
    #[serde(default)]
    pub sources: Vec<Source>,
}

#[derive(Deserialize)]
struct CodeModel {
    configurations: Vec<Configuration>,
}

#[derive(Deserialize)]
struct Configuration {
    name: String,
    targets: Vec<TargetRef>,
}

#[derive(Deserialize)]
struct TargetRef {
    #[serde(rename = "jsonFile")]
    json_file: String,
}

pub fn write_query(build: &Path) -> Result<(), EngineError> {
    let dir = build.join(".cmake/api/v1/query").join(CLIENT);
    fs::create_dir_all(&dir).map_err(|e| EngineError::io(&dir, e))?;
    let path = dir.join("query.json");
    fs::write(&path, QUERY).map_err(|e| EngineError::io(&path, e))
}

pub fn read_targets(build: &Path, profile: &str) -> Result<Vec<TargetJson>, EngineError> {
    let reply = build.join(".cmake/api/v1/reply");
    let model: CodeModel = parse(&reply.join(codemodel_name(&reply)?))?;
    let configuration = model
        .configurations
        .iter()
        .find(|c| c.name == profile)
        .or_else(|| model.configurations.first())
        .ok_or_else(|| EngineError::io(&reply, "no cmake configuration in the codemodel"))?;
    configuration
        .targets
        .iter()
        .map(|t| parse(&reply.join(&t.json_file)))
        .collect()
}

fn codemodel_name(reply: &Path) -> Result<String, EngineError> {
    let index: serde_json::Value = parse(&latest_index(reply)?)?;
    index["reply"][CLIENT]["query.json"]["responses"]
        .as_array()
        .and_then(|responses| {
            responses
                .iter()
                .find(|r| r["kind"] == "codemodel")
                .and_then(|r| r["jsonFile"].as_str())
        })
        .map(str::to_string)
        .ok_or_else(|| EngineError::io(reply, "no codemodel reply for client-ride"))
}

fn latest_index(reply: &Path) -> Result<PathBuf, EngineError> {
    fs::read_dir(reply)
        .map_err(|e| EngineError::io(reply, e))?
        .filter_map(|entry| entry.ok().map(|entry| entry.path()))
        .filter(|path| {
            path.file_name()
                .and_then(|name| name.to_str())
                .is_some_and(|name| name.starts_with("index-") && name.ends_with(".json"))
        })
        .max()
        .ok_or_else(|| EngineError::io(reply, "no cmake file api index"))
}

fn parse<T: serde::de::DeserializeOwned>(path: &Path) -> Result<T, EngineError> {
    let text = fs::read_to_string(path).map_err(|e| EngineError::io(path, e))?;
    serde_json::from_str(&text).map_err(|e| EngineError::io(path, e))
}
