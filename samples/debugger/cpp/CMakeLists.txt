cmake_minimum_required(VERSION 3.20)
project(debugger_lab_cpp LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Debug)
endif()
set(CMAKE_CXX_FLAGS_DEBUG "-O0 -g")

find_package(Threads REQUIRED)

add_executable(debugger-lab
    src/main.cpp
    src/stepping.cpp
    src/stack.cpp
    src/recursion.cpp
    src/loops.cpp
    src/data.cpp
    src/dispatch.cpp
    src/threads.cpp
    src/faults.cpp
    src/fork.cpp
    src/heartbeat.cpp
)
target_include_directories(debugger-lab PRIVATE include)
target_compile_options(debugger-lab PRIVATE -Wall -Wextra)
target_link_libraries(debugger-lab PRIVATE Threads::Threads)
