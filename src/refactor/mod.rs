mod constant;
mod extract;
mod indent;
mod inline;
mod literal;
mod local;
mod name;
mod spans;

#[cfg(test)]
mod tests;
#[cfg(test)]
mod tests_apply;
#[cfg(test)]
mod tests_constant;
#[cfg(test)]
mod tests_inline;

pub use constant::introduce_constant;
pub use extract::extract_variable;
pub use inline::inline_variable;
pub use literal::{ConstantSpans, constant_spans};
pub use local::{InlineSpans, inline_spans};
pub use spans::{ExtractSpans, spans};
