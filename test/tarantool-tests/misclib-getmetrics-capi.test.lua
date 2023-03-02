local tap = require('tap')
local test = tap.test("clib-misc-getmetrics"):skipcond({
  ['Test requires JIT enabled'] = not jit.status(),
  ['Disabled on *BSD due to #4819'] = jit.os == 'BSD',
})

test:plan(11)

local path = arg[0]:gsub('%.test%.lua', '')
local suffix = package.cpath:match('?.(%a+);')
package.cpath = ('%s/?.%s;'):format(path, suffix)..package.cpath

local MAXNINS = require('utils').const.maxnins
local jit_opt_default = {
    3, -- level
    "hotloop=56",
    "hotexit=10",
    "minstitch=0",
}

local testgetmetrics = require("testgetmetrics")

test:ok(testgetmetrics.base())
test:ok(testgetmetrics.gc_allocated_freed())
test:ok(testgetmetrics.gc_steps())

test:ok(testgetmetrics.objcount(function(iterations)
    local ffi = require("ffi")

    jit.opt.start(0)

    local placeholder = {
        str = {},
        tab = {},
        udata = {},
        cdata = {},
    }

    -- Separate objects creations to separate jit traces.
    for _ = 1, iterations do
        table.insert(placeholder.str, tostring(_))
    end

    for _ = 1, iterations do
        table.insert(placeholder.tab, {_})
    end

    for _ = 1, iterations do
        table.insert(placeholder.udata, newproxy())
    end

    for _ = 1, iterations do
        -- Check counting of VLA/VLS/aligned cdata.
        table.insert(placeholder.cdata, ffi.new("char[?]", 4))
    end

    for _ = 1, iterations do
        -- Check counting of non-VLA/VLS/aligned cdata.
        table.insert(placeholder.cdata, ffi.new("uint64_t", _))
    end

    placeholder = nil -- luacheck: no unused
    -- Restore default jit settings.
    jit.opt.start(unpack(jit_opt_default))
end))

test:ok(testgetmetrics.objcount_cdata_decrement(function()
    -- gc_cdatanum decrement test.
    -- See https://github.com/tarantool/tarantool/issues/5820.
    local ffi = require("ffi")
    local function nop() end
    ffi.gc(ffi.cast("void *", 0), nop)
    -- Does not collect the cdata, but resurrects the object and
    -- removes LJ_GC_CDATA_FIN flag.
    collectgarbage()
    -- Collects the cdata.
    collectgarbage()
end))

-- Compiled loop with a direct exit to the interpreter.
test:ok(testgetmetrics.snap_restores(function()
    jit.opt.start(0, "hotloop=1")

    local sum = 0
    for i = 1, 20 do
        sum = sum + i
    end

    -- Restore default jit settings.
    jit.opt.start(unpack(jit_opt_default))

    -- A single snapshot restoration happened on loop finish.
    return 1
end))

-- Compiled loop with a side exit which does not get compiled.
test:ok(testgetmetrics.snap_restores(function()
    jit.opt.start(0, "hotloop=1", "hotexit=2", ("minstitch=%d"):format(MAXNINS))

    local function foo(i)
        -- math.fmod is not yet compiled!
        return i <= 5 and i or math.fmod(i, 11)
    end

    local sum = 0
    for i = 1, 10 do
        sum = sum + foo(i)
    end

    -- Restore default jit settings.
    jit.opt.start(unpack(jit_opt_default))

    -- Side exits from the root trace could not get compiled.
    return 5
end))

-- Compiled loop with a side exit which gets compiled.
test:ok(testgetmetrics.snap_restores(function()
    -- Optimization level is important here as `loop` optimization
    -- may unroll the loop body and insert +1 side exit.
    jit.opt.start(0, "hotloop=1", "hotexit=5")

    local function foo(i)
        return i <= 10 and i or tostring(i)
    end

    local sum = 0
    for i = 1, 20 do
        sum = sum + foo(i)
    end

    -- Restore default jit settings.
    jit.opt.start(unpack(jit_opt_default))

    -- 5 side exits to the interpreter before trace gets hot
    -- and compiled
    -- 1 side exit on loop end
    return 6
end))

-- Compiled scalar trace with a direct exit to the interpreter.
test:ok(testgetmetrics.snap_restores(function()
    -- For calls it will be 2 * hotloop (see lj_dispatch.{c,h}
    -- and hotcall@vm_*.dasc).
    jit.opt.start(3, "hotloop=2", "hotexit=3")

    local function foo(i)
        return i <= 15 and i or tostring(i)
    end

    foo(1)  -- interp only
    foo(2)  -- interp only
    foo(3)  -- interp only
    foo(4)  -- compile trace during this call
    foo(5)  -- follow the trace
    foo(6)  -- follow the trace
    foo(7)  -- follow the trace
    foo(8)  -- follow the trace
    foo(9)  -- follow the trace
    foo(10) -- follow the trace

    -- Simply 2 side exits from the trace:
    foo(20)
    foo(21)

    -- Restore default jit settings.
    jit.opt.start(unpack(jit_opt_default))

    return 2
end))

test:ok(testgetmetrics.strhash())

test:ok(testgetmetrics.tracenum_base(function()
    local sum = 0
    for i = 1, 200 do
        sum = sum + i
    end
    -- Compiled only 1 loop as new trace.
    return 1
end))
