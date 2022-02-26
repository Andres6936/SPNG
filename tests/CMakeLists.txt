# In this case, the name of the NAME variable is important.
# because it will be used to determine the path where the
# source code of the project is located.
cpmaddpackage(
        NAME LIB_PNG
        GITHUB_REPOSITORY Andres6936/PNG
        VERSION 1.6.35
)

include_directories(${LIB_PNG_BINARY_DIR})
include_directories(${LIB_PNG_SOURCE_DIR})

add_executable(libspng.testsuit testsuite.c)
target_include_directories(libspng.testsuit PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/spng)
target_link_libraries(libspng.testsuit spng zlib png)

# Reference: https://www.py4u.net/discuss/2364298
add_custom_command(TARGET libspng.testsuit POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${ZLIB_BINARY_DIR}"
        $<TARGET_FILE_DIR:libspng.testsuit>)

# Reference: https://www.py4u.net/discuss/2364298
add_custom_command(TARGET libspng.testsuit POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${LIB_PNG_BINARY_DIR}"
        $<TARGET_FILE_DIR:libspng.testsuit>)