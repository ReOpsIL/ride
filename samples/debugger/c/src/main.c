#include <stdio.h>
#include <string.h>

#include "scenarios.h"

typedef struct {
    const char *name;
    void (*run)(void);
} scenario_t;

static const scenario_t scenarios[] = {
    {"stepping", lab_stepping},
    {"stack", lab_stack},
    {"recursion", lab_recursion},
    {"loops", lab_loops},
    {"data", lab_data},
    {"dispatch", lab_dispatch},
    {"threads", lab_threads},
    {"faults", lab_faults},
    {"heartbeat", lab_heartbeat},
};

int main(int argc, char **argv) {
    const char *only = argc > 1 ? argv[1] : NULL;
    size_t count = sizeof scenarios / sizeof scenarios[0];
    for (size_t i = 0; i < count; ++i) {
        if (only == NULL || strcmp(only, scenarios[i].name) == 0) {
            printf("== %s ==\n", scenarios[i].name);
            fflush(stdout);
            scenarios[i].run();
        }
    }
    printf("== done ==\n");
    return 0;
}
