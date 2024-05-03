local ffi = require('ffi')

ffi.cdef[[
typedef struct {
    uint8_t a;
    uint8_t b;
} TestStruct;
]]

local obj = ffi.new("TestStruct")
obj = ffi.gc(obj, nil)
local intPtr = ffi.cast("uint8_t *", obj)
obj = nil
collectgarbage("collect")

-- after free
-- mem dump: ... RZ RZ RZ RZ RZ ... \\ RZ - redzone
--                        ^
--                        |
--                       ptr

-- error
local p = intPtr[0]
