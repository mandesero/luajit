local tap = require('tap')
local test = tap.test('lj-noticket-varg-usedef'):skipcond({
  ['Test requires JIT enabled'] = not jit.status(),
})

test:plan(1)

jit.opt.start('hotloop=1')

local counter = 0
local anchor

while counter < 3 do
  counter = counter + 1
  -- BC_VARG 4 1 0. `...` is nil (argument for the script).
  -- luacheck: ignore
  anchor = {{}}, ...
end

test:ok(type(anchor[1]) == 'table', 'BC_VARG reg_b > 0')

os.exit(test:check() and 0 or 1)
