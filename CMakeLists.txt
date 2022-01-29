cmake_minimum_required(VERSION 3.14)

project(libspng LANGUAGES C)

set(SPNG_MAJOR 0)
set(SPNG_MINOR 7)
set(SPNG_REVISION 2)
set(SPNG_VERSION ${SPNG_MAJOR}.${SPNG_MINOR}.${SPNG_REVISION})

option(ENABLE_OPT "Enable architecture-specific optimizations" ON)
option(SPNG_SHARED "Build shared lib" ON)
option(SPNG_STATIC "Build static lib" ON)
option(BUILD_EXAMPLES "Build examples" ON)

include(GNUInstallDirs)
include(CMakeModules/CPM.cmake)


# In this case, the name of the NAME variable is important.
# because it will be used to determine the path where the
# source code of the project is located.
cpmaddpackage(
        NAME ZLIB
        GITHUB_REPOSITORY madler/zlib
        VERSION 1.2.11
)

include_directories(${ZLIB_BINARY_DIR})
include_directories(${ZLIB_SOURCE_DIR})
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/spng)

set(spng_SOURCES spng/spng.c)

if (NOT ENABLE_OPT)
    add_definitions(-DSPNG_DISABLE_OPT=1)
endif ()

if (SPNG_SHARED)
    add_library(spng SHARED ${spng_SOURCES})
    target_link_libraries(spng zlib)
    install(TARGETS spng DESTINATION lib)

    if (BUILD_EXAMPLES)
        add_executable(examples examples/example.c)
        target_include_directories(example PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/spng)
        target_link_libraries(examples spng zlib)

        # Reference: https://www.py4u.net/discuss/2364298
        add_custom_command(TARGET examples POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_directory
                "${ZLIB_BINARY_DIR}"
                $<TARGET_FILE_DIR:examples>)
    endif ()
endif ()

if (SPNG_STATIC)
    add_library(spng_static STATIC ${spng_SOURCES})
    target_compile_definitions(spng_static PUBLIC SPNG_STATIC)
    install(TARGETS spng_static DESTINATION lib)
endif ()

install(FILES spng/spng.h DESTINATION include)


if (NOT CMAKE_HOST_WIN32 OR CYGWIN OR MINGW)
    set(prefix ${CMAKE_INSTALL_PREFIX})
    set(exec_prefix ${CMAKE_INSTALL_PREFIX})
    set(libdir ${CMAKE_INSTALL_FULL_LIBDIR})
    set(includedir ${CMAKE_INSTALL_FULL_INCLUDEDIR})
    set(LIBS "-lz -lm")

    configure_file(${CMAKE_CURRENT_SOURCE_DIR}/tests/libspng.pc.in ${CMAKE_CURRENT_BINARY_DIR}/tests/libspng.pc @ONLY)

    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/tests/libspng.pc DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig)
endif ()

add_subdirectory(tests/)