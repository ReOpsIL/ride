cmake_minimum_required(VERSION 3.20)
project(c_demo LANGUAGES C)

set(CMAKE_C_STANDARD 17)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_library(geometry STATIC src/geometry.c src/util.c)
target_include_directories(geometry PUBLIC include)
target_link_libraries(geometry PUBLIC m)

add_executable(demo src/main.c)
target_link_libraries(demo PRIVATE geometry)
