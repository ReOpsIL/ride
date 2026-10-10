mod idle;
mod piped;
mod sigpipe;

pub use idle::{IdleError, output_idle};
pub use piped::run_piped;
pub use sigpipe::ignore_sigpipe;
