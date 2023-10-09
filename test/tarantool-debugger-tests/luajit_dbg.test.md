## smoke
### debug lj_cf_print
### lua
print(1)
### expected
lj-tv command intialized
lj-state command intialized
lj-arch command intialized
lj-gc command intialized
lj-str command intialized
lj-tab command intialized
lj-stack command intialized
LuaJIT debug extension is successfully loaded


## lj-arch
### debug lj_cf_print
lj-arch
### lua
print(1)
### matches
LJ_64: (True|False), LJ_GC64: (True|False), LJ_DUALNUM: (True|False)


## lj-state
### debug lj_cf_print
lj-state
### lua
print(1)
### matches
VM state: [A-Z]+
GC state: [A-Z]+
JIT state: [A-Z]+


## lj-gc
### debug lj_cf_print
lj-gc
### lua
print(1)
### matches
GC stats: [A-Z]+
\ttotal: \d+
\tthreshold: \d+
\tdebt: \d+
\testimate: \d+
\tstepmul: \d+
\tpause: \d+
\tsweepstr: \d+/\d+
\troot: \d+ objects
\tgray: \d+ objects
\tgrayagain: \d+ objects
\tweak: \d+ objects
\tmmudata: \d+ objects


## lj-stack
### debug lj_cf_print
lj-stack
### lua
print(1)
### matches
-+ Red zone:\s+\d+ slots -+
(0x[a-zA-Z0-9]+\s+\[(S|\s)(B|\s)(T|\s)(M|\s)\] VALUE: nil\n?)*
-+ Stack:\s+\d+ slots -+
(0x[A-Za-z0-9]+(:0x[A-Za-z0-9]+)?\s+\[(S|\s)(B|\s)(T|\s)(M|\s)\].*\n?)+


## lj-tv
### debug lj_cf_print
lj-tv L->base
lj-tv L->base + 1
lj-tv L->base + 2
lj-tv L->base + 3
lj-tv L->base + 4
lj-tv L->base + 5
lj-tv L->base + 6
lj-tv L->base + 7
lj-tv L->base + 8
lj-tv L->base + 9
lj-tv L->base + 10
lj-tv L->base + 11
### lua
local ffi = require('ffi')

print(
  nil,
  false,
  true,
  "hello",
  {1},
  1,
  1.1,
  coroutine.create(function() end),
  ffi.new('int*'),
  function() end,
  print,
  require
) 
### matches
nil
false
true
string \"hello\" @ 0x[a-zA-Z0-9]+
table @ 0x[a-zA-Z0-9]+ \(asize: \d+, hmask: 0x[a-zA-Z0-9]+\)
(number|integer) .*1.*
number 1.1\d+
thread @ 0x[a-zA-Z0-9]+
cdata @ 0x[a-zA-Z0-9]+
Lua function @ 0x[a-zA-Z0-9]+, [0-9]+ upvalues, .+:[0-9]+
fast function #[0-9]+
C function @ 0x[a-zA-Z0-9]+


## lj-str
### debug lj_cf_dofile
lj-str fname
### lua
pcall(dofile('name'))
### matches
String: .* \[\d+ bytes\] with hash 0x[a-zA-Z0-9]+


## lj-tab
### debug lj_cf_unpack
lj-tab t
### lua
unpack({1; a = 1})
### matches
Array part: 3 slots
0x[a-zA-Z0-9]+: \[0\]: nil
0x[a-zA-Z0-9]+: \[1\]: .+ 1
0x[a-zA-Z0-9]+: \[2\]: nil
Hash part: 2 nodes
0x[a-zA-Z0-9]+: { string "a" @ 0x[a-zA-Z0-9]+ } => { .+ 1 }; next = 0x0
0x[a-zA-Z0-9]+: { nil } => { nil }; next = 0x0
