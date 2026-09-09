use std::path::Path;

use sha2::{Digest, Sha256};

use crate::discover::DiscoveredCrate;

use super::hash::content_hash;
use super::schema::SCHEMA_VERSION;

pub struct HashedCrate {
    pub crate_: DiscoveredCrate,
    pub hash: String,
}

pub fn hash_crates(crates: Vec<DiscoveredCrate>) -> Vec<HashedCrate> {
    crates
        .into_iter()
        .map(|crate_| HashedCrate {
            hash: content_hash(&crate_.path),
            crate_,
        })
        .collect()
}

pub fn fingerprint(hashed: &[HashedCrate]) -> String {
    let mut hasher = Sha256::new();
    hasher.update(SCHEMA_VERSION.to_le_bytes());
    hasher.update(env!("CARGO_PKG_VERSION").as_bytes());
    for h in hashed {
        hasher.update(key_bytes(&h.crate_.path));
        hasher.update(h.crate_.name.as_bytes());
        hasher.update(h.crate_.version.as_bytes());
        hasher.update(h.hash.as_bytes());
        hasher.update([0]);
    }
    hex(&hasher.finalize())
}

fn key_bytes(path: &Path) -> Vec<u8> {
    path.to_string_lossy().into_owned().into_bytes()
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().fold(String::new(), |mut out, b| {
        use std::fmt::Write;
        let _ = write!(out, "{b:02x}");
        out
    })
}
