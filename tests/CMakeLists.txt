add_executable(libspng.testsuit testsuite.c)
target_include_directories(libspng.testsuit PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/spng)
target_link_libraries(libspng.testsuit spng zlib)

# Reference: https://www.py4u.net/discuss/2364298
add_custom_command(TARGET libspng.testsuit POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${ZLIB_BINARY_DIR}"
        $<TARGET_FILE_DIR:libspng.testsuit>)