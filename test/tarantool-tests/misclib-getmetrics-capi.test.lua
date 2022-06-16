-- Disabled on *BSD due to #4819.
require('utils').skipcond(jit.os == 'BSD', 'Disabled due to #4819')

local path = arg[0]:gsub('%.test%.lua', '')
local suffix = package.cpath:match('?.(%a+);')
package.cpath = ('%s/?.%s;'):format(path, suffix)..package.cpath

local jit_opt_default = {
    3, -- level
    "hotloop=56",
    "hotexit=10",
    "minstitch=0",
}

local tap = require('tap')

local test = tap.test("clib-misc-getmetrics")
test:plan(10)

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
    for i = 1, iterations do
        table.insert(placeholder.str, tostring(i))
    end

    for i = 1, iterations do
        table.insert(placeholder.tab, {i})
    end

    for i = 1, iterations do
        table.insert(placeholder.udata, newproxy())
    end

    for i = 1, iterations do
        -- Check counting of VLA/VLS/aligned cdata.
        table.insert(placeholder.cdata, ffi.new("char[?]", 4))
    end

    for i = 1, iterations do
        -- Check counting of non-VLA/VLS/aligned cdata.
        table.insert(placeholder.cdata, ffi.new("uint64_t", i))
    end

    placeholder = nil
    -- Restore default jit settings.
    jit.opt.start(unpack(jit_opt_default))
end))

-- Compiled loop with a direct exit to the interpreter.
test:ok(testgetmetrics.snap_restores(function()
    jit.opt.start(0, "hotloop=1")

    local old_metrics = misc.getmetrics()

    local sum = 0
    for i = 1, 20 do
        sum = sum + i
    end

    local new_metrics = misc.getmetrics()

    -- Restore default jit settings.
    jit.opt.start(unpack(jit_opt_default))

    -- A single snapshot restoration happened on loop finish.
    return 1
end))

-- Compiled loop with a side exit which does not get compiled.
test:ok(testgetmetrics.snap_restores(function()
    jit.opt.start(0, "hotloop=1", "hotexit=2", "minstitch=15")

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
