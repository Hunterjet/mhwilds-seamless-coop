cmake_minimum_required(VERSION 3.25)
project(seamless_coop VERSION 0.1.0 LANGUAGES C CXX)

if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
    message(FATAL_ERROR "Monster Hunter Wilds is 64-bit: configure with a 64-bit toolchain (vcvars64).")
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
# Static CRT, like REFramework (no VC++ redistributable needed).
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

option(SEAMLESS_BUILD_TESTS "Build the Lua test runner and the plugin tests" ON)

include(src/plugin/cmake/RefDeps.cmake)
add_subdirectory(src/plugin)

if(SEAMLESS_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
