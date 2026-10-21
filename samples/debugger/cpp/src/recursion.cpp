#include <cstdint>
#include <cstdio>

#include "scenarios.hpp"

namespace {

std::uint64_t factorial(std::uint64_t n) {
    if (n <= 1) {
        return 1;
    }
    std::uint64_t below = factorial(n - 1);
    return n * below;
}

std::uint64_t fibonacci(unsigned n) {
    if (n < 2) {
        return n;
    }
    return fibonacci(n - 1) + fibonacci(n - 2);
}

bool is_odd(unsigned n);

bool is_even(unsigned n) {
    if (n == 0) {
        return true;
    }
    return is_odd(n - 1);
}

bool is_odd(unsigned n) {
    if (n == 0) {
        return false;
    }
    return is_even(n - 1);
}

template <unsigned N>
struct Power {
    static unsigned of(unsigned base) { return base * Power<N - 1>::of(base); }
};

template <>
struct Power<0> {
    static unsigned of(unsigned) { return 1; }
};

}

void lab::recursion() {
    std::uint64_t fact = factorial(8);
    std::uint64_t fib = fibonacci(10);
    bool even = is_even(7);
    unsigned cube = Power<3>::of(4);
    std::printf("recursion: 8! = %llu, fib(10) = %llu, 7 even = %d, 4^3 = %u\n",
                static_cast<unsigned long long>(fact), static_cast<unsigned long long>(fib), even, cube);
}
