local tap = require('tap')

local test = tap.test('lj-994-instable-types-during-loop-unroll'):skipcond({
  ['Test requires JIT enabled'] = not jit.status(),
})

-- Test file to demonstrate LuaJIT misbehaviour during loop
-- unrolling and load forwarding for newly created tables.
-- See also https://github.com/LuaJIT/LuaJIT/issues/994.

-- TODO: test that compiled traces don't always exit by the type
-- guard. See also the comment for the TDUP test chunk.
test:plan(1)

-- TNEW.
local result
local stored_tab = {1}
local slot = {}
local key = 1

jit.opt.start('hotloop=1')
-- The trouble happens during loop unrolling when we copy
-- `>+ num ALOAD` IR in the context of the table on the previous
-- iteration instead of a new one created via TNEW containing no
-- values (so type nil should be used instead of num).
for _ = 1, 5 do
  local t = slot
  -- Use a non-constant key to avoid LJ_TRERR_GFAIL and undoing
  -- the loop.
  result = t[key]
  -- Swap table loaded by SLOAD to the created via TNEW.
  slot = _ % 2 ~= 0 and stored_tab or {}
end
test:is(result, nil, 'TNEW load forwarding was successful')

-- TDUP.
--[[
-- FIXME: Disable test case for now. Enable, with another
-- backported commit with a fix for the aforementioned issue
-- (and after patch "Improve assertions.").
-- Test taken trace exits too.
for _ = 1, 5 do
  local t = slot
  -- Now use constant key slot to get necessary branch.
  -- LJ_TRERR_GFAIL isn't triggered here.
  -- See `fwd_ahload()` in <src/lj_opt_mem.c> for details.
  result = t[1]
  slot = _ % 2 ~= 0 and stored_tab or {true}
end
test:is(result, true, 'TDUP load forwarding was successful')
]]

os.exit(test:check() and 0 or 1)
