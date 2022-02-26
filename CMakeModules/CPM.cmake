# CPM.cmake - CMake's missing package manager
# ===========================================
# See https://github.com/cpm-cmake/CPM.cmake for usage and update instructions.
#
# MIT License
# -----------
#[[
  Copyright (c) 2021 Lars Melchior and additional contributors

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
]]

CMAKE_MINIMUM_REQUIRED(VERSION 3.14 FATAL_ERROR)

SET(CURRENT_CPM_VERSION 0.34.2)

IF (CPM_DIRECTORY)
    IF (NOT CPM_DIRECTORY STREQUAL CMAKE_CURRENT_LIST_DIR)
        IF (CPM_VERSION VERSION_LESS CURRENT_CPM_VERSION)
            MESSAGE(
                    AUTHOR_WARNING
                    "${CPM_INDENT} \
A dependency is using a more recent CPM version (${CURRENT_CPM_VERSION}) than the current project (${CPM_VERSION}). \
It is recommended to upgrade CPM to the most recent version. \
See https://github.com/cpm-cmake/CPM.cmake for more information."
            )
        ENDIF ()
        IF (${CMAKE_VERSION} VERSION_LESS "3.17.0")
            INCLUDE(FetchContent)
        ENDIF ()
        RETURN()
    ENDIF ()

    GET_PROPERTY(
            CPM_INITIALIZED GLOBAL ""
            PROPERTY CPM_INITIALIZED
            SET
    )
    IF (CPM_INITIALIZED)
        RETURN()
    ENDIF ()
ENDIF ()

IF (CURRENT_CPM_VERSION MATCHES "development-version")
    MESSAGE(WARNING "Your project is using an unstable development version of CPM.cmake. \
Please update to a recent release if possible. \
See https://github.com/cpm-cmake/CPM.cmake for details."
            )
ENDIF ()

SET_PROPERTY(GLOBAL PROPERTY CPM_INITIALIZED true)

OPTION(CPM_USE_LOCAL_PACKAGES "Always try to use `find_package` to get dependencies"
        $ENV{CPM_USE_LOCAL_PACKAGES}
        )
OPTION(CPM_LOCAL_PACKAGES_ONLY "Only use `find_package` to get dependencies"
        $ENV{CPM_LOCAL_PACKAGES_ONLY}
        )
OPTION(CPM_DOWNLOAD_ALL "Always download dependencies from source" $ENV{CPM_DOWNLOAD_ALL})
OPTION(CPM_DONT_UPDATE_MODULE_PATH "Don't update the module path to allow using find_package"
        $ENV{CPM_DONT_UPDATE_MODULE_PATH}
        )
OPTION(CPM_DONT_CREATE_PACKAGE_LOCK "Don't create a package lock file in the binary path"
        $ENV{CPM_DONT_CREATE_PACKAGE_LOCK}
        )
OPTION(CPM_INCLUDE_ALL_IN_PACKAGE_LOCK
        "Add all packages added through CPM.cmake to the package lock"
        $ENV{CPM_INCLUDE_ALL_IN_PACKAGE_LOCK}
        )
OPTION(CPM_USE_NAMED_CACHE_DIRECTORIES
        "Use additional directory of package name in cache on the most nested level."
        $ENV{CPM_USE_NAMED_CACHE_DIRECTORIES}
        )

SET(CPM_VERSION
        ${CURRENT_CPM_VERSION}
        CACHE INTERNAL ""
        )
SET(CPM_DIRECTORY
        ${CMAKE_CURRENT_LIST_DIR}
        CACHE INTERNAL ""
        )
SET(CPM_FILE
        ${CMAKE_CURRENT_LIST_FILE}
        CACHE INTERNAL ""
        )
SET(CPM_PACKAGES
        ""
        CACHE INTERNAL ""
        )
SET(CPM_DRY_RUN
        OFF
        CACHE INTERNAL "Don't download or configure dependencies (for testing)"
        )

IF (DEFINED ENV{CPM_SOURCE_CACHE})
    SET(CPM_SOURCE_CACHE_DEFAULT $ENV{CPM_SOURCE_CACHE})
ELSE ()
    SET(CPM_SOURCE_CACHE_DEFAULT OFF)
ENDIF ()

SET(CPM_SOURCE_CACHE
        ${CPM_SOURCE_CACHE_DEFAULT}
        CACHE PATH "Directory to download CPM dependencies"
        )

IF (NOT CPM_DONT_UPDATE_MODULE_PATH)
    SET(CPM_MODULE_PATH
            "${CMAKE_BINARY_DIR}/CPM_modules"
            CACHE INTERNAL ""
            )
    # remove old modules
    FILE(REMOVE_RECURSE ${CPM_MODULE_PATH})
    FILE(MAKE_DIRECTORY ${CPM_MODULE_PATH})
    # locally added CPM modules should override global packages
    SET(CMAKE_MODULE_PATH "${CPM_MODULE_PATH};${CMAKE_MODULE_PATH}")
ENDIF ()

IF (NOT CPM_DONT_CREATE_PACKAGE_LOCK)
    SET(CPM_PACKAGE_LOCK_FILE
            "${CMAKE_BINARY_DIR}/cpm-package-lock.cmake"
            CACHE INTERNAL ""
            )
    FILE(WRITE ${CPM_PACKAGE_LOCK_FILE}
            "# CPM Package Lock\n# This file should be committed to version control\n\n"
            )
ENDIF ()

INCLUDE(FetchContent)

# Try to infer package name from git repository uri (path or url)
FUNCTION(CPM_PACKAGE_NAME_FROM_GIT_URI URI RESULT)
    IF ("${URI}" MATCHES "([^/:]+)/?.git/?$")
        SET(${RESULT}
                ${CMAKE_MATCH_1}
                PARENT_SCOPE
                )
    ELSE ()
        UNSET(${RESULT} PARENT_SCOPE)
    ENDIF ()
