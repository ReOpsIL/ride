#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

#include "scenarios.h"

static uint64_t factorial(uint64_t n) {
    if (n <= 1) {
        return 1;
    }
    uint64_t below = factorial(n - 1);
    return n * below;
}

static uint64_t fibonacci(unsigned n) {
    if (n < 2) {
        return n;
    }
    return fibonacci(n - 1) + fibonacci(n - 2);
}

static bool is_odd(unsigned n);

static bool is_even(unsigned n) {
    if (n == 0) {
        return true;
    }
    return is_odd(n - 1);
}

static bool is_odd(unsigned n) {
    if (n == 0) {
        return false;
    }
    return is_even(n - 1);
}

void lab_recursion(void) {
    uint64_t fact = factorial(8);
    uint64_t fib = fibonacci(10);
    bool even = is_even(7);
    printf("recursion: 8! = %llu, fib(10) = %llu, 7 even = %d\n", (unsigned long long)fact,
           (unsigned long long)fib, even);
}
