local tap = require('tap')
local test = tap.test('lj-noticket-tdup-load-fwd-mismatch'):skipcond({
  ['Test requires JIT enabled'] = not jit.status(),
})

jit.opt.start('hotloop=1')

-- Same IR type for table and stack and different type.
test:plan(4)

local result
local expected = 'result'

-- TDUP different types.
for i = 6, 9 do
  local t = {1, 2, 3, 4, 5, 6, 7, 8}
  t[i] = expected
  t[i + 1] = expected
  t[1] = nil
  t[2] = nil
  t[3] = nil
  t[4] = nil
  t[5] = nil
  t[6] = nil
  t['1000'] = 1000
  result = t[8]
end

-- Checked for assertion guard, on the last iteration we get
-- the value on initializatoin.
test:ok(result == 8, 'TDUP load forwarding different types')

local alias_store = {{}, {}, {}, {}, {}}
for i = 6, 9 do
  local t = {1, 2, 3, 4, 5, 6, 7, 8}
  -- Store table, to be aliased later.
  alias_store[#alias_store + 1] = t
  local alias = alias_store[i]
  alias[i] = expected
  alias[i + 1] = expected
  alias[1] = nil
  alias[2] = nil
  alias[3] = nil
  alias[4] = nil
  alias[5] = nil
  alias[6] = nil
  alias['1000'] = 1000
  result = t[8]
end

-- Checked for assertion guard, on the last iteration we get
-- the value on initializatoin.
test:ok(result == 8, 'TDUP load forwarding different types, aliased table')

-- TDUP same type, different values.
for i = 6, 9 do
  local t = {1, 2, 3, 4, 5, 6, 'other', 'other'}
  t[i] = expected
  t[i + 1] = expected
  t[1] = nil
  t[2] = nil
  t[3] = nil
  t[4] = nil
  t[5] = nil
  t[6] = nil
  t['1000'] = 1000
  result = t[8]
end

-- Checked for assertion guard, on the last iteration we get
-- the value on initializatoin.
test:ok(result == 'other', 'TDUP load forwarding same type different values')

alias_store = {{}, {}, {}, {}, {}}
for i = 6, 9 do
  local t = {1, 2, 3, 4, 5, 6, 'other', 'other'}
  -- Store table, to be aliased later.
  alias_store[#alias_store + 1] = t
  local alias = alias_store[i]
  alias[i] = expected
  alias[i + 1] = expected
  alias[1] = nil
  alias[2] = nil
  alias[3] = nil
  alias[4] = nil
  alias[5] = nil
  alias[6] = nil
  alias['1000'] = 1000
  result = t[8]
end

-- Checked for assertion guard, on the last iteration we get
-- the value on initializatoin.
test:ok(
  result == 'other',
  'TDUP load forwarding same type different values, aliased table'
)

os.exit(test:check() and 0 or 1)
