#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

#include "scenarios.h"

enum { ROUNDS = 60 };

static int child_work(int round) {
    int squared = round * round;
    return squared;
}

static void child(void) {
    printf("fork: child pid %d\n", getpid());
    fflush(stdout);
    int total = 0;
    for (int round = 1; round <= ROUNDS; ++round) {
        total += child_work(round);
        usleep(500 * 1000);
    }
    printf("fork: child total=%d\n", total);
    fflush(stdout);
    _exit(0);
}

static void parent(pid_t pid) {
    int status = 0;
    waitpid(pid, &status, 0);
    printf("fork: child %d exited with %d\n", pid, WEXITSTATUS(status));
}

void lab_fork(unsigned delay) {
    printf("fork: parent pid %d forks in %u s\n", getpid(), delay);
    fflush(stdout);
    sleep(delay);
    pid_t pid = fork();
    if (pid == 0) {
        child();
    } else if (pid > 0) {
        parent(pid);
    } else {
        printf("fork: fork failed\n");
    }
}
