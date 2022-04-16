CMAKE_MINIMUM_REQUIRED(VERSION 3.14)

PROJECT(SPNG LANGUAGES C VERSION 2022.2.26)

SET(SPNG_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
SET(SPNG_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR})

OPTION(ENABLE_OPT "Enable architecture-specific optimizations" ON)
OPTION(SPNG_BUILD_EXAMPLES "Build examples" ON)
OPTION(SPNG_BUILD_SHARED_LIBS "Build shared lib" ON)


# Content Pack Manager (Wrapper over FetchContent)
INCLUDE(CMakeModules/CPM.cmake)

# In this case, the name of the NAME variable is important.
# because it will be used to determine the path where the
# source code of the project is located.
CPMADDPACKAGE(
        NAME ZLIB
        GITHUB_REPOSITORY Andres6936/ZLib
        VERSION 1.2.12
)


# The OBJECT's can be used to compile the sources in the list given to add_library
# to object files, but then neither archiving them into a static library nor
# linking them into a shared object. The use of object libraries is
# particularly useful if one needs to create both static and shared libraries
# in one go.

# Property: OBJECT
ADD_LIBRARY(Spng.Framework.Object OBJECT Source/spng.c)
SET_TARGET_PROPERTIES(Spng.Framework.Object PROPERTIES C_STANDARD 11)
# Link the dependency of zlib
TARGET_LINK_LIBRARIES(Spng.Framework.Object PUBLIC ZLib::Framework)
TARGET_INCLUDE_DIRECTORIES(Spng.Framework.Object PUBLIC $<BUILD_INTERFACE:${SPNG_SOURCE_DIR}/Include/>)

IF (SPNG_BUILD_SHARED_LIBS)

    # The POSITION_INDEPENDENT_CODE property determines whether position independent executables or
    # shared libraries will be created. This property is True by default for SHARED and MODULE library
    # targets and False otherwise.

    # Property: SHARED, POSITION_INDEPENDENT_CODE
    ADD_LIBRARY(Spng.Framework SHARED $<TARGET_OBJECTS:Spng.Framework.Object>)

ELSE()

    ADD_LIBRARY(Spng.Framework STATIC $<TARGET_OBJECTS:Spng.Framework.Object>)

ENDIF ()

ADD_LIBRARY(Spng::Framework ALIAS Spng.Framework)
SET_TARGET_PROPERTIES(Spng.Framework.Object PROPERTIES C_STANDARD 11)
# It is necessary to repeat these instructions again, in case of not doing it, the executables
# will be unable to locate the Headers needed to perform the linking
TARGET_LINK_LIBRARIES(Spng.Framework PUBLIC ZLib::Framework)
TARGET_INCLUDE_DIRECTORIES(Spng.Framework PUBLIC $<BUILD_INTERFACE:${SPNG_SOURCE_DIR}/Include/>)


IF (NOT ENABLE_OPT)
    ADD_DEFINITIONS(-DSPNG_DISABLE_OPT=1)
ENDIF ()



IF (SPNG_BUILD_EXAMPLES)
    ADD_EXECUTABLE(Examples Examples/example.c)
    TARGET_LINK_LIBRARIES(Examples PRIVATE Spng::Framework)

    # Reference: https://www.py4u.net/discuss/2364298
    ADD_CUSTOM_COMMAND(TARGET Examples POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_directory
            $<TARGET_FILE_DIR:ZLib::Framework>
            $<TARGET_FILE_DIR:Examples>)
ENDIF ()


ADD_SUBDIRECTORY(Test/)