find_program(CODESPELL codespell)

list(APPEND CODESPELL_WHITELIST ${PROJECT_SOURCE_DIR}/src/lj_mapi.c)
list(APPEND CODESPELL_WHITELIST ${PROJECT_SOURCE_DIR}/src/lj_sysprof.c)
list(APPEND CODESPELL_WHITELIST ${PROJECT_SOURCE_DIR}/src/lj_utils_leb128.c)
list(APPEND CODESPELL_WHITELIST ${PROJECT_SOURCE_DIR}/src/lj_wbuf.c)
list(APPEND CODESPELL_WHITELIST ${PROJECT_SOURCE_DIR}/src/luajit-gdb.py)
list(APPEND CODESPELL_WHITELIST ${PROJECT_SOURCE_DIR}/src/luajit_lldb.py)
list(APPEND CODESPELL_WHITELIST ${PROJECT_SOURCE_DIR}/test/CMakeLists.txt)
list(APPEND CODESPELL_WHITELIST ${PROJECT_SOURCE_DIR}/test/tarantool-c-tests)
list(APPEND CODESPELL_WHITELIST ${PROJECT_SOURCE_DIR}/test/tarantool-tests)
list(APPEND CODESPELL_WHITELIST ${PROJECT_SOURCE_DIR}/tools)

set(IGNORE_WORDS ${PROJECT_SOURCE_DIR}/tools/codespell-ignore-words.txt)

add_custom_target(${PROJECT_NAME}-codespell)
if (CODESPELL)
  add_custom_command(TARGET ${PROJECT_NAME}-codespell
    COMMENT "Running codespell"
    COMMAND
      ${CODESPELL}
        --ignore-words ${IGNORE_WORDS}
        --skip ${IGNORE_WORDS}
        --check-filenames
        ${CODESPELL_WHITELIST}
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
  )
else ()
  set(WARN_MSG "`codespell' is not found, "
               "so ${PROJECT_NAME}-codespell target is dummy")
  add_custom_command(TARGET ${PROJECT_NAME}-codespell
    COMMAND ${CMAKE_COMMAND} -E cmake_echo_color --red ${MSG}
    COMMENT ${MSG}
  )
endif (CODESPELL)
