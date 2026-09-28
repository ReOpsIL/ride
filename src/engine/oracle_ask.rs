use std::sync::Arc;

use crate::highlight::Lang;
use crate::oracle::{DocText, Oracle};

use super::Inner;
use super::oracle_sites::{doc_text, stale_docs};

pub struct Ask {
    pub oracle: Arc<Oracle>,
    pub doc: DocText,
    pub stale: Vec<DocText>,
}

pub fn ask(i: &Inner, session_id: u64) -> Option<Ask> {
    let session = i.sessions.get(&session_id)?;
    if !matches!(session.lang(), Lang::Rust | Lang::C | Lang::Cpp) {
        return None;
    }
    let path = session.path()?;
    Some(Ask {
        oracle: Arc::clone(&i.oracle),
        doc: doc_text(session_id, session, path),
        stale: stale_docs(i, session_id),
    })
}
