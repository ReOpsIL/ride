use std::thread;
use std::time::Duration;

const ROUNDS: u32 = 60;
const DEFAULT_DELAY: u64 = 10;

extern "C" {
    fn fork() -> i32;
    fn waitpid(pid: i32, status: *mut i32, options: i32) -> i32;
}

pub fn run(delay: Option<String>) {
    let delay = delay
        .and_then(|text| text.parse().ok())
        .unwrap_or(DEFAULT_DELAY);
    println!("fork: parent pid {} forks in {delay} s", std::process::id());
    thread::sleep(Duration::from_secs(delay));
    match unsafe { fork() } {
        0 => child(),
        pid if pid > 0 => parent(pid),
        _ => println!("fork: fork failed"),
    }
}

fn parent(child: i32) {
    let mut status = 0;
    unsafe { waitpid(child, &mut status, 0) };
    println!("fork: child {child} exited with {}", (status >> 8) & 0xff);
}

fn child() -> ! {
    println!("fork: child pid {}", std::process::id());
    let mut total = 0;
    for round in 1..=ROUNDS {
        total += child_work(round);
        thread::sleep(Duration::from_millis(500));
    }
    println!("fork: child total={total}");
    std::process::exit(0);
}

fn child_work(round: u32) -> u32 {
    let squared = round * round;
    squared
}