ENDFUNCTION()

# Try to infer package name and version from a url
FUNCTION(CPM_PACKAGE_NAME_AND_VER_FROM_URL url outName outVer)
    IF (url MATCHES "[/\\?]([a-zA-Z0-9_\\.-]+)\\.(tar|tar\\.gz|tar\\.bz2|zip|ZIP)(\\?|/|$)")
        # We matched an archive
        SET(filename "${CMAKE_MATCH_1}")

        IF (filename MATCHES "([a-zA-Z0-9_\\.-]+)[_-]v?(([0-9]+\\.)*[0-9]+[a-zA-Z0-9]*)")
            # We matched <name>-<version> (ie foo-1.2.3)
            SET(${outName}
                    "${CMAKE_MATCH_1}"
                    PARENT_SCOPE
                    )
            SET(${outVer}
                    "${CMAKE_MATCH_2}"
                    PARENT_SCOPE
                    )
        ELSEIF (filename MATCHES "(([0-9]+\\.)+[0-9]+[a-zA-Z0-9]*)")
            # We couldn't find a name, but we found a version
            #
            # In many cases (which we don't handle here) the url would look something like
            # `irrelevant/ACTUAL_PACKAGE_NAME/irrelevant/1.2.3.zip`. In such a case we can't possibly
            # distinguish the package name from the irrelevant bits. Moreover if we try to match the
            # package name from the filename, we'd get bogus at best.
            UNSET(${outName} PARENT_SCOPE)
            SET(${outVer}
                    "${CMAKE_MATCH_1}"
                    PARENT_SCOPE
                    )
        ELSE ()
            # Boldly assume that the file name is the package name.
            #
            # Yes, something like `irrelevant/ACTUAL_NAME/irrelevant/download.zip` will ruin our day, but
            # such cases should be quite rare. No popular service does this... we think.
            SET(${outName}
                    "${filename}"
                    PARENT_SCOPE
                    )
            UNSET(${outVer} PARENT_SCOPE)
        ENDIF ()
    ELSE ()
        # No ideas yet what to do with non-archives
        UNSET(${outName} PARENT_SCOPE)
        UNSET(${outVer} PARENT_SCOPE)
    ENDIF ()
ENDFUNCTION()

# Initialize logging prefix
IF (NOT CPM_INDENT)
    SET(CPM_INDENT
            "CPM:"
            CACHE INTERNAL ""
            )
ENDIF ()

FUNCTION(CPM_FIND_PACKAGE NAME VERSION)
    STRING(REPLACE " " ";" EXTRA_ARGS "${ARGN}")
    FIND_PACKAGE(${NAME} ${VERSION} ${EXTRA_ARGS} QUIET)
    IF (${CPM_ARGS_NAME}_FOUND)
        MESSAGE(STATUS "${CPM_INDENT} using local package ${CPM_ARGS_NAME}@${VERSION}")
        CPMREGISTERPACKAGE(${CPM_ARGS_NAME} "${VERSION}")
        SET(CPM_PACKAGE_FOUND
                YES
                PARENT_SCOPE
                )
    ELSE ()
        SET(CPM_PACKAGE_FOUND
                NO
                PARENT_SCOPE
                )
    ENDIF ()
ENDFUNCTION()

# Create a custom FindXXX.cmake module for a CPM package This prevents `find_package(NAME)` from
# finding the system library
FUNCTION(CPM_CREATE_MODULE_FILE Name)
    IF (NOT CPM_DONT_UPDATE_MODULE_PATH)
        # erase any previous modules
        FILE(WRITE ${CPM_MODULE_PATH}/Find${Name}.cmake
                "include(\"${CPM_FILE}\")\n${ARGN}\nset(${Name}_FOUND TRUE)"
                )
    ENDIF ()
ENDFUNCTION()

# Find a package locally or fallback to CPMAddPackage
FUNCTION(CPMFINDPACKAGE)
    SET(oneValueArgs NAME VERSION GIT_TAG FIND_PACKAGE_ARGUMENTS)

    CMAKE_PARSE_ARGUMENTS(CPM_ARGS "" "${oneValueArgs}" "" ${ARGN})

    IF (NOT DEFINED CPM_ARGS_VERSION)
        IF (DEFINED CPM_ARGS_GIT_TAG)
            CPM_GET_VERSION_FROM_GIT_TAG("${CPM_ARGS_GIT_TAG}" CPM_ARGS_VERSION)
        ENDIF ()
    ENDIF ()

    IF (CPM_DOWNLOAD_ALL)
        CPMADDPACKAGE(${ARGN})
        CPM_EXPORT_VARIABLES(${CPM_ARGS_NAME})
        RETURN()
    ENDIF ()

    CPM_CHECK_IF_PACKAGE_ALREADY_ADDED(${CPM_ARGS_NAME} "${CPM_ARGS_VERSION}")
    IF (CPM_PACKAGE_ALREADY_ADDED)
        CPM_EXPORT_VARIABLES(${CPM_ARGS_NAME})
        RETURN()
    ENDIF ()

    CPM_FIND_PACKAGE(${CPM_ARGS_NAME} "${CPM_ARGS_VERSION}" ${CPM_ARGS_FIND_PACKAGE_ARGUMENTS})

    IF (NOT CPM_PACKAGE_FOUND)
        CPMADDPACKAGE(${ARGN})
        CPM_EXPORT_VARIABLES(${CPM_ARGS_NAME})
    ENDIF ()

ENDFUNCTION()

# checks if a package has been added before
FUNCTION(CPM_CHECK_IF_PACKAGE_ALREADY_ADDED CPM_ARGS_NAME CPM_ARGS_VERSION)
    IF ("${CPM_ARGS_NAME}" IN_LIST CPM_PACKAGES)
        CPMGETPACKAGEVERSION(${CPM_ARGS_NAME} CPM_PACKAGE_VERSION)
        IF ("${CPM_PACKAGE_VERSION}" VERSION_LESS "${CPM_ARGS_VERSION}")
            MESSAGE(
                    WARNING
                    "${CPM_INDENT} requires a newer version of ${CPM_ARGS_NAME} (${CPM_ARGS_VERSION}) than currently included (${CPM_PACKAGE_VERSION})."
            )
        ENDIF ()
        CPM_GET_FETCH_PROPERTIES(${CPM_ARGS_NAME})
        SET(${CPM_ARGS_NAME}_ADDED NO)
        SET(CPM_PACKAGE_ALREADY_ADDED
                YES
                PARENT_SCOPE
                )
        CPM_EXPORT_VARIABLES(${CPM_ARGS_NAME})
    ELSE ()
        SET(CPM_PACKAGE_ALREADY_ADDED
                NO
                PARENT_SCOPE
                )
    ENDIF ()
ENDFUNCTION()

# Parse the argument of CPMAddPackage in case a single one was provided and convert it to a list of
# arguments which can then be parsed idiomatically. For example gh:foo/bar@1.2.3 will be converted
# to: GITHUB_REPOSITORY;foo/bar;VERSION;1.2.3
FUNCTION(CPM_PARSE_ADD_PACKAGE_SINGLE_ARG arg outArgs)
    # Look for a scheme
    IF ("${arg}" MATCHES "^([a-zA-Z]+):(.+)$")
        STRING(TOLOWER "${CMAKE_MATCH_1}" scheme)
        SET(uri "${CMAKE_MATCH_2}")

        # Check for CPM-specific schemes
        IF (scheme STREQUAL "gh")
            SET(out "GITHUB_REPOSITORY;${uri}")
            SET(packageType "git")
        ELSEIF (scheme STREQUAL "gl")
            SET(out "GITLAB_REPOSITORY;${uri}")
            SET(packageType "git")
        ELSEIF (scheme STREQUAL "bb")
            SET(out "BITBUCKET_REPOSITORY;${uri}")
            SET(packageType "git")
            # A CPM-specific scheme was not found. Looks like this is a generic URL so try to determine
            # type
        ELSEIF (arg MATCHES ".git/?(@|#|$)")
            SET(out "GIT_REPOSITORY;${arg}")
            SET(packageType "git")
        ELSE ()
            # Fall back to a URL
            SET(out "URL;${arg}")
            SET(packageType "archive")

            # We could also check for SVN since FetchContent supports it, but SVN is so rare these days.
            # We just won't bother with the additional complexity it will induce in this function. SVN is
            # done by multi-arg
        ENDIF ()
    ELSE ()
        IF (arg MATCHES ".git/?(@|#|$)")
            SET(out "GIT_REPOSITORY;${arg}")
            SET(packageType "git")
        ELSE ()
            # Give up
            MESSAGE(FATAL_ERROR "CPM: Can't determine package type of '${arg}'")
        ENDIF ()
    ENDIF ()

    # For all packages we interpret @... as version. Only replace the last occurence. Thus URIs
    # containing '@' can be used
    STRING(REGEX REPLACE "@([^@]+)$" ";VERSION;\\1" out "${out}")

    # Parse the rest according to package type
    IF (packageType STREQUAL "git")
        # For git repos we interpret #... as a tag or branch or commit hash
        STRING(REGEX REPLACE "#([^#]+)$" ";GIT_TAG;\\1" out "${out}")
    ELSEIF (packageType STREQUAL "archive")
        # For archives we interpret #... as a URL hash.
        STRING(REGEX REPLACE "#([^#]+)$" ";URL_HASH;\\1" out "${out}")
        # We don't try to parse the version if it's not provided explicitly. cpm_get_version_from_url
        # should do this at a later point
    ELSE ()
        # We should never get here. This is an assertion and hitting it means there's a bug in the code
        # above. A packageType was set, but not handled by this if-else.
        MESSAGE(FATAL_ERROR "CPM: Unsupported package type '${packageType}' of '${arg}'")
    ENDIF ()

    SET(${outArgs}
            ${out}
            PARENT_SCOPE
            )
ENDFUNCTION()

# Check that the working directory for a git repo is clean
FUNCTION(CPM_CHECK_GIT_WORKING_DIR_IS_CLEAN repoPath gitTag isClean)

    FIND_PACKAGE(Git REQUIRED)

    IF (NOT GIT_EXECUTABLE)
        # No git executable, assume directory is clean
        SET(${isClean}
                TRUE
                PARENT_SCOPE
                )
        RETURN()
    ENDIF ()

    # check for uncommited changes
    EXECUTE_PROCESS(
            COMMAND ${GIT_EXECUTABLE} status --porcelain
            RESULT_VARIABLE resultGitStatus
            OUTPUT_VARIABLE repoStatus
            OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET
            WORKING_DIRECTORY ${repoPath}
    )
    IF (resultGitStatus)
        # not supposed to happen, assume clean anyway
        MESSAGE(WARNING "Calling git status on folder ${repoPath} failed")
        SET(${isClean}
                TRUE
                PARENT_SCOPE
                )
        RETURN()
    ENDIF ()

    IF (NOT "${repoStatus}" STREQUAL "")
        SET(${isClean}
                FALSE
                PARENT_SCOPE
                )
        RETURN()
    ENDIF ()

    # check for commited changes
    EXECUTE_PROCESS(
            COMMAND ${GIT_EXECUTABLE} diff -s --exit-code ${gitTag}
            RESULT_VARIABLE resultGitDiff
            OUTPUT_STRIP_TRAILING_WHITESPACE OUTPUT_QUIET
            WORKING_DIRECTORY ${repoPath}
    )

    IF (${resultGitDiff} EQUAL 0)
        SET(${isClean}
                TRUE
                PARENT_SCOPE
                )
    ELSE ()
        SET(${isClean}
                FALSE
                PARENT_SCOPE
                )
    ENDIF ()

