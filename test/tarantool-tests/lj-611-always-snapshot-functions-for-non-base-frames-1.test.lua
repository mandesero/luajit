local tap = require('tap')
local test = tap.test('lj-611-always-snapshot-functions-for-non-base-frames-1'):skipcond({
  ['Test requires JIT enabled'] = not jit.status(),
})

-- GC64: Function missing in snapshot for non-base frame
-- https://github.com/LuaJIT/LuaJIT/issues/611

test:plan(1)

jit.opt.start('hotloop=1', 'hotexit=1')

local inner_counter = 0
local SIDE_START = 1
-- Lower frame to return from `inner()` function side trace.
-- TODO: Give a reason for vararg func.
local function lower_frame(...)
  local inner = function()
    if inner_counter > SIDE_START then
      return
    end
    inner_counter = inner_counter + 1
  end
  inner(..., inner(inner()))
end

-- Compile `inner()` function.
lower_frame()
lower_frame()
-- Compile hotexit
lower_frame()
-- Take side exit from side trace.
lower_frame(1)

test:ok(true, 'function is present in snapshot')
test:done(true)
