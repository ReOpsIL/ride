use std::fs;
use std::path::{Path, PathBuf};

use crate::error::EngineError;

use super::mark::{Mark, now_stamp};

pub fn read_all(root: &Path) -> Vec<Mark> {
    let dir = root.join(".ride/follow");
    let Ok(entries) = fs::read_dir(&dir) else {
        return Vec::new();
    };
    let mut marks = Vec::new();
    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().and_then(|ext| ext.to_str()) != Some("toml") {
            continue;
        }
        if let Ok(text) = fs::read_to_string(&path) {
            marks.extend(parse(&text));
        }
    }
    marks.sort_by(|left, right| left.id.cmp(&right.id));
    marks
}

pub fn upsert(root: &Path, author: &str, agent: bool, mark: Mark) -> Result<(), EngineError> {
    let path = file_path(root, author)?;
    let mut marks = read_author(&path);
    if let Some(slot) = marks
        .iter_mut()
        .find(|have| have.id == mark.id || same_slot(have, &mark))
    {
        let id = slot.id.clone();
        *slot = mark;
        slot.id = id;
        slot.author = author.to_string();
        slot.agent = agent;
    } else {
        let mut mark = mark;
        mark.author = author.to_string();
        mark.agent = agent;
        if mark.at.is_empty() {
            mark.at = now_stamp();
        }
        marks.push(mark);
    }
    marks.sort_by(|left, right| left.id.cmp(&right.id));
    write(&path, author, agent, &marks)
}

pub fn drop(root: &Path, author: &str, id: &str) -> Result<(), EngineError> {
    let path = file_path(root, author)?;
    let mut marks = read_author(&path);
    let agent = marks.first().is_some_and(|mark| mark.agent);
    marks.retain(|mark| mark.id != id);
    write(&path, author, agent, &marks)
}

fn same_slot(have: &Mark, mark: &Mark) -> bool {
    have.path == mark.path
        && have.item == mark.item
        && have.kind == mark.kind
        && have.mark == mark.mark
}

fn file_path(root: &Path, author: &str) -> Result<PathBuf, EngineError> {
    let Some(author) = super::mark::slug(author) else {
        return Err(EngineError::git("git user.name is empty"));
    };
    Ok(root.join(".ride/follow").join(format!("{author}.toml")))
}

fn read_author(path: &Path) -> Vec<Mark> {
    fs::read_to_string(path)
        .map(|text| parse(&text))
        .unwrap_or_default()
}

fn write(path: &Path, author: &str, agent: bool, marks: &[Mark]) -> Result<(), EngineError> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|err| EngineError::io(parent, err))?;
    }
    fs::write(path, render(author, agent, marks)).map_err(|err| EngineError::io(path, err))
}

pub fn parse(text: &str) -> Vec<Mark> {
    let Ok(value) = toml::from_str::<toml::Value>(text) else {
        return Vec::new();
    };
    let Some(table) = value.as_table() else {
        return Vec::new();
    };
    let (author, agent) = table.get("author").map(author_of).unwrap_or_default();
    let Some(list) = table.get("mark").and_then(toml::Value::as_array) else {
        return Vec::new();
    };
    list.iter()
        .filter_map(|entry| mark_of(entry, &author, agent))
        .collect()
}

fn author_of(value: &toml::Value) -> (String, bool) {
    let Some(table) = value.as_table() else {
        return (String::new(), false);
    };
    let name = table
        .get("name")
        .and_then(toml::Value::as_str)
        .unwrap_or("")
        .to_string();
    let agent = table
        .get("agent")
        .and_then(toml::Value::as_bool)
        .unwrap_or(false);
    (name, agent)
}

fn mark_of(value: &toml::Value, author: &str, agent: bool) -> Option<Mark> {
    let table = value.as_table()?;
    let field = |key: &str| {
        table
            .get(key)
            .and_then(toml::Value::as_str)
            .unwrap_or("")
            .to_string()
    };
    Some(Mark {
        id: field("id"),
        author: author.to_string(),
        agent,
        path: field("path"),
        item: field("item"),
        kind: field("kind"),
        mark: field("mark"),
        note: field("note"),
        basis: field("basis"),
        commit: field("commit"),
        at: field("at"),
        re: field("re"),
        accepted: table
            .get("accepted")
            .and_then(toml::Value::as_bool)
            .unwrap_or(false),
    })
}

fn render(author: &str, agent: bool, marks: &[Mark]) -> String {
    let mut out = format!("[author]\nname = {}\nagent = {agent}\n", toml_str(author));
    for mark in marks {
        out.push_str("\n[[mark]]\n");
        line(&mut out, "id", &mark.id);
        line(&mut out, "path", &mark.path);
        line(&mut out, "item", &mark.item);
        line(&mut out, "kind", &mark.kind);
        line(&mut out, "mark", &mark.mark);
        line(&mut out, "note", &mark.note);
        line(&mut out, "basis", &mark.basis);
        line(&mut out, "commit", &mark.commit);
        line(&mut out, "at", &mark.at);
        if !mark.re.is_empty() {
            line(&mut out, "re", &mark.re);
        }
        if mark.accepted {
            out.push_str("accepted = true\n");
        }
    }
    out
}

fn line(out: &mut String, key: &str, value: &str) {
    out.push_str(key);
    out.push_str(" = ");
    out.push_str(&toml_str(value));
    out.push('\n');
}

fn toml_str(value: &str) -> String {
    let mut out = String::from("\"");
    for ch in value.chars() {
        match ch {
            '\\' => out.push_str("\\\\"),
            '"' => out.push_str("\\\""),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            ch => out.push(ch),
        }
    }
    out.push('"');
    out
}
