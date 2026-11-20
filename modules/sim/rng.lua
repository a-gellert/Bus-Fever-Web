-- Deterministic seeded RNG (Park–Miller). Same seed -> same level on LuaJIT (Defold) and in tests.
-- math.random is not used in the sim: its sequence differs between Lua builds.
local M = {}
M.__index = M

local MOD = 2147483647

function M.new(seed)
	local s = math.floor(math.abs(seed or 1)) % MOD
	if s == 0 then s = 1 end
	return setmetatable({ s = s }, M)
end

-- float in [0, 1)
function M:float()
	self.s = (self.s * 16807) % MOD
	return (self.s - 1) / (MOD - 1)
end

-- integer in [a, b]
function M:int(a, b)
	return a + math.floor(self:float() * (b - a + 1))
end

function M:pick(list)
	return list[self:int(1, #list)]
end

function M:shuffle(list)
	for i = #list, 2, -1 do
		local j = self:int(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

return M
