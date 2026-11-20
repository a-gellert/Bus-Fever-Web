-- Minimal assertions for tests/run via tools/run_tests.js
local T = {}

function T.eq(a, b, msg)
	if a ~= b then error((msg or "eq") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

function T.ok(v, msg)
	if not v then error(msg or "expected true", 2) end
end

return T
