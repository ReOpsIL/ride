cmake_minimum_required(VERSION 3.20)
project(cpp_demo LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

option(DEMO_WARNINGS "Enable -Wall -Wextra" ON)

function(demo_apply_warnings target)
    if(DEMO_WARNINGS)
        target_compile_options(${target} PRIVATE -Wall -Wextra)
    endif()
endfunction()

add_library(shapes STATIC src/shapes.cpp src/registry.cpp)
target_include_directories(shapes PUBLIC include)
demo_apply_warnings(shapes)

add_executable(demo src/main.cpp)
target_link_libraries(demo PRIVATE shapes)
demo_apply_warnings(demo)