ENDFUNCTION()

# Download and add a package from source
FUNCTION(CPMADDPACKAGE)
    LIST(LENGTH ARGN argnLength)
    IF (argnLength EQUAL 1)
        CPM_PARSE_ADD_PACKAGE_SINGLE_ARG("${ARGN}" ARGN)

        # The shorthand syntax implies EXCLUDE_FROM_ALL
        SET(ARGN "${ARGN};EXCLUDE_FROM_ALL;YES")
    ENDIF ()

    SET(oneValueArgs
            NAME
            FORCE
            VERSION
            GIT_TAG
            DOWNLOAD_ONLY
            GITHUB_REPOSITORY
            GITLAB_REPOSITORY
            BITBUCKET_REPOSITORY
            GIT_REPOSITORY
            SOURCE_DIR
            DOWNLOAD_COMMAND
            FIND_PACKAGE_ARGUMENTS
            NO_CACHE
            GIT_SHALLOW
            EXCLUDE_FROM_ALL
            SOURCE_SUBDIR
            )

    SET(multiValueArgs URL OPTIONS)

    CMAKE_PARSE_ARGUMENTS(CPM_ARGS "" "${oneValueArgs}" "${multiValueArgs}" "${ARGN}")

    # Set default values for arguments

    IF (NOT DEFINED CPM_ARGS_VERSION)
        IF (DEFINED CPM_ARGS_GIT_TAG)
            CPM_GET_VERSION_FROM_GIT_TAG("${CPM_ARGS_GIT_TAG}" CPM_ARGS_VERSION)
        ENDIF ()
    ENDIF ()

    IF (CPM_ARGS_DOWNLOAD_ONLY)
        SET(DOWNLOAD_ONLY ${CPM_ARGS_DOWNLOAD_ONLY})
    ELSE ()
        SET(DOWNLOAD_ONLY NO)
    ENDIF ()

    IF (DEFINED CPM_ARGS_GITHUB_REPOSITORY)
        SET(CPM_ARGS_GIT_REPOSITORY "https://github.com/${CPM_ARGS_GITHUB_REPOSITORY}.git")
    ELSEIF (DEFINED CPM_ARGS_GITLAB_REPOSITORY)
        SET(CPM_ARGS_GIT_REPOSITORY "https://gitlab.com/${CPM_ARGS_GITLAB_REPOSITORY}.git")
    ELSEIF (DEFINED CPM_ARGS_BITBUCKET_REPOSITORY)
        SET(CPM_ARGS_GIT_REPOSITORY "https://bitbucket.org/${CPM_ARGS_BITBUCKET_REPOSITORY}.git")
    ENDIF ()

    IF (DEFINED CPM_ARGS_GIT_REPOSITORY)
        LIST(APPEND CPM_ARGS_UNPARSED_ARGUMENTS GIT_REPOSITORY ${CPM_ARGS_GIT_REPOSITORY})
        IF (NOT DEFINED CPM_ARGS_GIT_TAG)
            SET(CPM_ARGS_GIT_TAG v${CPM_ARGS_VERSION})
        ENDIF ()

        # If a name wasn't provided, try to infer it from the git repo
        IF (NOT DEFINED CPM_ARGS_NAME)
            CPM_PACKAGE_NAME_FROM_GIT_URI(${CPM_ARGS_GIT_REPOSITORY} CPM_ARGS_NAME)
        ENDIF ()
    ENDIF ()

    SET(CPM_SKIP_FETCH FALSE)

    IF (DEFINED CPM_ARGS_GIT_TAG)
        LIST(APPEND CPM_ARGS_UNPARSED_ARGUMENTS GIT_TAG ${CPM_ARGS_GIT_TAG})
        # If GIT_SHALLOW is explicitly specified, honor the value.
        IF (DEFINED CPM_ARGS_GIT_SHALLOW)
            LIST(APPEND CPM_ARGS_UNPARSED_ARGUMENTS GIT_SHALLOW ${CPM_ARGS_GIT_SHALLOW})
        ENDIF ()
    ENDIF ()

    IF (DEFINED CPM_ARGS_URL)
        # If a name or version aren't provided, try to infer them from the URL
        LIST(GET CPM_ARGS_URL 0 firstUrl)
        CPM_PACKAGE_NAME_AND_VER_FROM_URL(${firstUrl} nameFromUrl verFromUrl)
        # If we fail to obtain name and version from the first URL, we could try other URLs if any.
        # However multiple URLs are expected to be quite rare, so for now we won't bother.

        # If the caller provided their own name and version, they trump the inferred ones.
        IF (NOT DEFINED CPM_ARGS_NAME)
            SET(CPM_ARGS_NAME ${nameFromUrl})
        ENDIF ()
        IF (NOT DEFINED CPM_ARGS_VERSION)
            SET(CPM_ARGS_VERSION ${verFromUrl})
        ENDIF ()

        LIST(APPEND CPM_ARGS_UNPARSED_ARGUMENTS URL "${CPM_ARGS_URL}")
    ENDIF ()

    # Check for required arguments

    IF (NOT DEFINED CPM_ARGS_NAME)
        MESSAGE(
                FATAL_ERROR
                "CPM: 'NAME' was not provided and couldn't be automatically inferred for package added with arguments: '${ARGN}'"
        )
    ENDIF ()

    # Check if package has been added before
    CPM_CHECK_IF_PACKAGE_ALREADY_ADDED(${CPM_ARGS_NAME} "${CPM_ARGS_VERSION}")
    IF (CPM_PACKAGE_ALREADY_ADDED)
        CPM_EXPORT_VARIABLES(${CPM_ARGS_NAME})
        RETURN()
    ENDIF ()

    # Check for manual overrides
    IF (NOT CPM_ARGS_FORCE AND NOT "${CPM_${CPM_ARGS_NAME}_SOURCE}" STREQUAL "")
        SET(PACKAGE_SOURCE ${CPM_${CPM_ARGS_NAME}_SOURCE})
        SET(CPM_${CPM_ARGS_NAME}_SOURCE "")
        CPMADDPACKAGE(
                NAME "${CPM_ARGS_NAME}"
                SOURCE_DIR "${PACKAGE_SOURCE}"
                EXCLUDE_FROM_ALL "${CPM_ARGS_EXCLUDE_FROM_ALL}"
                OPTIONS "${CPM_ARGS_OPTIONS}"
                SOURCE_SUBDIR "${CPM_ARGS_SOURCE_SUBDIR}"
                DOWNLOAD_ONLY "${DOWNLOAD_ONLY}"
                FORCE True
        )
        CPM_EXPORT_VARIABLES(${CPM_ARGS_NAME})
        RETURN()
    ENDIF ()

    # Check for available declaration
    IF (NOT CPM_ARGS_FORCE AND NOT "${CPM_DECLARATION_${CPM_ARGS_NAME}}" STREQUAL "")
        SET(declaration ${CPM_DECLARATION_${CPM_ARGS_NAME}})
        SET(CPM_DECLARATION_${CPM_ARGS_NAME} "")
        CPMADDPACKAGE(${declaration})
        CPM_EXPORT_VARIABLES(${CPM_ARGS_NAME})
        # checking again to ensure version and option compatibility
        CPM_CHECK_IF_PACKAGE_ALREADY_ADDED(${CPM_ARGS_NAME} "${CPM_ARGS_VERSION}")
        RETURN()
    ENDIF ()

    IF (CPM_USE_LOCAL_PACKAGES OR CPM_LOCAL_PACKAGES_ONLY)
        CPM_FIND_PACKAGE(${CPM_ARGS_NAME} "${CPM_ARGS_VERSION}" ${CPM_ARGS_FIND_PACKAGE_ARGUMENTS})

        IF (CPM_PACKAGE_FOUND)
            CPM_EXPORT_VARIABLES(${CPM_ARGS_NAME})
            RETURN()
        ENDIF ()

        IF (CPM_LOCAL_PACKAGES_ONLY)
            MESSAGE(
                    SEND_ERROR
                    "CPM: ${CPM_ARGS_NAME} not found via find_package(${CPM_ARGS_NAME} ${CPM_ARGS_VERSION})"
            )
        ENDIF ()
    ENDIF ()

    CPMREGISTERPACKAGE("${CPM_ARGS_NAME}" "${CPM_ARGS_VERSION}")

    IF (DEFINED CPM_ARGS_GIT_TAG)
        SET(PACKAGE_INFO "${CPM_ARGS_GIT_TAG}")
    ELSEIF (DEFINED CPM_ARGS_SOURCE_DIR)
        SET(PACKAGE_INFO "${CPM_ARGS_SOURCE_DIR}")
    ELSE ()
        SET(PACKAGE_INFO "${CPM_ARGS_VERSION}")
    ENDIF ()

    IF (DEFINED FETCHCONTENT_BASE_DIR)
        # respect user's FETCHCONTENT_BASE_DIR if set
        SET(CPM_FETCHCONTENT_BASE_DIR ${FETCHCONTENT_BASE_DIR})
    ELSE ()
        SET(CPM_FETCHCONTENT_BASE_DIR ${CMAKE_BINARY_DIR}/_deps)
    ENDIF ()

    IF (DEFINED CPM_ARGS_DOWNLOAD_COMMAND)
        LIST(APPEND CPM_ARGS_UNPARSED_ARGUMENTS DOWNLOAD_COMMAND ${CPM_ARGS_DOWNLOAD_COMMAND})
    ELSEIF (DEFINED CPM_ARGS_SOURCE_DIR)
        LIST(APPEND CPM_ARGS_UNPARSED_ARGUMENTS SOURCE_DIR ${CPM_ARGS_SOURCE_DIR})
    ELSEIF (CPM_SOURCE_CACHE AND NOT CPM_ARGS_NO_CACHE)
        STRING(TOLOWER ${CPM_ARGS_NAME} lower_case_name)
        SET(origin_parameters ${CPM_ARGS_UNPARSED_ARGUMENTS})
        LIST(SORT origin_parameters)
        IF (CPM_USE_NAMED_CACHE_DIRECTORIES)
            STRING(SHA1 origin_hash "${origin_parameters};NEW_CACHE_STRUCTURE_TAG")
            SET(download_directory ${CPM_SOURCE_CACHE}/${lower_case_name}/${origin_hash}/${CPM_ARGS_NAME})
        ELSE ()
            STRING(SHA1 origin_hash "${origin_parameters}")
            SET(download_directory ${CPM_SOURCE_CACHE}/${lower_case_name}/${origin_hash})
        ENDIF ()
        # Expand `download_directory` relative path. This is important because EXISTS doesn't work for
        # relative paths.
        GET_FILENAME_COMPONENT(download_directory ${download_directory} ABSOLUTE)
        LIST(APPEND CPM_ARGS_UNPARSED_ARGUMENTS SOURCE_DIR ${download_directory})
        IF (EXISTS ${download_directory})
            # avoid FetchContent modules to improve performance
            SET(${CPM_ARGS_NAME}_BINARY_DIR ${CPM_FETCHCONTENT_BASE_DIR}/${lower_case_name}-build)
            SET(${CPM_ARGS_NAME}_ADDED YES)
            SET(${CPM_ARGS_NAME}_SOURCE_DIR ${download_directory})

            IF (DEFINED CPM_ARGS_GIT_TAG)
                # warn if cache has been changed since checkout
                CPM_CHECK_GIT_WORKING_DIR_IS_CLEAN(${download_directory} ${CPM_ARGS_GIT_TAG} IS_CLEAN)
                IF (NOT ${IS_CLEAN})
                    MESSAGE(WARNING "Cache for ${CPM_ARGS_NAME} (${download_directory}) is dirty")
                ENDIF ()
            ENDIF ()

            CPM_ADD_SUBDIRECTORY(
                    "${CPM_ARGS_NAME}" "${DOWNLOAD_ONLY}"
                    "${${CPM_ARGS_NAME}_SOURCE_DIR}/${CPM_ARGS_SOURCE_SUBDIR}" "${${CPM_ARGS_NAME}_BINARY_DIR}"
                    "${CPM_ARGS_EXCLUDE_FROM_ALL}" "${CPM_ARGS_OPTIONS}"
            )
            SET(CPM_SKIP_FETCH TRUE)
            SET(PACKAGE_INFO "${PACKAGE_INFO} at ${download_directory}")
        ELSE ()
            # Enable shallow clone when GIT_TAG is not a commit hash. Our guess may not be accurate, but
            # it should guarantee no commit hash get mis-detected.
            IF (NOT DEFINED CPM_ARGS_GIT_SHALLOW)
                CPM_IS_GIT_TAG_COMMIT_HASH("${CPM_ARGS_GIT_TAG}" IS_HASH)
                IF (NOT ${IS_HASH})
                    LIST(APPEND CPM_ARGS_UNPARSED_ARGUMENTS GIT_SHALLOW TRUE)
                ENDIF ()
            ENDIF ()

            # remove timestamps so CMake will re-download the dependency
            FILE(REMOVE_RECURSE ${CPM_FETCHCONTENT_BASE_DIR}/${lower_case_name}-subbuild)
            SET(PACKAGE_INFO "${PACKAGE_INFO} to ${download_directory}")
        ENDIF ()
    ENDIF ()

    CPM_CREATE_MODULE_FILE(${CPM_ARGS_NAME} "CPMAddPackage(${ARGN})")

    IF (CPM_PACKAGE_LOCK_ENABLED)
        IF ((CPM_ARGS_VERSION AND NOT CPM_ARGS_SOURCE_DIR) OR CPM_INCLUDE_ALL_IN_PACKAGE_LOCK)
            CPM_ADD_TO_PACKAGE_LOCK(${CPM_ARGS_NAME} "${ARGN}")
        ELSEIF (CPM_ARGS_SOURCE_DIR)
            CPM_ADD_COMMENT_TO_PACKAGE_LOCK(${CPM_ARGS_NAME} "local directory")
        ELSE ()
            CPM_ADD_COMMENT_TO_PACKAGE_LOCK(${CPM_ARGS_NAME} "${ARGN}")
        ENDIF ()
    ENDIF ()

    MESSAGE(
            STATUS "${CPM_INDENT} adding package ${CPM_ARGS_NAME}@${CPM_ARGS_VERSION} (${PACKAGE_INFO})"
    )

    IF (NOT CPM_SKIP_FETCH)
        CPM_DECLARE_FETCH(
                "${CPM_ARGS_NAME}" "${CPM_ARGS_VERSION}" "${PACKAGE_INFO}" "${CPM_ARGS_UNPARSED_ARGUMENTS}"
        )
        CPM_FETCH_PACKAGE("${CPM_ARGS_NAME}" populated)
        IF (${populated})
            CPM_ADD_SUBDIRECTORY(
                    "${CPM_ARGS_NAME}" "${DOWNLOAD_ONLY}"
                    "${${CPM_ARGS_NAME}_SOURCE_DIR}/${CPM_ARGS_SOURCE_SUBDIR}" "${${CPM_ARGS_NAME}_BINARY_DIR}"
                    "${CPM_ARGS_EXCLUDE_FROM_ALL}" "${CPM_ARGS_OPTIONS}"
            )
        ENDIF ()
        CPM_GET_FETCH_PROPERTIES("${CPM_ARGS_NAME}")
    ENDIF ()

    SET(${CPM_ARGS_NAME}_ADDED YES)
    CPM_EXPORT_VARIABLES("${CPM_ARGS_NAME}")
