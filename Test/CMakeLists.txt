# In this case, the name of the NAME variable is important.
# because it will be used to determine the path where the
# source code of the project is located.
CPMADDPACKAGE(
        NAME LIB_PNG
        GITHUB_REPOSITORY Andres6936/PNG
        VERSION 1.6.37
)

ADD_EXECUTABLE(libspng.testsuit testsuite.c)
TARGET_LINK_LIBRARIES(libspng.testsuit Spng::Framework ZLib::Framework Png.Framework)

# Reference: https://www.py4u.net/discuss/2364298
ADD_CUSTOM_COMMAND(TARGET libspng.testsuit POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        $<TARGET_FILE_DIR:Spng::Framework>
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