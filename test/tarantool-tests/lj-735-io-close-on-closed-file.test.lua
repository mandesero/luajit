local tap = require('tap')

local test = tap.test('lj-735-io-close-on-closed-file')
test:plan(1)

local TEST_FILE = 'lj-735-io-close-on-closed-file.tmp'

-- Save the old stdout for the TAP output.
local oldstdout = io.output()
io.output(TEST_FILE)

local status, err = io.close()
assert(status, err)

status = pcall(io.close)

io.output(oldstdout)

test:ok(not status, 'close already closed file')

assert(os.remove(TEST_FILE))

os.exit(test:check() and 0 or 1)
