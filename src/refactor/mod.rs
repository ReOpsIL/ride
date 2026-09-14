mod extract;
mod name;
mod spans;

#[cfg(test)]
mod tests;

pub use extract::extract_variable;
pub use spans::{ExtractSpans, spans};
