# Fetches the pieces of REFramework that seamless_net.dll must match exactly, pinned to the REFramework commit the mod
# is tested with: the plugin C API header and REFramework's vendored Lua 5.4.3 sources. The plugin operates on
# REFramework's lua_State with its own copy of Lua, so the sources must be identical (implementation plan §7).
# Files are downloaded once into REF_DEPS_DIR (default: <build>/_deps/reframework-<commit>).

set(REF_COMMIT "d4611aef1d63effd3a736bdf9404ea702428017d" CACHE STRING "REFramework commit the plugin is built against")
set(REF_DEPS_DIR "${CMAKE_BINARY_DIR}/_deps/reframework-${REF_COMMIT}" CACHE PATH "Download folder for REFramework files")
set(_ref_raw "https://raw.githubusercontent.com/praydog/REFramework/${REF_COMMIT}")

# lua.c (standalone interpreter, used only by the offline test runner) is not vendored by REFramework: it comes from
# upstream Lua 5.4.3 and only uses the public API.
set(LUA_UPSTREAM_TAG "v5.4.3")
set(_lua_upstream_raw "https://raw.githubusercontent.com/lua/lua/${LUA_UPSTREAM_TAG}")

set(REF_LUA_SOURCES
    lapi.c lauxlib.c lbaselib.c lcode.c lcorolib.c lctype.c ldblib.c ldebug.c ldo.c ldump.c lfunc.c lgc.c linit.c
    liolib.c llex.c lmathlib.c lmem.c loadlib.c lobject.c lopcodes.c loslib.c lparser.c lstate.c lstring.c lstrlib.c
    ltable.c ltablib.c ltm.c lundump.c lutf8lib.c lvm.c lzio.c)
set(REF_LUA_HEADERS
    lapi.h lauxlib.h lcode.h lctype.h ldebug.h ldo.h lfunc.h lgc.h ljumptab.h llex.h llimits.h lmem.h lobject.h
    lopcodes.h lopnames.h lparser.h lprefix.h lstate.h lstring.h ltable.h ltm.h lua.h lua.hpp luaconf.h lualib.h
    lundump.h lvm.h lzio.h)

function(_ref_download url dest)
    if(EXISTS "${dest}")
        return()
    endif()
    message(STATUS "Downloading ${url}")
    file(DOWNLOAD "${url}" "${dest}.part" STATUS _st TLS_VERIFY ON)
    list(GET _st 0 _code)
    if(NOT _code EQUAL 0)
        file(REMOVE "${dest}.part")
        message(FATAL_ERROR "Download failed (${_st}): ${url}")
    endif()
    file(RENAME "${dest}.part" "${dest}")
endfunction()

_ref_download("${_ref_raw}/include/reframework/API.h" "${REF_DEPS_DIR}/include/reframework/API.h")
foreach(_f IN LISTS REF_LUA_SOURCES REF_LUA_HEADERS)
    _ref_download("${_ref_raw}/dependencies/lua/src/${_f}" "${REF_DEPS_DIR}/lua/${_f}")
endforeach()
_ref_download("${_lua_upstream_raw}/lua.c" "${REF_DEPS_DIR}/lua-upstream/lua.c")

list(TRANSFORM REF_LUA_SOURCES PREPEND "${REF_DEPS_DIR}/lua/")

# REFramework's Lua, compiled as C exactly like REFramework does (no extra definitions).
add_library(ref_lua STATIC ${REF_LUA_SOURCES})
set_target_properties(ref_lua PROPERTIES LINKER_LANGUAGE C)
target_include_directories(ref_lua PUBLIC "${REF_DEPS_DIR}/lua")
if(MSVC)
    target_compile_options(ref_lua PRIVATE /W0)
endif()

add_library(ref_api INTERFACE)
target_include_directories(ref_api INTERFACE "${REF_DEPS_DIR}/include")
