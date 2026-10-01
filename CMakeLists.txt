cmake_minimum_required(VERSION 3.21)
project(squeeze_vd LANGUAGES C)

set(CMAKE_C_STANDARD 23)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Own these flags explicitly instead of inheriting compiler-module defaults.
set(CMAKE_C_FLAGS_DEBUG "-g -O0" CACHE STRING "VD Debug C flags" FORCE)
set(CMAKE_C_FLAGS_RELEASE "-O3 -g0 -DNDEBUG" CACHE STRING "VD Release C flags" FORCE)
if (NOT CMAKE_BUILD_TYPE MATCHES "^(Debug|Release)$")
	message(FATAL_ERROR "Select Debug or Release using the VD presets")
endif ()

set(VD_BACKEND "ffmpeg" CACHE STRING "VD backend: ffmpeg or stub")
set_property(CACHE VD_BACKEND PROPERTY STRINGS ffmpeg stub)
string(TOLOWER "${CMAKE_BUILD_TYPE}" vd_config)
set(FFMPEG_PREFIX "${CMAKE_SOURCE_DIR}/build/deps/ffmpeg/${vd_config}/install" CACHE PATH "Prebuilt FFmpeg installation")

if (NOT APPLE OR NOT CMAKE_SYSTEM_PROCESSOR STREQUAL "arm64")
	message(FATAL_ERROR "VD archive build currently supports macOS arm64 only")
endif ()
find_program(VD_LIBTOOL libtool REQUIRED)

# One policy for our C sources; prebuilt FFmpeg retains its own flags.
add_compile_options(
	-fno-omit-frame-pointer -fstack-protector-strong -fno-common
	-Wall -Wextra -Wpedantic -Werror
	-Wconversion -Wsign-conversion -Wfloat-conversion
	-Wuninitialized -Winit-self -Warray-bounds -Wstrict-overflow=5
	-Wnull-dereference -Wdouble-promotion
	-Wshadow -Wcast-align -Wcast-qual
	-Wredundant-decls -Wmissing-declarations -Wmissing-include-dirs
	-Wstrict-prototypes -Wmissing-prototypes
	-Wformat=2 -Wvla -Wundef -Wswitch-enum -Wimplicit-fallthrough
)

# vd.c includes the selected backend: one compiler process, one object.
add_library(vd_unity OBJECT core/vd/vd.c)
# Visible to the IDE, but still compiled only through vd.c.
set_source_files_properties(core/vd/vd_ffmpeg.c core/vd/vd_stub.c PROPERTIES HEADER_FILE_ONLY ON)
target_sources(vd_unity PRIVATE core/vd/vd.h core/vd/vd_ffmpeg.c core/vd/vd_stub.c)
set(vd_archives)
if (VD_BACKEND STREQUAL "ffmpeg")
	foreach (lib avformat avcodec avutil swscale swresample)
		set(archive "${FFMPEG_PREFIX}/lib/lib${lib}.a")
		if (NOT EXISTS "${archive}")
			message(FATAL_ERROR "Missing ${archive}. Run just vd_config=${vd_config} build-ffmpeg first.")
		endif ()
		list(APPEND vd_archives "${archive}")
	endforeach ()
	if (NOT EXISTS "${FFMPEG_PREFIX}/include/libavutil/avutil.h")
		message(FATAL_ERROR "Missing FFmpeg headers. Run just vd_config=${vd_config} build-ffmpeg first.")
	endif ()
	target_compile_definitions(vd_unity PRIVATE VD_BACKEND_FFMPEG)
	target_include_directories(vd_unity SYSTEM PRIVATE "${FFMPEG_PREFIX}/include")
elseif (VD_BACKEND STREQUAL "stub")
	target_compile_definitions(vd_unity PRIVATE VD_BACKEND_STUB)
else ()
	message(FATAL_ERROR "Unknown VD_BACKEND: ${VD_BACKEND} (use ffmpeg or stub)")
endif ()

set(vd_archive "${CMAKE_CURRENT_BINARY_DIR}/libvd.a")
add_custom_command(
	OUTPUT "${vd_archive}"
	COMMAND "${VD_LIBTOOL}" -static -o "${vd_archive}" $<TARGET_OBJECTS:vd_unity> ${vd_archives}
	DEPENDS vd_unity $<TARGET_OBJECTS:vd_unity> ${vd_archives}
	COMMAND_EXPAND_LISTS VERBATIM
)
add_custom_target(vd ALL DEPENDS "${vd_archive}")
message(STATUS "VD archive (${VD_BACKEND}): ${vd_archive}")

# All applicable tests stay in the project/database, even when building only vd.
enable_testing()
add_executable(vd_smoke core/vd/tests/vd_smoke.c)
set_target_properties(vd_smoke PROPERTIES OUTPUT_NAME vd-smoke)
set(vd_tests vd_smoke)
if (VD_BACKEND STREQUAL "ffmpeg")
	add_executable(vd_ffmpeg_smoke core/vd/tests/vd_ffmpeg_smoke.c)
	set_target_properties(vd_ffmpeg_smoke PROPERTIES OUTPUT_NAME vd-ffmpeg-smoke)
	target_include_directories(vd_ffmpeg_smoke SYSTEM PRIVATE "${FFMPEG_PREFIX}/include")
	list(APPEND vd_tests vd_ffmpeg_smoke)
endif ()
foreach (test IN LISTS vd_tests)
	add_dependencies(${test} vd)
	target_include_directories(${test} PRIVATE "${CMAKE_SOURCE_DIR}/core/vd")
	target_compile_options(${test} PRIVATE -UNDEBUG)
	target_link_libraries(${test} PRIVATE "${vd_archive}")
	add_test(NAME ${test} COMMAND ${test})
	add_custom_command(TARGET ${test} POST_BUILD
		COMMAND "${CMAKE_COMMAND}" -E echo "Smoke binary: $<TARGET_FILE:${test}>"
		VERBATIM
	)
endforeach ()
