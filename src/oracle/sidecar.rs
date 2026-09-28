use std::collections::HashMap;
use std::path::Path;
use std::time::Duration;

use serde_json::json;

use crate::ffi::CompletionHit;

use super::clangd::compile_settings;
use super::error::OracleError;
use super::items::{Shape, completion_hits};
use super::job::DocText;
use super::lsp::{self, Client, Encoding, document_uri};
use super::server::{Server, language_id};

const INIT_TIMEOUT: Duration = Duration::from_secs(30);

pub struct Sidecar {
    server: Server,
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
    pub fn start(server: Server, program: &Path, root: &Path) -> Result<Self, OracleError> {
        let client = Client::spawn(program, server.args(), root)?;
        let params = lsp::initialize(root, server.init_options());
        let init = client.request("initialize", params, INIT_TIMEOUT)?;
        client.notify("initialized", json!({}))?;
        Ok(Self {
            server,
            encoding: Encoding::from_capabilities(&init["capabilities"]),
            client,
            docs: HashMap::new(),
        })
    }

    pub fn ready(&self) -> bool {
        !self.server.waits_for_load() || self.client.is_quiescent()
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
        self.configure(doc)?;
        let params = lsp::did_open(&uri, language_id(doc.lang), 1, &doc.text);
        self.client.notify("textDocument/didOpen", params)?;
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
        let timeout = self.server.completion_timeout();
        let result = self
            .client
            .request("textDocument/completion", params, timeout)?;
        Ok(completion_hits(&result, shape, self.server.dialect()))
    }

    fn configure(&self, doc: &DocText) -> Result<(), OracleError> {
        if self.server != Server::Clangd {
            return Ok(());
        }
        let path = std::fs::canonicalize(&doc.path).unwrap_or_else(|_| doc.path.clone());
        match compile_settings(&path, doc.lang) {
            Some(settings) => self
                .client
                .notify("workspace/didChangeConfiguration", settings),
            None => Ok(()),
        }
    }
}
