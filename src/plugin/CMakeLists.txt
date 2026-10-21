# seamless_core: platform-independent logic (channel rules, rate limits, save backup), unit-tested.
add_library(seamless_core STATIC
    src/channel.cpp
    src/save_backup.cpp)
target_include_directories(seamless_core PUBLIC src)

# seamless_net.dll: the REFramework plugin.
add_library(seamless_net SHARED
    src/plugin.cpp
    src/steam_flat.cpp)
target_link_libraries(seamless_net PRIVATE seamless_core ref_lua ref_api)
target_compile_definitions(seamless_net PRIVATE SEAMLESS_NET_VERSION="${PROJECT_VERSION}")
set_target_properties(seamless_net PROPERTIES OUTPUT_NAME "seamless_net")
if(MSVC)
    target_link_options(seamless_net PRIVATE /INCREMENTAL:NO /OPT:REF /OPT:ICF)
endif()

foreach(_t seamless_core seamless_net)
    target_compile_definitions(${_t} PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX _CRT_SECURE_NO_WARNINGS)
    if(MSVC)
        target_compile_options(${_t} PRIVATE /W4 /permissive- /utf-8 /EHsc /Zc:__cplusplus)
    endif()
endforeach()
