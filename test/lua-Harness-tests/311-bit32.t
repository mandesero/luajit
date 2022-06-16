#! /usr/bin/lua
--
-- lua-Harness : <https://fperrad.frama.io/lua-Harness/>
--
-- Copyright (C) 2010-2018, Perrad Francois
--
-- This code is licensed under the terms of the MIT/X11 license,
-- like Lua itself.
--

--[[

=head1 Lua Bitwise Library

=head2 Synopsis

    % prove 311-bit32.t

=head2 Description

Tests Lua Bitwise Library

This library was introduced in Lua 5.2 and deprecated in Lua 5.3.

See section "Bitwise Operations" in "Reference Manual"
L<https://www.lua.org/manual/5.2/manual.html#6.7>

=cut

--]]

require 'tap'
local profile = require'profile'
local has_bit32 = _VERSION == 'Lua 5.2' or profile.compat52 or profile.has_bit32

if not bit32 then
    plan(1)
    nok(has_bit32, "no has_bit32")
    os.exit(0)
end

plan(20)

do -- arshift
    is(bit32.arshift(0x06, 1), 0x03, "function arshift")
    is(bit32.arshift(-3, 1), bit32.arshift(-6, 2), "function arshift")
end

do -- band
    is(bit32.band(0x01, 0x03, 0x07), 0x01, "function band")
end

do -- bnot
    if string.pack and #string.pack('n', 0) == 4 then
        is(bit32.bnot(0x03), (-1 - 0x03), "function bnot")
    else
        is(bit32.bnot(0x03), (-1 - 0x03) % 2^32, "function bnot")
    end
end

do -- bor
    is(bit32.bor(0x01, 0x03, 0x07), 0x07, "function bor")
end

do -- btest
    is(bit32.btest(0x01), true, "function btest")
    is(bit32.btest(0x00), false, "function btest")
end

do -- bxor
    is(bit32.bxor(0x01, 0x03, 0x07), 0x05, "function bxor")
end

do -- extract
    is(bit32.extract(0xFFFF, 3, 3), 0x07, "function extract")

    error_like(function () bit32.extract(0xFFFF, 99) end,
               "^[^:]+:%d+: trying to access non%-existent bits",
               "function extract (non-existent bits)")

    error_like(function () bit32.extract(0xFFFF, -3) end,
               "^[^:]+:%d+: bad argument #2 to 'extract' %(field cannot be negative%)",
               "function extract (negatif field)")

    error_like(function () bit32.extract(0xFFFF, 3, -3) end,
               "^[^:]+:%d+: bad argument #3 to 'extract' %(width must be positive%)",
               "function extract (negative width)")
end

do -- replace
    is(bit32.replace(0x0000, 0xFFFF, 3, 3), 0x38, "function replace")

    error_like(function () bit32.replace(0x0000, 0xFFFF, 99) end,
               "^[^:]+:%d+: trying to access non%-existent bits",
               "function replace (non-existent bits)")

    error_like(function () bit32.replace(0x0000, 0xFFFF, -3) end,
               "^[^:]+:%d+: bad argument #3 to 'replace' %(field cannot be negative%)",
               "function replace (negatif field)")

    error_like(function () bit32.replace(0x0000, 0xFFFF, 3, -3) end,
               "^[^:]+:%d+: bad argument #4 to 'replace' %(width must be positive%)",
               "function replace (negative width)")
end

do -- lrotate
    is(bit32.lrotate(0x03, 2), 0x0C, "function lrotate")
end

do -- lshift
    is(bit32.lshift(0x03, 2), 0x0C, "function lshift")
end

do -- rrotate
    is(bit32.rrotate(0x06, 1), 0x03, "function rrotate")
end

do -- rshift
    is(bit32.rshift(0x06, 1), 0x03, "function rshift")
end

-- Local Variables:
--   mode: lua
--   lua-indent-level: 4
--   fill-column: 100
-- End:
-- vim: ft=lua expandtab shiftwidth=4:
