use std::thread;
use std::time::Duration;

pub fn run() {
    let beats = 40;
    for beat in 1..=beats {
        println!("heartbeat {beat}/{beats}");
        thread::sleep(Duration::from_millis(500));
    }
}
