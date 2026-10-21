#include <sys/wait.h>
#include <unistd.h>

#include <chrono>
#include <cstdio>
#include <thread>

#include "scenarios.hpp"

namespace {

constexpr int rounds = 60;

int child_work(int round) {
    int squared = round * round;
    return squared;
}

[[noreturn]] void child() {
    std::printf("fork: child pid %d\n", getpid());
    std::fflush(stdout);
    int total = 0;
    for (int round = 1; round <= rounds; ++round) {
        total += child_work(round);
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }
    std::printf("fork: child total=%d\n", total);
    std::fflush(stdout);
    _exit(0);
}

void parent(pid_t pid) {
    int status = 0;
    waitpid(pid, &status, 0);
    std::printf("fork: child %d exited with %d\n", pid, WEXITSTATUS(status));
}

}

void lab::fork(unsigned delay) {
    std::printf("fork: parent pid %d forks in %u s\n", getpid(), delay);
    std::fflush(stdout);
    std::this_thread::sleep_for(std::chrono::seconds(delay));
    pid_t pid = ::fork();
    if (pid == 0) {
        child();
    } else if (pid > 0) {
        parent(pid);
    } else {
        std::printf("fork: fork failed\n");
    }
}
