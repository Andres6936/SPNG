CMAKE_MINIMUM_REQUIRED(VERSION 3.14)

PROJECT(libspng LANGUAGES C)

SET(SPNG_MAJOR 0)
SET(SPNG_MINOR 7)
SET(SPNG_REVISION 2)
SET(SPNG_VERSION ${SPNG_MAJOR}.${SPNG_MINOR}.${SPNG_REVISION})
SET(SPNG_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR})

OPTION(ENABLE_OPT "Enable architecture-specific optimizations" ON)
OPTION(SPNG_SHARED "Build shared lib" ON)
OPTION(SPNG_STATIC "Build static lib" ON)
OPTION(BUILD_EXAMPLES "Build examples" ON)

INCLUDE(GNUInstallDirs)
INCLUDE(CMakeModules/CPM.cmake)


# In this case, the name of the NAME variable is important.
# because it will be used to determine the path where the
# source code of the project is located.
CPMADDPACKAGE(
        NAME ZLIB
        GITHUB_REPOSITORY madler/zlib
        VERSION 1.2.11
)

INCLUDE_DIRECTORIES(${ZLIB_BINARY_DIR})
INCLUDE_DIRECTORIES(${ZLIB_SOURCE_DIR})
INCLUDE_DIRECTORIES(${CMAKE_CURRENT_SOURCE_DIR}/spng)

SET(spng_SOURCES spng/spng.c)

IF (NOT ENABLE_OPT)
    ADD_DEFINITIONS(-DSPNG_DISABLE_OPT=1)
ENDIF ()

IF (SPNG_SHARED)
    ADD_LIBRARY(spng SHARED ${spng_SOURCES})
    TARGET_LINK_LIBRARIES(spng zlib)
    INSTALL(TARGETS spng DESTINATION lib)

    IF (BUILD_EXAMPLES)
        ADD_EXECUTABLE(examples examples/example.c)
        TARGET_INCLUDE_DIRECTORIES(example PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/spng)
        TARGET_LINK_LIBRARIES(examples spng zlib)

        # Reference: https://www.py4u.net/discuss/2364298
        ADD_CUSTOM_COMMAND(TARGET examples POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_directory
                "${ZLIB_BINARY_DIR}"
                $<TARGET_FILE_DIR:examples>)
    ENDIF ()
ENDIF ()

IF (SPNG_STATIC)
    ADD_LIBRARY(spng_static STATIC ${spng_SOURCES})
    TARGET_COMPILE_DEFINITIONS(spng_static PUBLIC SPNG_STATIC)
    INSTALL(TARGETS spng_static DESTINATION lib)
ENDIF ()

INSTALL(FILES spng/spng.h DESTINATION include)


IF (NOT CMAKE_HOST_WIN32 OR CYGWIN OR MINGW)
    SET(prefix ${CMAKE_INSTALL_PREFIX})
    SET(exec_prefix ${CMAKE_INSTALL_PREFIX})
    SET(libdir ${CMAKE_INSTALL_FULL_LIBDIR})
    SET(includedir ${CMAKE_INSTALL_FULL_INCLUDEDIR})
    SET(LIBS "-lz -lm")

    CONFIGURE_FILE(${CMAKE_CURRENT_SOURCE_DIR}/tests/libspng.pc.in ${CMAKE_CURRENT_BINARY_DIR}/tests/libspng.pc @ONLY)

    INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/tests/libspng.pc DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig)
ENDIF ()

ADD_SUBDIRECTORY(tests/)