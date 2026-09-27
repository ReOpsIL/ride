use std::path::Path;

use sha2::{Digest, Sha256};

use crate::digest::{hex, sha256_hex};
use crate::discover::DiscoveredCrate;
use crate::extract::EXTRACTOR_VERSION;

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
            hash: crate_hash(&crate_.path, EXTRACTOR_VERSION),
            crate_,
        })
        .collect()
}

fn crate_hash(path: &Path, extractor: u32) -> String {
    sha256_hex(&[&extractor.to_le_bytes(), content_hash(path).as_bytes()])
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

#[cfg(test)]
mod tests {
    use super::crate_hash;
    use std::path::Path;

    #[test]
    fn crate_hash_changes_with_the_extractor_version() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/sample_crate");
        assert_eq!(crate_hash(&root, 1), crate_hash(&root, 1));
        assert_ne!(crate_hash(&root, 1), crate_hash(&root, 2));
    }
}
