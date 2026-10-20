pub fn run() {
    let base = 10;
    let doubled = double(base);
    let shifted = offset(doubled, 3);
    let nested = offset(double(base), double(3));
    let total = combine(base, doubled, shifted);
    println!(
        "stepping: base={base} doubled={doubled} shifted={shifted} nested={nested} total={total}"
    );
}

fn double(value: i32) -> i32 {
    let result = value * 2;
    result
}

fn offset(value: i32, by: i32) -> i32 {
    let moved = value + by;
    moved
}

fn combine(a: i32, b: i32, c: i32) -> i32 {
    let partial = double(a) + b;
    let total = offset(partial, c);
    total
}
