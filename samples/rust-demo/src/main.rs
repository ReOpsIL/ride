mod util;

use std::collections::HashMap;

use util::{Counter, Recorder};

/// Records a few events and prints the totals.
fn main() {
    let mut counter = Counter::new();
    counter.record("ride");
    counter.record("engine");
    println!("ride: {}", counter.count("ride"));
    let mut totals: HashMap<&str, u32> = HashMap::new();
    totals.insert("ride", counter.count("ride"));
    totals.insert("engine", counter.count("engine"));
    for (name, total) in &totals {
        println!("{name}: {total}");
    }
    println!("events: {}", totals.values().sum::<u32>());
}