ENDFUNCTION()

# Fetch a previously declared package
MACRO(CPMGETPACKAGE Name)
    IF (DEFINED "CPM_DECLARATION_${Name}")
        CPMADDPACKAGE(NAME ${Name})
    ELSE ()
        MESSAGE(SEND_ERROR "Cannot retrieve package ${Name}: no declaration available")
    ENDIF ()
ENDMACRO()

# export variables available to the caller to the parent scope expects ${CPM_ARGS_NAME} to be set
MACRO(CPM_EXPORT_VARIABLES name)
    SET(${name}_SOURCE_DIR
            "${${name}_SOURCE_DIR}"
            PARENT_SCOPE
            )
    SET(${name}_BINARY_DIR
            "${${name}_BINARY_DIR}"
            PARENT_SCOPE
            )
    SET(${name}_ADDED
            "${${name}_ADDED}"
            PARENT_SCOPE
            )
ENDMACRO()

# declares a package, so that any call to CPMAddPackage for the package name will use these
# arguments instead. Previous declarations will not be overriden.
MACRO(CPMDECLAREPACKAGE Name)
    IF (NOT DEFINED "CPM_DECLARATION_${Name}")
        SET("CPM_DECLARATION_${Name}" "${ARGN}")
    ENDIF ()
ENDMACRO()

