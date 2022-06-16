local tap = require('tap')

local test = tap.test("lj-505-fold-icorrect-behavior")
test:plan(1)

-- Test file to demonstrate Lua fold machinery icorrect behavior, details:
--     https://github.com/LuaJIT/LuaJIT/issues/505

jit.opt.start("hotloop=1")
for _ = 1, 20 do
    local value = "abc"
    local pos_c = string.find(value, "c", 1, true)
    local value2 = string.sub(value, 1, pos_c - 1)
    local pos_b = string.find(value2, "b", 2, true)
    assert(pos_b == 2, "FAIL: position of 'b' is " .. pos_b)
end
test:ok(true, "string.find offset aritmetics wasn't broken while recording")

os.exit(test:check() and 0 or 1)
