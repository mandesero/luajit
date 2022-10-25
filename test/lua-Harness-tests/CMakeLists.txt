# Test suite that has been added from lua-Harness test suite
# in scope of https://github.com/tarantool/tarantool/issues/5844.

# See the rationale in the root CMakeLists.txt
cmake_minimum_required(VERSION 3.1 FATAL_ERROR)

# Tests create temporary files (see 303-package.t and 411-luajit.t for
# example) to require. Also, they require some files from original test 
# source directory.
set(LUA_PATH "./?.lua\;${CMAKE_CURRENT_SOURCE_DIR}/?.lua\;${LUAJIT_SOURCE_DIR}/?.lua\;${LUAJIT_BINARY_DIR}/?.lua")

# FIXME
add_custom_target(lua-Harness-tests DEPENDS ${LUAJIT_TEST_BINARY})

file(GLOB_RECURSE tests ${CMAKE_CURRENT_SOURCE_DIR} "*.t")
foreach(path ${tests})
  get_filename_component(test_name ${path} NAME)
  get_filename_component(basedir ${path} DIRECTORY)
  get_filename_component(suite ${basedir} NAME)
  if ("${suite}" STREQUAL "lexicojit" OR
      "${suite}" STREQUAL "lexico52" OR
      "${suite}" STREQUAL "lexico53" OR
      "${suite}" STREQUAL "lexico52")
    set(test_title "test/lua-Harness/${suite}/${test_name}")
  else()
    set(test_title "test/lua-Harness/${test_name}")
  endif()
  message(STATUS "Add ${test_title}")
  add_test(NAME ${test_title}
           COMMAND ${LUAJIT_TEST_COMMAND} -l profile_luajit21 ${path}
           WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
  )
  set_tests_properties(${test_title}
                       PROPERTIES ENVIRONMENT "LUA_PATH=${LUA_PATH}")
  set_property(TEST ${test_title} PROPERTY LABELS lua-Harness)
endforeach()

# vim: expandtab tabstop=2 shiftwidth=2
