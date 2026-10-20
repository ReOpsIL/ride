#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>

#include "scenarios.h"

typedef struct {
    uint64_t id;
    uint64_t *shared;
    pthread_mutex_t *lock;
} worker_t;

static void *work(void *argument) {
    worker_t *worker = argument;
    for (uint64_t round = 0; round < 3; ++round) {
        uint64_t contribution = worker->id * 10 + round;
        pthread_mutex_lock(worker->lock);
        *worker->shared += contribution;
        pthread_mutex_unlock(worker->lock);
        usleep(50 * 1000);
    }
    return NULL;
}

void lab_threads(void) {
    uint64_t shared = 0;
    pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
    pthread_t threads[3];
    worker_t workers[3];
    for (uint64_t id = 0; id < 3; ++id) {
        workers[id] = (worker_t){id, &shared, &lock};
        pthread_create(&threads[id], NULL, work, &workers[id]);
    }
    for (int id = 0; id < 3; ++id) {
        pthread_join(threads[id], NULL);
    }
    printf("threads: total=%llu\n", (unsigned long long)shared);
}
