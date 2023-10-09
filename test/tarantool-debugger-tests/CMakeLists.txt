add_custom_target(tarantool-gdb-tests
  DEPENDS ${LUAJIT_TEST_BINARY}
)

add_custom_target(tarantool-lldb-tests
  DEPENDS ${LUAJIT_TEST_BINARY}
)

# Debug info is required for testing of extensions.
if(NOT (CMAKE_BUILD_TYPE MATCHES Debug))
  message(WARNING "not a DEBUG build, tarantool-*db-tests are dummy")
  return()
endif()

# MacOS asks for permission to debug a process even when the
# machine is set into development mode. To solve the issue,
# it is required to add relevant users to the `_developer` user
# group in MacOS. Disabled for now.
if(CMAKE_SYSTEM_NAME STREQUAL "Darwin" AND DEFINED ENV{CI})
  message(WARNING "non-interactive debugging on macOS, tarantool-*db-tests are dummy")
  return()
endif()

find_program(PROVE prove)
if(NOT PROVE)
  message(WARNING "`prove' is not found, so tarantool-*db-tests target are dummy")
  return()
endif()

find_package(PythonInterp)
if(NOT PYTHONINTERP_FOUND)
  message(WARNING "`python' is not found, so tarantool-*db-tests target are dummy")
  return()
endif()

set(DEBUGGER_TEST_FLAGS --failures)
if(CMAKE_VERBOSE_MAKEFILE)
  list(APPEND DEBUGGER_TEST_FLAGS --verbose)
endif()

set(DEBUGGER_TEST_ENV
  "LUAJIT_TEST_BINARY=${LUAJIT_TEST_BINARY}"
  # Suppresses __pycache__ generation.
  "PYTHONDONTWRITEBYTECODE=1"
  "DEBUGGER_EXTENSION_PATH=${PROJECT_SOURCE_DIR}/src/luajit_dbg.py"
)

find_program(GDB gdb)
if(GDB)
  set(GDB_TEST_ENV ${DEBUGGER_TEST_ENV}
    "DEBUGGER_COMMAND=${GDB}"
  )
  add_custom_command(TARGET tarantool-gdb-tests
    COMMENT "Running luajit_dbg.py tests with gdb"
    COMMAND
    ${GDB_TEST_ENV}
      ${PROVE} ${CMAKE_CURRENT_SOURCE_DIR}/luajit_dbg.test.md
      --exec '${PYTHON_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/run.py'
      ${DEBUGGER_TEST_FLAGS}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
  )
else()
  message(WARNING "`gdb' is not found, so tarantool-gdb-tests target is dummy")
endif()

find_program(LLDB lldb)
if(LLDB)
  set(LLDB_TEST_ENV ${DEBUGGER_TEST_ENV}
    "DEBUGGER_COMMAND=${LLDB}"
  )
  add_custom_command(TARGET tarantool-lldb-tests
    COMMENT "Running luajit_dbg.py tests with lldb"
    COMMAND
    ${LLDB_TEST_ENV}
      ${PROVE} ${CMAKE_CURRENT_SOURCE_DIR}/luajit_dbg.test.md
      --exec '${PYTHON_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/run.py'
      ${DEBUGGER_TEST_FLAGS}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
  )
else()
  message(WARNING "`lldb' is not found, so tarantool-lldb-tests target is dummy")
endif()
