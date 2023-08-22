local tap = require('tap')
local test = tap.test('lj-1051-snap-unsink-irfl-nomm'):skipcond({
  ['Test requires JIT enabled'] = not jit.status(),
})

test:plan(2)

jit.opt.start('hotloop=1')

local counter = 0
local slot = 'slot'
while true do
  counter = counter + 1
  -- Sinking table. `slot` isn't a constant at the moment of the
  -- recording, os `FREF` and `FSTORE` will be emitted.
  -- After re-emitting variant part of the loop NEWREF will
  -- contain constant key (see below).
  slot = {[slot] = 'foo'}
  -- Emit exit here, to be sure that the table will be restored
  -- from the snapshot.
  if counter > 2 then break end
  -- Need a constant reference for NEWREF. Just set old value.
  slot = 'slot'
end

test:is(slot.slot, 'foo', 'correct stored value')
test:ok(not debug.getmetatable(slot), 'foo', 'no metatable detected')

test:done(true)
