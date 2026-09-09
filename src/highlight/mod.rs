mod capture;
mod edit;
mod errors;
mod fences;
mod locals;
mod markdown;
mod outline;
mod paint;
mod ranges;
mod rust_syntax;
mod session;
mod spans;
mod symbol;
mod syntax;

pub use fences::is_rust_fence;
pub use session::BufferSession;
pub use spans::rust_highlights;
pub use syntax::Lang;
