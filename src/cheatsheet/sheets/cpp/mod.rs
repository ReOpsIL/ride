mod language;
mod library;
mod runtime;
mod types;

use super::super::load::Files;
use super::join::{count, flatten};

const PARTS: &[Files] = &[
    language::FILES,
    types::FILES,
    library::FILES,
    runtime::FILES,
];

const LEN: usize = count(PARTS);
const OWNED: [(&str, &str); LEN] = flatten::<LEN>(PARTS);

pub const FILES: Files = &OWNED;
