mod language;
mod program;
mod types;
mod values;

use super::super::load::Files;
use super::join::{count, flatten};

const PARTS: &[Files] = &[language::FILES, types::FILES, values::FILES, program::FILES];

const LEN: usize = count(PARTS);
const OWNED: [(&str, &str); LEN] = flatten::<LEN>(PARTS);

pub const FILES: Files = &OWNED;
