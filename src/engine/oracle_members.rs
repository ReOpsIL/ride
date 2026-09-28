use std::sync::Arc;

use crate::ffi::{CompletionHit, CompletionQuery, CompletionResponse};
use crate::highlight::{BufferSession, Lang, Site, SiteAt};
use crate::oracle::{DocText, MemberJob, MemberKey};

use super::{Inner, merge};

pub fn lookup(
    i: &Inner,
    session_id: u64,
    session: &BufferSession,
    at: &SiteAt,
) -> Option<Arc<[CompletionHit]>> {
    if session.lang() != Lang::Rust || !matches!(at.site, Site::MemberAccess) {
        return None;
    }
    let path = session.path()?;
    let key = MemberKey::new(session_id, session.replica(), at.replace_start)?;
    if let Some(members) = i.oracle.members(&key) {
        return Some(members);
    }
    if i.oracle.wants(&key) {
        i.oracle.request(MemberJob {
            key,
            doc: doc_text(session_id, session, path),
            stale: stale_docs(i, session_id),
        });
    }
    None
}

pub fn hits(
    members: &[CompletionHit],
    q: &CompletionQuery,
    next_char: Option<char>,
) -> CompletionResponse {
    let prefix = q.prefix.to_ascii_lowercase();
    let mut pool: Vec<CompletionHit> = members
        .iter()
        .filter(|h| h.name.to_ascii_lowercase().starts_with(&prefix))
        .cloned()
        .map(|hit| match next_char {
            Some('(') => plain(hit),
            _ => hit,
        })
        .collect();
    merge::keep_order(&mut pool, &q.prefix);
    merge::finish(q, pool, false)
}

fn plain(mut hit: CompletionHit) -> CompletionHit {
    hit.insert_text = hit.name.clone();
    hit.snippet = false;
    hit
}

fn doc_text(session_id: u64, session: &BufferSession, path: &std::path::Path) -> DocText {
    DocText {
        session_id,
        path: path.to_path_buf(),
        version: session.text_version(),
        text: session.replica().to_string(),
    }
}

fn stale_docs(i: &Inner, except: u64) -> Vec<DocText> {
    i.sessions
        .iter()
        .filter(|(id, _)| **id != except)
        .filter_map(|(id, session)| {
            let synced = i.oracle.synced_version(*id)?;
            let path = session.path()?;
            (synced != session.text_version()).then(|| doc_text(*id, session, path))
        })
        .collect()
}
