local tap = require('tap')
-- Test to demonstrate the incorrect JIT behaviour when splitting
-- IR_POW.
-- See also https://github.com/LuaJIT/LuaJIT/issues/9.
local test = tap.test('lj-9-pow-inconsistencies'):skipcond({
  ['Test requires JIT enabled'] = not jit.status(),
})

local nan = 0 / 0
local inf = math.huge

-- Table with some corner cases to check:
local INTERESTING_VALUES = {
  -- 0, -0, 1, -1 special cases with nan, inf, etc..
  0, -0, 1, -1, nan, inf, -inf,
  -- x ^  inf = 0 (inf), if |x| < 1 (|x| > 1).
  -- x ^ -inf = inf (0), if |x| < 1 (|x| > 1).
  0.999999, 1.000001, -0.999999, -1.000001,
}
test:plan(1 + (#INTERESTING_VALUES) ^ 2)

jit.opt.start('hotloop=1')

-- The JIT engine tries to split b^c to exp2(c * log2(b)).
-- For some cases for IEEE754 we can see, that
-- (double)exp2((double)log2(x)) != x, due to mathematical
-- functions accuracy and double precision restrictions.
-- Just use some numbers to observe this misbehaviour.
local res = {}
local cnt = 1
while cnt < 4 do
  -- XXX: use local variable to prevent folding via parser.
  local b = -0.90000000001
  res[cnt] = 1000 ^ b
  cnt = cnt + 1
end

test:samevalues(res, 'consistent pow operator behaviour for corner case')

-- Prevent JIT side effects for parent loops.
jit.off()
for i = 1, #INTERESTING_VALUES do
  for j = 1, #INTERESTING_VALUES do
    local b = INTERESTING_VALUES[i]
    local c = INTERESTING_VALUES[j]
    local results = {}
    local counter = 1
    jit.on()
    while counter < 4 do
      results[counter] = b ^ c
      counter = counter + 1
    end
    -- Prevent JIT side effects.
    jit.off()
    jit.flush()
    test:samevalues(
      results,
      ('consistent pow operator behaviour for (%s)^(%s)'):format(b, c)
    )
  end
end

test:done(true)
