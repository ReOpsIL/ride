use std::sync::Once;

static ONCE: Once = Once::new();

pub fn ignore_sigpipe() {
    ONCE.call_once(install);
}

#[cfg(unix)]
fn install() {
    const SIGPIPE: i32 = 13;
    const SIG_IGN: usize = 1;
    unsafe extern "C" {
        fn signal(signum: i32, handler: usize) -> usize;
    }
    unsafe {
        signal(SIGPIPE, SIG_IGN);
    }
}

#[cfg(not(unix))]
fn install() {}