FUNCTION(CPM_ADD_TO_PACKAGE_LOCK Name)
    IF (NOT CPM_DONT_CREATE_PACKAGE_LOCK)
        CPM_PRETTIFY_PACKAGE_ARGUMENTS(PRETTY_ARGN false ${ARGN})
        FILE(APPEND ${CPM_PACKAGE_LOCK_FILE} "# ${Name}\nCPMDeclarePackage(${Name}\n${PRETTY_ARGN})\n")
    ENDIF ()
ENDFUNCTION()

FUNCTION(CPM_ADD_COMMENT_TO_PACKAGE_LOCK Name)
    IF (NOT CPM_DONT_CREATE_PACKAGE_LOCK)
        CPM_PRETTIFY_PACKAGE_ARGUMENTS(PRETTY_ARGN true ${ARGN})
        FILE(APPEND ${CPM_PACKAGE_LOCK_FILE}
                "# ${Name} (unversioned)\n# CPMDeclarePackage(${Name}\n${PRETTY_ARGN}#)\n"
                )
    ENDIF ()
ENDFUNCTION()

# includes the package lock file if it exists and creates a target `cpm-write-package-lock` to
# update it
MACRO(CPMUSEPACKAGELOCK file)
    IF (NOT CPM_DONT_CREATE_PACKAGE_LOCK)
        GET_FILENAME_COMPONENT(CPM_ABSOLUTE_PACKAGE_LOCK_PATH ${file} ABSOLUTE)
        IF (EXISTS ${CPM_ABSOLUTE_PACKAGE_LOCK_PATH})
            INCLUDE(${CPM_ABSOLUTE_PACKAGE_LOCK_PATH})
        ENDIF ()
        IF (NOT TARGET cpm-update-package-lock)
            ADD_CUSTOM_TARGET(
                    cpm-update-package-lock COMMAND ${CMAKE_COMMAND} -E copy ${CPM_PACKAGE_LOCK_FILE}
                    ${CPM_ABSOLUTE_PACKAGE_LOCK_PATH}
            )
        ENDIF ()
        SET(CPM_PACKAGE_LOCK_ENABLED true)
    ENDIF ()
