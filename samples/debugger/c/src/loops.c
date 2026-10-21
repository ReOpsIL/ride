#include <stdint.h>
#include <stdio.h>

#include "scenarios.h"

void lab_loops(void) {
    uint64_t sum = 0;
    uint64_t checkpoints[10] = {0};
    int saved = 0;
    for (uint64_t i = 0; i < 100; ++i) {
        uint64_t square = i * i;
        sum += square;
        if (i % 10 == 0) {
            checkpoints[saved++] = square;
        }
    }
    int countdown = 5;
    while (countdown > 0) {
        --countdown;
    }
    int values[] = {5, 3, 8, 1, 9, 2};
    int largest = values[0];
    int index = 0;
    do {
        if (values[index] > largest) {
            largest = values[index];
        }
        ++index;
    } while (index < (int)(sizeof values / sizeof values[0]));
    printf("loops: sum=%llu checkpoints=%d last=%llu countdown=%d largest=%d\n", (unsigned long long)sum, saved,
           (unsigned long long)checkpoints[saved - 1], countdown, largest);
}
