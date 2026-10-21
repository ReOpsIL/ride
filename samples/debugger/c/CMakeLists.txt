cmake_minimum_required(VERSION 3.20)
project(debugger_lab_c LANGUAGES C)

set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Debug)
endif()
set(CMAKE_C_FLAGS_DEBUG "-O0 -g")

find_package(Threads REQUIRED)

add_executable(debugger-lab
    src/main.c
    src/stepping.c
    src/stack.c
    src/recursion.c
    src/loops.c
    src/data.c
    src/dispatch.c
    src/threads.c
    src/faults.c
    src/fork.c
    src/heartbeat.c
)
target_include_directories(debugger-lab PRIVATE include)
target_compile_options(debugger-lab PRIVATE -Wall -Wextra)
target_link_libraries(debugger-lab PRIVATE Threads::Threads)