ENDMACRO()

# registers a package that has been added to CPM
FUNCTION(CPMREGISTERPACKAGE PACKAGE VERSION)
    LIST(APPEND CPM_PACKAGES ${PACKAGE})
    SET(CPM_PACKAGES
            ${CPM_PACKAGES}
            CACHE INTERNAL ""
            )
    SET("CPM_PACKAGE_${PACKAGE}_VERSION"
            ${VERSION}
            CACHE INTERNAL ""
            )
ENDFUNCTION()

# retrieve the current version of the package to ${OUTPUT}
FUNCTION(CPMGETPACKAGEVERSION PACKAGE OUTPUT)
    SET(${OUTPUT}
            "${CPM_PACKAGE_${PACKAGE}_VERSION}"
            PARENT_SCOPE
            )
ENDFUNCTION()

# declares a package in FetchContent_Declare
FUNCTION(CPM_DECLARE_FETCH PACKAGE VERSION INFO)
    IF (${CPM_DRY_RUN})
        MESSAGE(STATUS "${CPM_INDENT} package not declared (dry run)")
        RETURN()
    ENDIF ()

    FETCHCONTENT_DECLARE(${PACKAGE} ${ARGN})
ENDFUNCTION()

# returns properties for a package previously defined by cpm_declare_fetch
FUNCTION(CPM_GET_FETCH_PROPERTIES PACKAGE)
    IF (${CPM_DRY_RUN})
        RETURN()
    ENDIF ()
    FETCHCONTENT_GETPROPERTIES(${PACKAGE})
    STRING(TOLOWER ${PACKAGE} lpackage)
    SET(${PACKAGE}_SOURCE_DIR
            "${${lpackage}_SOURCE_DIR}"
            PARENT_SCOPE
            )
    SET(${PACKAGE}_BINARY_DIR
            "${${lpackage}_BINARY_DIR}"
            PARENT_SCOPE
            )
ENDFUNCTION()

# adds a package as a subdirectory if viable, according to provided options
FUNCTION(
        cpm_add_subdirectory
        PACKAGE
        DOWNLOAD_ONLY
        SOURCE_DIR
        BINARY_DIR
        EXCLUDE
        OPTIONS
)
    IF (NOT DOWNLOAD_ONLY AND EXISTS ${SOURCE_DIR}/CMakeLists.txt)
        IF (EXCLUDE)
            SET(addSubdirectoryExtraArgs EXCLUDE_FROM_ALL)
        ELSE ()
            SET(addSubdirectoryExtraArgs "")
        ENDIF ()
        IF (OPTIONS)
            # the policy allows us to change options without caching
            CMAKE_POLICY(SET CMP0077 NEW)
            SET(CMAKE_POLICY_DEFAULT_CMP0077 NEW)

            FOREACH (OPTION ${OPTIONS})
                CPM_PARSE_OPTION("${OPTION}")
                SET(${OPTION_KEY} "${OPTION_VALUE}")
            ENDFOREACH ()
        ENDIF ()
        SET(CPM_OLD_INDENT "${CPM_INDENT}")
        SET(CPM_INDENT "${CPM_INDENT} ${PACKAGE}:")
        ADD_SUBDIRECTORY(${SOURCE_DIR} ${BINARY_DIR} ${addSubdirectoryExtraArgs})
        SET(CPM_INDENT "${CPM_OLD_INDENT}")
    ENDIF ()
ENDFUNCTION()

# downloads a previously declared package via FetchContent and exports the variables
# `${PACKAGE}_SOURCE_DIR` and `${PACKAGE}_BINARY_DIR` to the parent scope
FUNCTION(CPM_FETCH_PACKAGE PACKAGE populated)
    SET(${populated}
            FALSE
            PARENT_SCOPE
            )
    IF (${CPM_DRY_RUN})
        MESSAGE(STATUS "${CPM_INDENT} package ${PACKAGE} not fetched (dry run)")
        RETURN()
    ENDIF ()

    FETCHCONTENT_GETPROPERTIES(${PACKAGE})

    STRING(TOLOWER "${PACKAGE}" lower_case_name)

    IF (NOT ${lower_case_name}_POPULATED)
        FETCHCONTENT_POPULATE(${PACKAGE})
        SET(${populated}
                TRUE
                PARENT_SCOPE
                )
    ENDIF ()

    SET(${PACKAGE}_SOURCE_DIR
            ${${lower_case_name}_SOURCE_DIR}
            PARENT_SCOPE
            )
    SET(${PACKAGE}_BINARY_DIR
            ${${lower_case_name}_BINARY_DIR}
            PARENT_SCOPE
            )
