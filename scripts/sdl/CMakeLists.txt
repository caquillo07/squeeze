cmake_minimum_required(VERSION 3.22)
project(squeeze_sdl LANGUAGES C CXX OBJC)

if (NOT APPLE OR NOT CMAKE_SYSTEM_PROCESSOR STREQUAL "arm64")
	message(FATAL_ERROR "SDL dependency build supports macOS arm64 only")
endif ()
if (NOT CMAKE_BUILD_TYPE MATCHES "^(Debug|Release)$")
	message(FATAL_ERROR "Select Debug or Release")
endif ()
foreach (lang C CXX OBJC)
	set(CMAKE_${lang}_FLAGS_DEBUG "-g -O0 -fno-omit-frame-pointer" CACHE STRING "Debug flags" FORCE)
	set(CMAKE_${lang}_FLAGS_RELEASE "-O3 -g0 -DNDEBUG" CACHE STRING "Release flags" FORCE)
endforeach ()
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(root "${CMAKE_CURRENT_SOURCE_DIR}/../..")

# Static, platform SDK backends only. No optional external-library discovery.
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(CMAKE_DISABLE_FIND_PACKAGE_PkgConfig ON)
# Vendored releases must not identify themselves using the enclosing monorepo's Git hash.
set(CMAKE_DISABLE_FIND_PACKAGE_Git ON)
set(SDL_SHARED OFF CACHE BOOL "" FORCE)
set(SDL_STATIC ON CACHE BOOL "" FORCE)
set(SDL_FRAMEWORK OFF CACHE BOOL "" FORCE)
set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)
set(SDL_TESTS OFF CACHE BOOL "" FORCE)
set(SDL_EXAMPLES OFF CACHE BOOL "" FORCE)
set(SDL_INSTALL ON CACHE BOOL "" FORCE)
set(SDL_INSTALL_CPACK OFF CACHE BOOL "" FORCE)
set(SDL_INSTALL_DOCS OFF CACHE BOOL "" FORCE)
set(SDL_HIDAPI_LIBUSB OFF CACHE BOOL "" FORCE)
set(SDL_OPENGL OFF CACHE BOOL "" FORCE)
set(SDL_OPENGLES OFF CACHE BOOL "" FORCE)
set(SDL_VULKAN OFF CACHE BOOL "" FORCE)
set(SDL_CAMERA OFF CACHE BOOL "" FORCE)
set(SDL_CCACHE OFF CACHE BOOL "" FORCE)
add_subdirectory("${root}/ext/SDL3" SDL3)

# The existing shadercross source now consumes this SDL's headers, not a system package.
set(SDLSHADERCROSS_VENDORED ON CACHE BOOL "" FORCE)
set(SDLSHADERCROSS_SHARED OFF CACHE BOOL "" FORCE)
set(SDLSHADERCROSS_STATIC ON CACHE BOOL "" FORCE)
set(SDLSHADERCROSS_SPIRVCROSS_SHARED OFF CACHE BOOL "" FORCE)
set(SDLSHADERCROSS_DXC OFF CACHE BOOL "" FORCE)
set(SDLSHADERCROSS_CLI OFF CACHE BOOL "" FORCE)
set(SDLSHADERCROSS_TESTS OFF CACHE BOOL "" FORCE)
set(SDLSHADERCROSS_INSTALL OFF CACHE BOOL "" FORCE)
# Older vendored SPIRV-Cross specialization syntax needs this on current Clang.
add_compile_options("$<$<COMPILE_LANGUAGE:CXX>:-Wno-invalid-specialization>")
add_subdirectory("${root}/ext/SDL_gpu_shadercross" shadercross EXCLUDE_FROM_ALL)

# Odin consumes one self-contained shadercross archive, not nested archives.
find_program(sdl_libtool libtool REQUIRED)
set(shadercross_targets SDL3_shadercross-static spirv-cross-c spirv-cross-glsl
	spirv-cross-hlsl spirv-cross-msl spirv-cross-cpp spirv-cross-reflect spirv-cross-core)
set(shadercross_archives)
foreach (target IN LISTS shadercross_targets)
	list(APPEND shadercross_archives "$<TARGET_FILE:${target}>")
endforeach ()
set(shadercross_archive "${CMAKE_CURRENT_BINARY_DIR}/libSDL3_shadercross.a")
add_custom_command(OUTPUT "${shadercross_archive}"
	COMMAND "${sdl_libtool}" -static -o "${shadercross_archive}" ${shadercross_archives}
	DEPENDS ${shadercross_targets} ${shadercross_archives}
	COMMAND_EXPAND_LISTS VERBATIM)
add_custom_target(sdl-deps ALL DEPENDS SDL3-static "${shadercross_archive}")
install(FILES "${shadercross_archive}" DESTINATION lib)

# SDL generates its platform link requirements. Do not maintain a second framework list.
file(STRINGS "${CMAKE_CURRENT_BINARY_DIR}/SDL3/sdl3.pc" sdl_requires REGEX "^Requires.private:")
if (NOT sdl_requires MATCHES "^Requires.private: *$")
	message(FATAL_ERROR "Unexpected external SDL dependencies: ${sdl_requires}")
endif ()
file(STRINGS "${CMAKE_CURRENT_BINARY_DIR}/SDL3/sdl3.pc" sdl_link_flags REGEX "^Libs:")
string(REPLACE "Libs:" "" sdl_link_flags "${sdl_link_flags}")
string(REPLACE "-L\${libdir}" "" sdl_link_flags "${sdl_link_flags}")
string(REGEX REPLACE "-lSDL3( |$)" "" sdl_link_flags "${sdl_link_flags}")
# Odin already supplies libm; avoid duplicate linker warnings.
string(REGEX REPLACE "(^| )-lm( |$)" "\\1" sdl_link_flags "${sdl_link_flags}")
string(STRIP "${sdl_link_flags}" sdl_link_flags)
if (sdl_link_flags MATCHES "\\$|Libs.private:|-lSDL3")
	message(FATAL_ERROR "Unresolved SDL link requirements: ${sdl_link_flags}")
endif ()
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/odin-link-flags" "${sdl_link_flags} -lc++\n")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/odin-link-flags" DESTINATION share/squeeze)

enable_testing()
add_executable(sdl-smoke "${CMAKE_CURRENT_SOURCE_DIR}/sdl_smoke.c")
target_link_libraries(sdl-smoke PRIVATE SDL3::SDL3-static SDL3_shadercross::SDL3_shadercross-static)
add_test(NAME sdl-smoke COMMAND sdl-smoke)
