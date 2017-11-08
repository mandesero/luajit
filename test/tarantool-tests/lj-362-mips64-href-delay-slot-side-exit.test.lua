local tap = require('tap')
-- Test file to demonstrate the incorrect JIT behaviour for HREF
-- IR compilation on mips64.
-- See also https://github.com/LuaJIT/LuaJIT/pull/362.
local test = tap.test('lj-362-mips64-href-delay-slot-side-exit'):skipcond({
  ['Test requires JIT enabled'] = not jit.status(),
})

test:plan(1)

-- To reproduce the issue we need to compile a trace with
-- `IR_HREF`, with a lookup of constant hash key GC value. To
-- prevent an `IR_HREFK` to be emitted instead, we need a table
-- with a huge hash part. Delta of address between the start of
-- the hash part of the table and the current node to lookup must
-- be more than `(1024 * 64 - 1) * sizeof(Node)`.
-- See <src/lj_record.c>, for details.
-- XXX: This constant is well suited to prevent test to be flaky,
-- because the aforementioned delta is always large enough.
-- Also, this constant avoids table rehashing, when inserting new
-- keys.
local N_HASH_FIELDS = 2 ^ 16 + 2 ^ 15

-- XXX: don't set `hotexit` to prevent compilation of trace after
-- exiting the main test cycle.
jit.opt.start('hotloop=1')

-- Don't use `table.new()`, here by intence -- this leads to the
-- allocation failure for the mcode memory, so traces are not
-- compiled.
local filled_tab = {}
-- Filling-up the table with GC values to minimize the amount of
-- hash collisions and increase delta between the start of the
-- hash part of the table and currently stored node.
for _ = 1, N_HASH_FIELDS do
  filled_tab[1LL] = 1
end

-- luacheck: no unused
local tab_value_a
local tab_value_b
local tab_value_c
local tab_value_d
local tab_value_e
local tab_value_f
local tab_value_g
local tab_value_h
local tab_value_i

-- The function for this trace has a bunch of the following IRs:
--    p64 HREF   0001  "a"            ; or other keys
-- >  p64 EQ     0002  [0x4002d0c528] ; nilnode
-- Sometimes, when we need to rematerialize a constant during
-- evicting of the register. So, the instruction related to
-- constant rematerialization is placed in the delay branch slot,
-- which suppose to contain the loads of trace exit number to the
-- `$ra` register. This leading to the assertion failure during
-- trace exit in `lj_trace_exit()`, since a trace number is
-- incorrect. The amount of the side exit to check is empirical
-- (even a little bit more, than necessary just in case).
local function href_const(tab)
  tab_value_a = tab.a
  tab_value_b = tab.b
  tab_value_c = tab.c
  tab_value_d = tab.d
  tab_value_e = tab.e
  tab_value_f = tab.f
  tab_value_g = tab.g
  tab_value_h = tab.h
  tab_value_i = tab.i
end

-- Compile main trace first.
href_const(filled_tab)
href_const(filled_tab)

-- Now brute-force side exits to check that they are compiled
-- correct. Take side exits in the reverse order to take a new
-- side exit each time.
filled_tab.i = 'i'
href_const(filled_tab)
filled_tab.h = 'h'
href_const(filled_tab)
filled_tab.g = 'g'
href_const(filled_tab)
filled_tab.f = 'f'
href_const(filled_tab)
filled_tab.e = 'e'
href_const(filled_tab)
filled_tab.d = 'd'
href_const(filled_tab)
filled_tab.c = 'c'
href_const(filled_tab)
filled_tab.b = 'b'
href_const(filled_tab)
filled_tab.a = 'a'
href_const(filled_tab)

test:ok(true, 'no assertion failures during trace exits')

test:done(true)
