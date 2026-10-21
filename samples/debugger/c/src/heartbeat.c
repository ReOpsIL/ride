#include <stdio.h>
#include <unistd.h>

#include "scenarios.h"

void lab_heartbeat(void) {
    const int beats = 40;
    for (int beat = 1; beat <= beats; ++beat) {
        printf("heartbeat %d/%d\n", beat, beats);
        fflush(stdout);
        usleep(500 * 1000);
    }
}
