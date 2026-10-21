#include <chrono>
#include <cstdint>
#include <cstdio>
#include <mutex>
#include <thread>
#include <vector>

#include "scenarios.hpp"

namespace {

void work(std::uint64_t id, std::uint64_t& shared, std::mutex& lock) {
    for (std::uint64_t round = 0; round < 3; ++round) {
        std::uint64_t contribution = id * 10 + round;
        {
            std::lock_guard<std::mutex> guard(lock);
            shared += contribution;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }
}

}

void lab::threads() {
    std::uint64_t shared = 0;
    std::mutex lock;
    std::vector<std::thread> workers;
    for (std::uint64_t id = 0; id < 3; ++id) {
        workers.emplace_back(work, id, std::ref(shared), std::ref(lock));
    }
    for (std::thread& worker : workers) {
        worker.join();
    }
    std::printf("threads: total=%llu\n", static_cast<unsigned long long>(shared));
}
