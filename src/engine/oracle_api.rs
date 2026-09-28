use std::sync::Arc;

use crate::ffi::{OracleListener, OracleStatus};
use crate::oracle::Oracle;

use super::Engine;

#[uniffi::export]
impl Engine {
    pub fn set_oracle_enabled(&self, enabled: bool) {
        if let Some(oracle) = self.oracle() {
            oracle.set_enabled(enabled);
        }
    }

    pub fn oracle_status(&self) -> OracleStatus {
        self.oracle().map(|o| o.status()).unwrap_or_default()
    }

    pub fn set_oracle_listener(&self, listener: Arc<dyn OracleListener>) {
        if let Some(oracle) = self.oracle() {
            oracle.listen(listener);
        }
    }
}

impl Engine {
    fn oracle(&self) -> Option<Arc<Oracle>> {
        self.read(|i| Arc::clone(&i.oracle)).ok()
    }
}
