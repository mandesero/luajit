local tap = require('tap')
local test = tap.test('lj-549-bytecode-loader')
local ffi = require('ffi')
local exec = require('utils').exec
local tools = require('utils').tools

test:plan(1)

-- Test creates a shared library with LuaJIT bytecode,
-- loads shared library as a Lua module and checks,
-- that no crashes eliminated.
--
-- $ make HOST_CC='gcc -m32' TARGET_CFLAGS='-m32' \
--                           TARGET_LDFLAGS='-m32' \
--                           TARGET_SHLDFLAGS='-m32' \
--                           -f Makefile.original
-- $ echo 'print("test")' > a.lua
-- $ LUA_PATH="src/?.lua;;" luajit -b a.lua a.c
-- $ gcc -m32 -fPIC -shared a.c -o a.so
-- $ luajit -e "require('a')"
-- Program received signal SIGBUS, Bus error

-- Create a C file with LuaJIT bytecode.
-- We cannot use utils.makecmd, because command-line generated
-- by `makecmd` contains `-e` that is incompatible with option
-- `-b`.
local function create_c_file(pathlua, pathc)
  local lua_path = os.getenv('LUA_PATH')
  local lua_bin = exec.luacmd(arg):match('%S+')
  local cmd_fmt = 'LUA_PATH="%s" %s -b %s %s'
  local cmd = (cmd_fmt):format(lua_path, lua_bin, pathlua, pathc)
  local ret = os.execute(cmd)
  assert(ret == 0, 'create a C file with bytecode')
end

local stdout_msg = 'Lango team'
local lua_code = ('print(%q)'):format(stdout_msg)
local fpath = os.tmpname()
local path_lua = ('%s.lua'):format(fpath)
local path_c = ('%s.c'):format(fpath)
local ext = (jit.os == 'OSX' and 'dylib' or 'so')
local path_shared = ('%s.%s'):format(fpath, ext)

-- Create a file with a minimal Lua code.
local fh = assert(io.open(path_lua, 'w'))
fh:write(lua_code)
fh:close()

local module_name = assert(tools.basename(fpath))

create_c_file(path_lua, path_c)
assert(tools.file_exists(path_c))

-- Compile C source code with LuaJIT bytecode to a shared library.
-- `-m64` is not available on ARM64, see
-- "3.18.1 AArch64 Options in the manual",
-- https://gcc.gnu.org/onlinedocs/gcc/AArch64-Options.html.
local cflags_64 = jit.arch == 'arm64' and '-march=armv8-a' or '-m64'
local cflags = ffi.abi('32bit') and '-m32' or cflags_64
local cc_cmd = ('cc %s -fPIC -shared %s -o %s'):format(cflags, path_c, path_shared)
local rc = os.execute(cc_cmd)
assert(rc == 0)
assert(tools.file_exists(path_shared))

-- Load shared library as a Lua module.
local lua_cpath = ('"%s/?.%s;"'):format(tools.basedir(fpath), ext)
assert(tools.file_exists(path_shared))
local cmd = exec.makecmd(arg, {
  script = ('-e "require([[%s]])"'):format(module_name),
  env = {
    LUA_CPATH = lua_cpath,
    -- It is required to cleanup LUA_PATH, otherwise
    -- LuaJIT loads Lua module, see
    -- tarantool-tests/utils/init.lua.
    LUA_PATH = '',
  },
})
local res = cmd()
test:ok(res == stdout_msg, 'bytecode loader works')

os.remove(path_lua)
os.remove(path_c)
os.remove(path_shared)

test:done(true)