ENDFUNCTION()

# splits a package option
FUNCTION(CPM_PARSE_OPTION OPTION)
    STRING(REGEX MATCH "^[^ ]+" OPTION_KEY "${OPTION}")
    STRING(LENGTH "${OPTION}" OPTION_LENGTH)
    STRING(LENGTH "${OPTION_KEY}" OPTION_KEY_LENGTH)
    IF (OPTION_KEY_LENGTH STREQUAL OPTION_LENGTH)
        # no value for key provided, assume user wants to set option to "ON"
        SET(OPTION_VALUE "ON")
    ELSE ()
        MATH(EXPR OPTION_KEY_LENGTH "${OPTION_KEY_LENGTH}+1")
        STRING(SUBSTRING "${OPTION}" "${OPTION_KEY_LENGTH}" "-1" OPTION_VALUE)
    ENDIF ()
    SET(OPTION_KEY
            "${OPTION_KEY}"
            PARENT_SCOPE
            )
    SET(OPTION_VALUE
            "${OPTION_VALUE}"
            PARENT_SCOPE
            )
ENDFUNCTION()

# guesses the package version from a git tag
FUNCTION(CPM_GET_VERSION_FROM_GIT_TAG GIT_TAG RESULT)
    STRING(LENGTH ${GIT_TAG} length)
    IF (length EQUAL 40)
        # GIT_TAG is probably a git hash
        SET(${RESULT}
                0
                PARENT_SCOPE
                )
    ELSE ()
        STRING(REGEX MATCH "v?([0123456789.]*).*" _ ${GIT_TAG})
        SET(${RESULT}
                ${CMAKE_MATCH_1}
                PARENT_SCOPE
                )
    ENDIF ()
ENDFUNCTION()

# guesses if the git tag is a commit hash or an actual tag or a branch nane.
FUNCTION(CPM_IS_GIT_TAG_COMMIT_HASH GIT_TAG RESULT)
    STRING(LENGTH "${GIT_TAG}" length)
    # full hash has 40 characters, and short hash has at least 7 characters.
    IF (length LESS 7 OR length GREATER 40)
        SET(${RESULT}
                0
                PARENT_SCOPE
                )
    ELSE ()
        IF (${GIT_TAG} MATCHES "^[a-fA-F0-9]+$")
            SET(${RESULT}
                    1
                    PARENT_SCOPE
                    )
        ELSE ()
            SET(${RESULT}
                    0
                    PARENT_SCOPE
                    )
        ENDIF ()
    ENDIF ()
ENDFUNCTION()

FUNCTION(CPM_PRETTIFY_PACKAGE_ARGUMENTS OUT_VAR IS_IN_COMMENT)
    SET(oneValueArgs
            NAME
            FORCE
            VERSION
            GIT_TAG
            DOWNLOAD_ONLY
            GITHUB_REPOSITORY
            GITLAB_REPOSITORY
            GIT_REPOSITORY
            SOURCE_DIR
            DOWNLOAD_COMMAND
            FIND_PACKAGE_ARGUMENTS
            NO_CACHE
            GIT_SHALLOW
            )
    SET(multiValueArgs OPTIONS)
    CMAKE_PARSE_ARGUMENTS(CPM_ARGS "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    FOREACH (oneArgName ${oneValueArgs})
        IF (DEFINED CPM_ARGS_${oneArgName})
            IF (${IS_IN_COMMENT})
                STRING(APPEND PRETTY_OUT_VAR "#")
            ENDIF ()
            IF (${oneArgName} STREQUAL "SOURCE_DIR")
                STRING(REPLACE ${CMAKE_SOURCE_DIR} "\${CMAKE_SOURCE_DIR}" CPM_ARGS_${oneArgName}
                        ${CPM_ARGS_${oneArgName}}
                        )
            ENDIF ()
            STRING(APPEND PRETTY_OUT_VAR "  ${oneArgName} ${CPM_ARGS_${oneArgName}}\n")
        ENDIF ()
    ENDFOREACH ()
    FOREACH (multiArgName ${multiValueArgs})
        IF (DEFINED CPM_ARGS_${multiArgName})
            IF (${IS_IN_COMMENT})
                STRING(APPEND PRETTY_OUT_VAR "#")
            ENDIF ()
            STRING(APPEND PRETTY_OUT_VAR "  ${multiArgName}\n")
            FOREACH (singleOption ${CPM_ARGS_${multiArgName}})
                IF (${IS_IN_COMMENT})
                    STRING(APPEND PRETTY_OUT_VAR "#")
                ENDIF ()
                STRING(APPEND PRETTY_OUT_VAR "    \"${singleOption}\"\n")
            ENDFOREACH ()
        ENDIF ()
    ENDFOREACH ()

    IF (NOT "${CPM_ARGS_UNPARSED_ARGUMENTS}" STREQUAL "")
        IF (${IS_IN_COMMENT})
            STRING(APPEND PRETTY_OUT_VAR "#")
        ENDIF ()
        STRING(APPEND PRETTY_OUT_VAR " ")
        FOREACH (CPM_ARGS_UNPARSED_ARGUMENT ${CPM_ARGS_UNPARSED_ARGUMENTS})
            STRING(APPEND PRETTY_OUT_VAR " ${CPM_ARGS_UNPARSED_ARGUMENT}")
        ENDFOREACH ()
        STRING(APPEND PRETTY_OUT_VAR "\n")
    ENDIF ()

    SET(${OUT_VAR}
            ${PRETTY_OUT_VAR}
            PARENT_SCOPE
            )

ENDFUNCTION()
