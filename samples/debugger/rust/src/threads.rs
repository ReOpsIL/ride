use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

pub fn run() {
    let shared = Arc::new(Mutex::new(0u64));
    let workers: Vec<_> = (0..3)
        .map(|id| {
            let shared = Arc::clone(&shared);
            thread::Builder::new()
                .name(format!("worker-{id}"))
                .spawn(move || work(id, &shared))
        })
        .collect();
    for handle in workers.into_iter().flatten() {
        let _ = handle.join();
    }
    let total = shared.lock().map(|value| *value).unwrap_or(0);
    println!("threads: total={total}");
}

fn work(id: u64, shared: &Mutex<u64>) {
    for round in 0..3 {
        let contribution = id * 10 + round;
        if let Ok(mut value) = shared.lock() {
            *value += contribution;
        }
        thread::sleep(Duration::from_millis(50));
    }
}
