#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <vector>

#include "scenarios.hpp"

void lab::loops() {
    std::uint64_t sum = 0;
    std::vector<std::uint64_t> checkpoints;
    for (std::uint64_t i = 0; i < 100; ++i) {
        std::uint64_t square = i * i;
        sum += square;
        if (i % 10 == 0) {
            checkpoints.push_back(square);
        }
    }
    int countdown = 5;
    while (countdown > 0) {
        --countdown;
    }
    std::vector<int> values{5, 3, 8, 1, 9, 2};
    int evens = 0;
    for (int value : values) {
        if (value % 2 == 0) {
            ++evens;
        }
    }
    auto largest = std::max_element(values.begin(), values.end());
    std::printf("loops: sum=%llu checkpoints=%zu countdown=%d evens=%d largest=%d\n",
                static_cast<unsigned long long>(sum), checkpoints.size(), countdown, evens, *largest);
}
