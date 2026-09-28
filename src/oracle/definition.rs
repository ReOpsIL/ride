use super::error::OracleError;
use super::job::DocText;
use super::lsp::{Spot, spots};
use super::server::Server;
use super::sidecar::{ASK_TIMEOUT, Sidecar};
use super::target::{Target, targets};

const MAX_IMPLEMENTATIONS: usize = 8;

pub fn gather(
    sidecar: &Sidecar,
    doc: &DocText,
    site: usize,
    stale: &[DocText],
) -> Result<Vec<Target>, OracleError> {
    let ask = |method: &str| {
        sidecar
            .ask(method, doc, site, ASK_TIMEOUT)
            .map(|r| spots(&r))
    };
    let mut found = ask("textDocument/definition")?;
    match sidecar.server() {
        Server::Clangd => add(&mut found, ask("textDocument/declaration")?),
        Server::RustAnalyzer if in_project(sidecar, &found) => {
            let implementations = ask("textDocument/implementation")?;
            add(
                &mut found,
                implementations
                    .into_iter()
                    .take(MAX_IMPLEMENTATIONS)
                    .collect(),
            );
        }
        Server::RustAnalyzer => {}
    }
    let known: Vec<&DocText> = std::iter::once(doc).chain(stale).collect();
    Ok(targets(found, sidecar.encoding(), &known))
}

fn in_project(sidecar: &Sidecar, found: &[Spot]) -> bool {
    !found.is_empty() && found.iter().all(|s| s.path.starts_with(sidecar.root()))
}

fn add(found: &mut Vec<Spot>, more: Vec<Spot>) {
    for spot in more {
        if !found.contains(&spot) {
            found.push(spot);
        }
    }
}
