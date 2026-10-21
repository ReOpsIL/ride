#include <cstdio>
#include <cstdlib>
#include <cstring>

#include "scenarios.hpp"

struct Scenario {
    const char* name;
    void (*run)();
};

static const Scenario scenarios[] = {
    {"stepping", lab::stepping},
    {"stack", lab::stack},
    {"recursion", lab::recursion},
    {"loops", lab::loops},
    {"data", lab::data},
    {"dispatch", lab::dispatch},
    {"threads", lab::threads},
    {"faults", lab::faults},
    {"heartbeat", lab::heartbeat},
};

constexpr unsigned fork_delay = 10;

static void run_fork(int argc, char** argv) {
    std::printf("== fork ==\n");
    std::fflush(stdout);
    lab::fork(argc > 2 ? static_cast<unsigned>(std::atoi(argv[2])) : fork_delay);
}

int main(int argc, char** argv) {
    const char* only = argc > 1 ? argv[1] : nullptr;
    if (only != nullptr && std::strcmp(only, "fork") == 0) {
        run_fork(argc, argv);
        std::printf("== done ==\n");
        return 0;
    }
    for (const Scenario& scenario : scenarios) {
        if (only == nullptr || std::strcmp(only, scenario.name) == 0) {
            std::printf("== %s ==\n", scenario.name);
            std::fflush(stdout);
            scenario.run();
        }
    }
    std::printf("== done ==\n");
    return 0;
}
