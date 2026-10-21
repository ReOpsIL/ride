pub fn run() {
    let fact = factorial(8);
    let fib = fibonacci(10);
    let even = is_even(7);
    println!("recursion: 8! = {fact}, fib(10) = {fib}, 7 even = {even}");
}

fn factorial(n: u64) -> u64 {
    if n <= 1 {
        return 1;
    }
    let below = factorial(n - 1);
    n * below
}

fn fibonacci(n: u32) -> u64 {
    if n < 2 {
        return n as u64;
    }
    fibonacci(n - 1) + fibonacci(n - 2)
}

fn is_even(n: u32) -> bool {
    if n == 0 {
        return true;
    }
    is_odd(n - 1)
}

fn is_odd(n: u32) -> bool {
    if n == 0 {
        return false;
    }
    is_even(n - 1)
}
