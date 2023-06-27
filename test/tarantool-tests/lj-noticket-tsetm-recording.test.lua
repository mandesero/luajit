local tap = require('tap')
local test = tap.test('lj-noticket-tsetm'):skipcond({
  ['Test requires JIT enabled'] = not jit.status(),
})

test:plan(1)

local TEST_VALUE = '4'
local TEST_IDX = 4

local function nil3slots()
  return nil, nil, nil, TEST_VALUE
end

local t
local function test_tsetm(...)
  -- With enabled JIT dump L->top is rewritten by vmevent.
  -- After that JIT top slot compairing with the frame during
  -- `rec_check_slots()`.
  t = {nil3slots()}
  return nil3slots(...)
end

-- Additional frame to reduce baseslot value.
local function wrap()
  test_tsetm()
end

-- Need bytecode dump only (every bc instruction).
require('jit.dump').start('b', '/dev/null')
jit.opt.start('hotloop=1')

wrap()
wrap()
wrap()

test:ok(t[TEST_IDX] == TEST_VALUE, 'BC_TSETM recording')

os.exit(test:check() and 0 or 1)
