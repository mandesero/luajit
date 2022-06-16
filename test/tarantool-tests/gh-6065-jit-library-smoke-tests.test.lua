local tap = require('tap')

local test = tap.test('gh-6065-jit-library-smoke-tests')
test:plan(1)

-- Just check whether LuaJIT is built with JIT support. Otherwise,
-- <jit.on> raises an error that is handled via <pcall> and passed
-- as a second argument to the assertion.
test:ok(pcall(jit.on))

os.exit(test:check() and 0 or 1)
