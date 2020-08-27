local tap = require('tap')
local test = tap.test('lj-611-always-snapshot-functions-for-non-base-frames'):skipcond({
  ['Test requires JIT enabled'] = not jit.status(),
})

test:plan(1)

jit.opt.start('hotloop=1', 'hotexit=1')

-- Test reproduces a bug "GC64: Function missing in snapshot for non-base
-- frame" [1], and based on reproducer described in [2].
--
-- [1]: https://github.com/LuaJIT/LuaJIT/issues/611
-- [2]: https://github.com/LuaJIT/LuaJIT/issues/611#issuecomment-679228156
--
-- Function `outer` is recorded to a trace and calls a builtin function that is
-- not JIT-compilable and therefore triggers exit to interpreter, and then it
-- resumes tracing just after the call returns - this is a trace stitching.
-- Then, within the call, we need the potential for a side trace. Finally, we need
-- that side exit to be taken enough for the exit to be compiled into a trace.
-- The loop at the bottom has enough iterations to trigger JIT compilation, and
-- enough more on top on trigger compilation of the not case. Compilation of
-- this case hits the assertion failure.

local inner
for _ = 1, 3 do
  inner = function(_, i)
    return i < 4
  end
end

local function outer(i)
  -- The function `string.gsub` is not JIT-compilable and triggers a trace
  -- exit. For example, `string.gmatch` and `string.match` are suitable as
  -- well.
  -- See https://github.com/tarantool/tarantool/wiki/LuaJIT-Not-Yet-Implemented.
  inner(string.gsub('', '', ''), i)
end

for i = 1, 4 do
  outer(i)
end

test:ok(true, 'function is present in snapshot')
test:done(true)
