# In this case, the name of the NAME variable is important.
# because it will be used to determine the path where the
# source code of the project is located.
CPMADDPACKAGE(
        NAME LIB_PNG
        GITHUB_REPOSITORY Andres6936/PNG
        VERSION 1.6.37
)

ADD_EXECUTABLE(libspng.testsuit testsuite.c)
TARGET_INCLUDE_DIRECTORIES(libspng.testsuit PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/spng)
TARGET_LINK_LIBRARIES(libspng.testsuit spng ZLib::Framework Png.Framework)

# Reference: https://www.py4u.net/discuss/2364298
ADD_CUSTOM_COMMAND(TARGET libspng.testsuit POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${SPNG_BINARY_DIR}
        $<TARGET_FILE_DIR:libspng.testsuit>)

# Reference: https://www.py4u.net/discuss/2364298
ADD_CUSTOM_COMMAND(TARGET libspng.testsuit POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        $<TARGET_FILE_DIR:ZLib.Framework>
        $<TARGET_FILE_DIR:libspng.testsuit>)

# Reference: https://www.py4u.net/discuss/2364298
ADD_CUSTOM_COMMAND(TARGET libspng.testsuit POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        $<TARGET_FILE_DIR:Png.Framework>
        $<TARGET_FILE_DIR:libspng.testsuit>)