# Offline Lua tests run with an interpreter built from the same Lua sources as REFramework (5.4.3).
add_executable(lua_runner "${REF_DEPS_DIR}/lua-upstream/lua.c")
target_link_libraries(lua_runner PRIVATE ref_lua)
set_target_properties(lua_runner PROPERTIES LINKER_LANGUAGE C)
if(MSVC)
    target_compile_options(lua_runner PRIVATE /W0)
endif()

add_test(NAME lua_unit
    COMMAND lua_runner "${CMAKE_CURRENT_SOURCE_DIR}/lua/run.lua" "${CMAKE_SOURCE_DIR}"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}")

# Plugin unit tests (Catch2).
include(FetchContent)
FetchContent_Declare(Catch2
    GIT_REPOSITORY https://github.com/catchorg/Catch2.git
    GIT_TAG v3.8.1
    GIT_SHALLOW TRUE)
FetchContent_MakeAvailable(Catch2)

add_executable(plugin_tests
    plugin/test_rate_limiter.cpp
    plugin/test_channel.cpp
    plugin/test_save_backup.cpp
    plugin/test_steam_types.cpp)
target_link_libraries(plugin_tests PRIVATE seamless_core Catch2::Catch2WithMain)
target_compile_definitions(plugin_tests PRIVATE NOMINMAX)
if(MSVC)
    target_compile_options(plugin_tests PRIVATE /W4 /permissive- /utf-8 /EHsc)
endif()
add_test(NAME plugin_unit COMMAND plugin_tests)
