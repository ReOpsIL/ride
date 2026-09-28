use std::sync::Arc;

use crate::ffi::CompletionHit;
use crate::highlight::{BufferSession, Lang, Site, SiteAt};
use crate::oracle::{DocText, Shape, SiteJob, SiteKey};

use super::Inner;

pub fn lookup(
    i: &Inner,
    session_id: u64,
    session: &BufferSession,
    at: &SiteAt,
) -> Option<Arc<[CompletionHit]>> {
    let shape = shape_of(&at.site)
        .filter(|_| matches!(session.lang(), Lang::Rust | Lang::C | Lang::Cpp))?;
    let path = session.path()?;
    let key = SiteKey::new(session_id, session.replica(), at.replace_start)?;
    if let Some(hits) = i.oracle.hits(&key) {
        return Some(hits);
    }
    if i.oracle.wants(&key) {
        i.oracle.request(SiteJob {
            key,
            shape,
            doc: doc_text(session_id, session, path),
            stale: stale_docs(i, session_id),
        });
    }
    None
}

fn shape_of(site: &Site) -> Option<Shape> {
    match site {
        Site::MemberAccess => Some(Shape::Members),
        Site::Identifier(_) | Site::ScopedPath(_) | Site::UsePath(_) => Some(Shape::Scope),
        _ => None,
    }
}

pub fn doc_text(session_id: u64, session: &BufferSession, path: &std::path::Path) -> DocText {
    DocText {
        session_id,
        lang: session.lang(),
        path: path.to_path_buf(),
        version: session.text_version(),
        text: session.replica().to_string(),
    }
}

pub fn stale_docs(i: &Inner, except: u64) -> Vec<DocText> {
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
