pub fn run() {
    let mut sum = 0u64;
    let mut checkpoints = Vec::new();
    for i in 0..100u64 {
        let square = i * i;
        sum += square;
        if i % 10 == 0 {
            checkpoints.push(square);
        }
    }
    let mut countdown = 5;
    while countdown > 0 {
        countdown -= 1;
    }
    let evens: Vec<u64> = (0..20)
        .filter(|n| {
            let keep = n % 2 == 0;
            keep
        })
        .map(|n| {
            let tripled = n * 3;
            tripled
        })
        .collect();
    println!(
        "loops: sum={sum} checkpoints={checkpoints:?} countdown={countdown} evens={}",
        evens.len()
    );
}
