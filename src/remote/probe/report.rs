use std::path::Path;

use super::super::endpoint::Endpoint;
use super::check::Check;
use super::command::MARK;
use super::hint;
use super::tools::{self, Tool};

const SHOWN_LINES: usize = 6;

pub fn read(endpoint: &Endpoint, output: &str) -> Vec<Check> {
    let marked: Vec<&str> = output
        .lines()
        .filter_map(|line| line.strip_prefix(MARK))
        .map(str::trim)
        .collect();
    let Some(login) = field(&marked, "login") else {
        return vec![Check::fail("Connect", unreachable(output))];
    };
    let mut checks = vec![connected(login), root(endpoint.remote_root(), &marked)];
    checks.extend(
        tools::needed(endpoint.local_root())
            .into_iter()
            .map(|tool| found(tool, &marked)),
    );
    checks
}

fn field<'a>(marked: &[&'a str], key: &str) -> Option<&'a str> {
    marked.iter().find_map(|line| {
        let (head, rest) = line.split_once(' ').unwrap_or((line, ""));
        (head == key).then_some(rest)
    })
}

fn unreachable(output: &str) -> String {
    let said: Vec<&str> = output
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .collect();
    let tail = &said[said.len().saturating_sub(SHOWN_LINES)..];
    if tail.is_empty() {
        return hint::explain(output).to_string();
    }
    format!("{}\n{}", hint::explain(output), tail.join("\n"))
}

fn connected(login: &str) -> Check {
    match login.split_once(' ') {
        Some((user, system)) => Check::pass("Connect", format!("Signed in as {user} on {system}.")),
        None => Check::pass("Connect", format!("Signed in as {login}.")),
    }
}

fn root(remote: &Path, marked: &[&str]) -> Check {
    let shown = remote.display();
    let Some(state) = field(marked, "root") else {
        return Check::fail(
            "Remote Root",
            format!("The remote did not report on {shown}."),
        );
    };
    let (word, parent) = state.split_once(' ').unwrap_or((state, ""));
    match word {
        "ready" => Check::pass("Remote Root", format!("{shown} exists and is writable.")),
        "create" => Check::pass(
            "Remote Root",
            format!("{shown} does not exist yet. The first sync creates it under {parent}."),
        ),
        "readonly" => Check::fail(
            "Remote Root",
            format!("{shown} exists, but this user cannot write to it."),
        ),
        _ => Check::fail(
            "Remote Root",
            format!("{shown} cannot be created: {parent} is not writable by this user."),
        ),
    }
}

fn found(tool: Tool, marked: &[&str]) -> Check {
    let path = marked.iter().find_map(|line| {
        let rest = line.strip_prefix("tool ")?;
        let (name, path) = rest.split_once(' ').unwrap_or((rest, ""));
        (name == tool.name).then_some(path.trim())
    });
    match path {
        Some(path) if !path.is_empty() => Check::pass(tool.name, path),
        _ => {
            let detail = format!(
                "Not on the PATH of a non-interactive SSH shell. It {}.",
                tool.purpose
            );
            if tool.required {
                Check::fail(tool.name, detail)
            } else {
                Check::warn(tool.name, detail)
            }
        }
    }
}
