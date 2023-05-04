local tap = require('tap')

local test = tap.test('lj-noticket-tdup-tnew-load-fwd'):skipcond({
  ['Test requires JIT enabled'] = not jit.status(),
})
-- TODO: test with exits too.
test:plan(2)

-- TNEW.
local r
local stored_tab = {1}
local slot = {}
local key = 1

jit.opt.start('hotloop=1')
for _ = 1, 5 do
  local t = slot
  r = t[key]
  slot = _ % 2 ~= 0 and stored_tab or {}
end
test:is(r, nil, 'TNEW load forwarding successful')

-- TDUP.
for _ = 1, 5 do
  local t = slot
  r = t[1]
  slot = _ % 2 ~= 0 and stored_tab or {true}
end
test:is(r, true, 'TDUP load forwarding was successful')

os.exit(test:check() and 0 or 1)
