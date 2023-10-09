# This file provides filters and logic for running the debugger tests. It is
# imported by the runner and the test_base.py, so its symbols become exposed
# to the globals(). Thus, they can be called during the specification
# execution.
import re
import subprocess
import os
import sys
import tempfile
from threading import Timer

LEGACY = re.match(r'^2\.', sys.version)

LUAJIT_BINARY = os.environ['LUAJIT_TEST_BINARY']
EXTENSION = os.environ['DEBUGGER_EXTENSION_PATH']
DEBUGGER_COMMAND = os.environ['DEBUGGER_COMMAND']
LLDB = 'lldb' in DEBUGGER_COMMAND
TIMEOUT = 10

active_block = None
output = ''
dbg_cmds = ''


def persist(data):
    tmp = tempfile.NamedTemporaryFile(mode='w')
    tmp.write(data)
    tmp.flush()
    return tmp


def execute_process(cmd, timeout=TIMEOUT):
    if LEGACY:
        # XXX: The Python 2.7 version of `subprocess.Popen` doesn't have a
        # timeout option, so the required functionality was implemented via
        # `threading.Timer`.
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE)
        timer = Timer(TIMEOUT, process.kill)
        timer.start()
        stdout, _ = process.communicate()
        timer.cancel()

        # XXX: If the timeout is exceeded and the process is killed by the
        # timer, then the return code is non-zero, and we are going to blow up.
        assert process.returncode == 0
        return stdout.decode('ascii')
    else:
        process = subprocess.run(cmd, capture_output=True, timeout=TIMEOUT)
        return process.stdout.decode('ascii')


def load_extension_cmd():
    load_cmd = 'command script import {ext}' if LLDB else 'source {ext}'
    return load_cmd.format(ext=EXTENSION)


def filter_debugger_output(output):
    descriptor = '(lldb)' if LLDB else '(gdb)'
    return ''.join(
        filter(
            lambda line: not line.startswith(descriptor),
            output.splitlines(True),
        )
    )


def lua(data):
    global output

    exec_file_flag = '-s' if LLDB else '-x'
    inferior_args_flag = '--' if LLDB else '--args'

    tmp_cmds = persist(dbg_cmds)
    lua_script = persist(data)

    process_cmd = [
        DEBUGGER_COMMAND,
        exec_file_flag,
        tmp_cmds.name,
        inferior_args_flag,
        LUAJIT_BINARY,
        lua_script.name,
    ]

    output = execute_process(process_cmd)
    output = filter_debugger_output(output)

    tmp_cmds.close()
    lua_script.close()


def run_until_breakpoint(location):
    return [
        'b {loc}'.format(loc=location),
        'process launch' if LLDB else 'r',
        'n',
    ]


def lj_cf_print(data):
    return run_until_breakpoint('lj_cf_print'), data


def lj_cf_dofile(data):
    return run_until_breakpoint('lj_cf_dofile'), data


def lj_cf_unpack(data):
    return run_until_breakpoint('lj_cf_unpack'), data


def debug(data):
    global dbg_cmds
    setup_cmds, extension_cmds = data
    setup_cmds.append(load_extension_cmd())

    if extension_cmds:
        setup_cmds.append(extension_cmds)

    setup_cmds.append('q')
    dbg_cmds = '\n'.join(setup_cmds)


def test_ok(result):
    status = 'ok' if result else 'not ok'
    print(
        '{status} - {test_name}'.format(
            status=status,
            test_name=active_block.name,
        )
    )


def expected(data):
    test_ok(data in output)


def matches(data):
    test_ok(re.search(data, output))


def runner(blocks):
    print('1..{n}'.format(n=len(blocks)))
    global active_block
    for block in blocks:
        active_block = block
        for section in block.sections:
            globals()[section.name](section.pipeline(section.data.strip()))
