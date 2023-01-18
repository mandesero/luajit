-- Sysprof is implemented for x86 and x64 architectures only.
local utils = require("utils")
local ffi = require("ffi")
-- luacheck: globals is_excluded
utils.skipcond(
  jit.arch ~= "x86" and jit.arch ~= "x64" or jit.os ~= "Linux"
    or ffi.abi("gc64") or utils.is_excluded(arg),
  jit.arch.." architecture or "..jit.os..
  " OS is NIY for sysprof, or the test suite was excluded"
)

local testsysprof = require("testsysprof")

local tap = require("tap")
local jit = require('jit')

jit.off()

local test = tap.test("clib-misc-sysprof")
test:plan(4)

test:ok(testsysprof.base())
test:ok(testsysprof.validation())

local function lua_payload(n)
  if n <= 1 then
    return n
  end
  return lua_payload(n - 1) + lua_payload(n - 2)
end

local function payload()
  local n_iterations = 500000

  local co = coroutine.create(function ()
    for i = 1, n_iterations do
      if i % 2 == 0 then
        testsysprof.c_payload(10)
      else
        lua_payload(10)
      end
      coroutine.yield()
    end
  end)

  for _ = 1, n_iterations do
    coroutine.resume(co)
  end
end

test:ok(testsysprof.profile_func(payload))

jit.on()
jit.flush()

test:ok(testsysprof.profile_func(payload))
os.exit(test:check() and 0 or 1)
