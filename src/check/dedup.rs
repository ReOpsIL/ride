use std::collections::HashSet;

use crate::ffi::Diagnostic;

#[derive(Default)]
pub struct Seen(HashSet<(String, u32, String)>);

impl Seen {
    pub fn accepts(&mut self, diagnostic: &Diagnostic) -> bool {
        self.0.insert((
            diagnostic.path.clone(),
            diagnostic.byte_start,
            diagnostic.message.clone(),
        ))
    }
}
