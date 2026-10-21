#include <chrono>
#include <cstdio>
#include <thread>

#include "scenarios.hpp"

void lab::heartbeat() {
    const int beats = 40;
    for (int beat = 1; beat <= beats; ++beat) {
        std::printf("heartbeat %d/%d\n", beat, beats);
        std::fflush(stdout);
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }
}
