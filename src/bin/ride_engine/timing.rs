use std::time::Instant;

pub fn timed<T>(repeat: u32, mut run: impl FnMut(u64) -> T) -> T {
    let mut result = run(1);
    let mut timings = Vec::new();
    for i in 2..=repeat.max(1) {
        let start = Instant::now();
        result = run(u64::from(i));
        timings.push(start.elapsed());
    }
    if !timings.is_empty() {
        timings.sort();
        let p50 = timings[timings.len() / 2];
        let p95 = timings[(timings.len() * 95 / 100).min(timings.len() - 1)];
        eprintln!("p50 {p50:?} p95 {p95:?} over {} runs", timings.len());
    }
    result
}
