use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use std::time::Duration;

use serde_json::json;

use crate::ffi::CompletionHit;

use super::clangd::compile_settings;
use super::error::OracleError;
use super::hover::{Hover, hover_of};
use super::items::{Shape, completion_hits};
use super::job::DocText;
use super::lsp::{self, Client, Encoding, document_uri};
use super::server::{Server, language_id};
use super::shared::lock;

const INIT_TIMEOUT: Duration = Duration::from_secs(30);
pub const ASK_TIMEOUT: Duration = Duration::from_millis(1500);

pub struct Sidecar {
    server: Server,
    root: PathBuf,
    client: Client,
    encoding: Encoding,
    docs: Mutex<HashMap<u64, OpenDoc>>,
}

struct OpenDoc {
    uri: String,
    version: u64,
    revision: i32,
}

impl Sidecar {
    pub fn start(
        server: Server,
        program: &Path,
        root: &Path,
        cache: &Path,
    ) -> Result<Self, OracleError> {
        let client = Client::spawn(program, &server.args(root, cache), root)?;
        let params = lsp::initialize(root, server.init_options());
        let init = client.request("initialize", params, INIT_TIMEOUT)?;
        client.notify("initialized", json!({}))?;
        Ok(Self {
            server,
            root: root.to_path_buf(),
            encoding: Encoding::from_capabilities(&init["capabilities"]),
            client,
            docs: Mutex::default(),
        })
    }

    pub fn server(&self) -> Server {
        self.server
    }

    pub fn root(&self) -> &Path {
        &self.root
    }

    pub fn encoding(&self) -> Encoding {
        self.encoding
    }

    pub fn ready(&self) -> bool {
        !self.server.waits_for_load() || self.client.is_quiescent()
    }

    pub fn failure(&self) -> Option<String> {
        self.client.failure()
    }

    pub fn sessions(&self) -> Vec<u64> {
        lock(&self.docs).keys().copied().collect()
    }

    pub fn sync_all(
        &self,
        doc: &DocText,
        stale: &[DocText],
        mut synced: impl FnMut(u64, u64),
    ) -> Result<(), OracleError> {
        let mut docs = lock(&self.docs);
        for other in stale {
            if !docs.contains_key(&other.session_id) {
                continue;
            }
            self.sync(&mut docs, other)?;
            synced(other.session_id, other.version);
        }
        self.sync(&mut docs, doc)?;
        synced(doc.session_id, doc.version);
        Ok(())
    }

    pub fn close(&self, session_id: u64) {
        if let Some(doc) = lock(&self.docs).remove(&session_id) {
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
        let timeout = self.server.completion_timeout();
        let result = self.ask("textDocument/completion", doc, site, timeout)?;
        Ok(completion_hits(&result, shape, self.server.dialect()))
    }

    pub fn hover(&self, doc: &DocText, site: usize) -> Result<Option<Hover>, OracleError> {
        let result = self.ask("textDocument/hover", doc, site, ASK_TIMEOUT)?;
        Ok(hover_of(&result))
    }

    pub fn ask(
        &self,
        method: &str,
        doc: &DocText,
        site: usize,
        timeout: Duration,
    ) -> Result<serde_json::Value, OracleError> {
        let position = lsp::position(&doc.text, site, self.encoding);
        let uri = lock(&self.docs)
            .get(&doc.session_id)
            .map_or_else(|| document_uri(&doc.path), |open| open.uri.clone());
        self.client
            .request(method, lsp::at(&uri, position), timeout)
    }

    fn sync(&self, docs: &mut HashMap<u64, OpenDoc>, doc: &DocText) -> Result<(), OracleError> {
        let uri = document_uri(&doc.path);
        if let Some(open) = docs.get_mut(&doc.session_id)
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
        if let Some(old) = docs.remove(&doc.session_id) {
            let _ = self
                .client
                .notify("textDocument/didClose", lsp::did_close(&old.uri));
        }
        self.configure(doc)?;
        let params = lsp::did_open(&uri, language_id(doc.lang), 1, &doc.text);
        self.client.notify("textDocument/didOpen", params)?;
        docs.insert(
            doc.session_id,
            OpenDoc {
                uri,
                version: doc.version,
                revision: 1,
            },
        );
        Ok(())
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
