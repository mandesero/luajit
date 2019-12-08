local tap = require('tap')

-- Test to check that we avoid parsing of too long separator
-- for long strings.
-- See also the discussion in the
-- https://github.com/LuaJIT/LuaJIT/issues/812.

local test = tap.test('lj-812-too-long-string-separator'):skipcond({
  ['Test requires GC64 mode enabled'] = not require('ffi').abi('gc64'),
})
test:plan(2)

-- We can't check the string overflow itself without a really
-- large file, because the ERR_MEM error will be raised, due to
-- the string buffer reallocations during parsing.
-- Keep such huge file in the repo is pointless, so just check
-- that we don't parse long string after some separator length.
-- Be aware that this limit is different for Lua 5.1.

-- Use the hardcoded limit. The same as in the <src/lj_lex.c>.
local separator = string.rep('=', 0x20000000 + 1)
local test_str = ('return [%s[]%s]'):format(separator, separator)

local f, err = loadstring(test_str, 'empty_str_f')
test:ok(not f, 'correct status when parsing string with too long separator')

-- Check error message.
test:ok(tostring(err):match('invalid long string delimiter'),
        'correct error when parsing string with too long separator')

test:done(true)
