# Test suite that has been moved from Tarantool repository in
# scope of https://github.com/tarantool/tarantool/issues/4478.

# See the rationale in the root CMakeLists.txt.
cmake_minimum_required(VERSION 3.1 FATAL_ERROR)

macro(BuildTestCLib lib sources)
  add_library(${lib} SHARED EXCLUDE_FROM_ALL ${sources})
  target_include_directories(${lib} PRIVATE
    ${LUAJIT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}
  )
  set_target_properties(${lib} PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
    PREFIX ""
  )

  # XXX: This change affects the current cmake variable scope and
  # so a user should care to don't use it in a top level scope.
  # The dynamic libraries are loaded with LuaJIT binary and use
  # symbols from it. So it is totally OK to have unresolved
  # symbols at build time.
  if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    set_target_properties(${lib} PROPERTIES
      LINK_FLAGS "-undefined dynamic_lookup"
    )
  else()
    # FIXME: Unfortunately, there is no another way to suppress
    # this linker option, so just strip it out from the flags.
    string(REPLACE "-Wl,--no-undefined" ""
      CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS}"
    )
  endif()
  # XXX: Append the lib to be built to the dependency list.
  # Unfortunately, there is no convenient way in CMake to extend
  # the list in parent scope other than join two strings with
  # semicolon. If one finds the normal way to make it work, feel
  # free to reach me.
  set(TESTLIBS "${lib};${TESTLIBS}" PARENT_SCOPE)
  # Add the directory where the lib is built to the LUA_CPATH
  # environment variable, so LuaJIT can find and load it.
  # XXX: Here we see the other side of the coin. If one joins two
  # strings with semicolon, the value automatically becomes a
  # list. I found a single working solution to make LUA_CPATH be
  # a string via "escaping" the semicolon right in string
  # interpolation.
  set(LUA_CPATH "${CMAKE_CURRENT_BINARY_DIR}/?${CMAKE_SHARED_LIBRARY_SUFFIX}\;${LUA_CPATH}" PARENT_SCOPE)
  # Also add this directory to LD_LIBRARY_PATH environment
  # variable, so FFI machinery can find and load it.
  set(LD_LIBRARY_PATH "${CMAKE_CURRENT_BINARY_DIR}:${LD_LIBRARY_PATH}" PARENT_SCOPE)
endmacro()

add_subdirectory(ffi-ccall)
add_subdirectory(gh-4427-ffi-sandwich)
add_subdirectory(gh-5813-resolving-of-c-symbols/both)
add_subdirectory(gh-5813-resolving-of-c-symbols/hash)
add_subdirectory(gh-5813-resolving-of-c-symbols/gnuhash)
add_subdirectory(gh-5813-resolving-of-c-symbols/stripped)
add_subdirectory(gh-6098-fix-side-exit-patching-on-arm64)
add_subdirectory(gh-6189-cur_L)
add_subdirectory(lj-49-bad-lightuserdata)
add_subdirectory(lj-601-fix-gc-finderrfunc)
add_subdirectory(lj-727-lightuserdata-itern)
add_subdirectory(lj-flush-on-trace)
add_subdirectory(misclib-getmetrics-capi)
add_subdirectory(misclib-sysprof-capi)

# The part of the memory profiler toolchain is located in tools
# directory, jit, profiler, and bytecode toolchains are located
# in src/ directory and auxiliary tests-related modules are
# located in the current directory (but tests are run in the
# binary directory), so LUA_PATH need to be updated.
set(LUA_PATH
  "${CMAKE_CURRENT_SOURCE_DIR}/?.lua\;${PROJECT_SOURCE_DIR}/tools/?.lua\;${PROJECT_SOURCE_DIR}/src/?.lua"
)

# XXX: Since the auxiliary libraries are built as a dynamically
# loaded modules on MacOS instead of shared libraries as it is
# done on Linux and BSD, another environment variable should be
# used to guide <ffi.load> while searching the extension.
if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  list(APPEND LUA_TEST_ENV_MORE DYLD_LIBRARY_PATH="${LD_LIBRARY_PATH}")
else()
  list(APPEND LUA_TEST_ENV_MORE LD_LIBRARY_PATH="${LD_LIBRARY_PATH}")
endif()

# LUA_CPATH and LD_LIBRARY_PATH variables and also TESTLIBS list
# with dependecies are set in scope of BuildTestLib macro.
# FIXME
add_custom_target(tarantool-tests
  DEPENDS ${LUAJIT_TEST_BINARY} ${TESTLIBS}
)

file(GLOB_RECURSE tests ${CMAKE_CURRENT_SOURCE_DIR} "*.test.lua")
foreach(path ${tests})
  get_filename_component(test_name ${path} NAME)
  set(test_title "test/tarantool-tests/${test_name}")
  message(STATUS "Add ${test_title}")
  add_test(NAME ${test_title}
           COMMAND ${LUAJIT_TEST_COMMAND} ${path}
           WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
  )
  set_tests_properties(${test_title}
                       PROPERTIES ENVIRONMENT LUA_PATH=${LUA_PATH}:LUA_CPATH=${LUA_CPATH}:${LUA_TEST_ENV_MORE})
  set_property(TEST ${test_title} PROPERTY LABELS tarantool)
endforeach()
