mod binds;
mod boundary;
mod capture;
mod constant;
mod declare;
mod extract;
mod inline;
mod literal;
mod literal_type;
mod local;
mod name;
mod position;
mod spans;
mod tree;
mod uses;

#[cfg(test)]
mod tests;
#[cfg(test)]
mod tests_apply;
#[cfg(test)]
mod tests_boundary;
#[cfg(test)]
mod tests_constant;
#[cfg(test)]
mod tests_constant_types;
#[cfg(test)]
mod tests_inline;
#[cfg(test)]
mod tests_inline_scope;

pub use constant::introduce_constant;
pub use extract::extract_variable;
pub use inline::inline_variable;
pub use literal::{ConstantSpans, constant_spans};
pub use local::{InlineSpans, inline_spans};
pub use spans::{ExtractSpans, spans};
