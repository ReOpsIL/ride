#include <cstdio>
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

int main(int argc, char** argv) {
    const char* only = argc > 1 ? argv[1] : nullptr;
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
