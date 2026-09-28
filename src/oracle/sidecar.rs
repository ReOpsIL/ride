use std::collections::HashMap;
use std::path::Path;
use std::time::Duration;

use serde_json::json;

use crate::ffi::CompletionHit;

use super::error::OracleError;
use super::items::{Shape, completion_hits};
use super::job::DocText;
use super::lsp::{self, Client, Encoding, document_uri};

const INIT_TIMEOUT: Duration = Duration::from_secs(30);
const COMPLETION_TIMEOUT: Duration = Duration::from_secs(5);

pub struct Sidecar {
    client: Client,
    encoding: Encoding,
    docs: HashMap<u64, OpenDoc>,
}

struct OpenDoc {
    uri: String,
    version: u64,
    revision: i32,
}

impl Sidecar {
    pub fn start(program: &Path, root: &Path) -> Result<Self, OracleError> {
        let client = Client::spawn(program, root)?;
        let init = client.request("initialize", lsp::initialize(root), INIT_TIMEOUT)?;
        client.notify("initialized", json!({}))?;
        Ok(Self {
            encoding: Encoding::from_capabilities(&init["capabilities"]),
            client,
            docs: HashMap::new(),
        })
    }

    pub fn ready(&self) -> bool {
        self.client.is_quiescent()
    }

    pub fn failure(&self) -> Option<String> {
        self.client.failure()
    }

    pub fn holds(&self, session_id: u64) -> bool {
        self.docs.contains_key(&session_id)
    }

    pub fn sessions(&self) -> impl Iterator<Item = u64> + '_ {
        self.docs.keys().copied()
    }

    pub fn sync(&mut self, doc: &DocText) -> Result<(), OracleError> {
        let uri = document_uri(&doc.path);
        if let Some(open) = self.docs.get_mut(&doc.session_id)
            && open.uri == uri
        {
            if open.version == doc.version {
                return Ok(());
            }
            open.version = doc.version;
            open.revision += 1;
            let params = lsp::did_change(&uri, open.revision, &doc.text);
            return self.client.notify("textDocument/didChange", params);
        }
        self.close(doc.session_id);
        self.client
            .notify("textDocument/didOpen", lsp::did_open(&uri, 1, &doc.text))?;
        self.docs.insert(
            doc.session_id,
            OpenDoc {
                uri,
                version: doc.version,
                revision: 1,
            },
        );
        Ok(())
    }

    pub fn close(&mut self, session_id: u64) {
        if let Some(doc) = self.docs.remove(&session_id) {
            let _ = self
                .client
                .notify("textDocument/didClose", lsp::did_close(&doc.uri));
        }
    }

    pub fn complete(
        &self,
        doc: &DocText,
        site: usize,
        shape: Shape,
    ) -> Result<Vec<CompletionHit>, OracleError> {
        let position = lsp::position(&doc.text, site, self.encoding);
        let uri = self
            .docs
            .get(&doc.session_id)
            .map_or_else(|| document_uri(&doc.path), |open| open.uri.clone());
        let params = lsp::completion(&uri, position);
        let result = self
            .client
            .request("textDocument/completion", params, COMPLETION_TIMEOUT)?;
        Ok(completion_hits(&result, shape))
    }
}
