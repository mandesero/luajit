#! /usr/bin/lua
--
-- lua-Harness : <https://fperrad.frama.io/lua-Harness/>
--
-- Copyright (C) 2009-2018, Perrad Francois
--
-- This code is licensed under the terms of the MIT/X11 license,
-- like Lua itself.
--

--[[

=head1 Lua nil & coercion

=head2 Synopsis

    % prove 103-nil.t

=head2 Description

=cut

--]]

require'tap'
local has_op53 = _VERSION >= 'Lua 5.3'

plan'no_plan'

error_like(function () return -nil end,
           "^[^:]+:%d+: attempt to perform arithmetic on a nil value",
           "-nil")

error_like(function () return #nil end,
           "^[^:]+:%d+: attempt to get length of a nil value",
           "#nil")

is(not nil, true, "not nil")

error_like(function () return nil + 10 end,
           "^[^:]+:%d+: attempt to perform arithmetic on a nil value",
           "nil + 10")

error_like(function () return nil - 2 end,
           "^[^:]+:%d+: attempt to perform arithmetic on a nil value",
           "nil - 2")

error_like(function () return nil * 3.14 end,
           "^[^:]+:%d+: attempt to perform arithmetic on a nil value",
           "nil * 3.14")

error_like(function () return nil / -7 end,
           "^[^:]+:%d+: attempt to perform arithmetic on a nil value",
           "nil / -7")

error_like(function () return nil % 4 end,
           "^[^:]+:%d+: attempt to perform arithmetic on a nil value",
           "nil % 4")

error_like(function () return nil ^ 3 end,
           "^[^:]+:%d+: attempt to perform arithmetic on a nil value",
           "nil ^ 3")

error_like(function () return nil .. 'end' end,
           "^[^:]+:%d+: attempt to concatenate a nil value",
           "nil .. 'end'")

is(nil == nil, true, "nil == nil")

is(nil ~= nil, false, "nil ~= nil")

is(nil == 1, false, "nil == 1")

is(nil ~= 1, true, "nil ~= 1")

error_like(function () return nil < nil end,
           "^[^:]+:%d+: attempt to compare two nil values",
           "nil < nil")

error_like(function () return nil <= nil end,
           "^[^:]+:%d+: attempt to compare two nil values",
           "nil <= nil")

error_like(function () return nil > nil end,
           "^[^:]+:%d+: attempt to compare two nil values",
           "nil > nil")

error_like(function () return nil > nil end,
           "^[^:]+:%d+: attempt to compare two nil values",
           "nil >= nil")

error_like(function () return nil < 0 end,
           "^[^:]+:%d+: attempt to compare %w+ with %w+",
           "nil < 0")

error_like(function () return nil <= 0 end,
           "^[^:]+:%d+: attempt to compare %w+ with %w+",
           "nil <= 0")

error_like(function () return nil > 0 end,
           "^[^:]+:%d+: attempt to compare %w+ with %w+",
           "nil > 0")

error_like(function () return nil >= 0 end,
           "^[^:]+:%d+: attempt to compare %w+ with %w+",
           "nil >= 0")

error_like(function () local a = nil; local b = a[1]; end,
           "^[^:]+:%d+: attempt to index",
           "index")

error_like(function () local a = nil; a[1] = 1; end,
           "^[^:]+:%d+: attempt to index",
           "index")

if has_op53 then
    dofile'lexico53/nil.t'
end

done_testing()

-- Local Variables:
--   mode: lua
--   lua-indent-level: 4
--   fill-column: 100
-- End:
-- vim: ft=lua expandtab shiftwidth=4:
