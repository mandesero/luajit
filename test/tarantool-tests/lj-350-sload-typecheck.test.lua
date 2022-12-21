local tap = require('tap')
local traceinfo = require('jit.util').traceinfo

-- Test file to demonstrate the incorrect GC64 JIT asembling
-- `IR_SLOAD`.
-- See also https://github.com/LuaJIT/LuaJIT/pull/350.
local test = tap.test('lj-350-sload-typecheck')

test:plan(1)

-- Contains only IR_SLOAD after recording.
local function sload(arg)
  return arg
end

local tab_arg = {}

-- Reset JIT, remove any other traces.
jit.off()
jit.flush()

assert(not traceinfo(1), 'no traces compiled after flush')

-- Try to execute the compiled trace with IR_SLOAD, if the emitted
-- mcode is incorrect, assertion guard type check will fail even
-- for the correct type of argument and a new trace is recorded.
jit.opt.start('hotloop=1', 'hotexit=1')

jit.on()

-- Make the function hot.
sload(tab_arg)
-- Compile the trace.
sload(tab_arg)
-- Execute trace and try to compile a trace from the side exit.
sload(tab_arg)

jit.off()

test:ok(not traceinfo(2), 'the second trace should not be compiled')

os.exit(test:check() and 0 or 1)
