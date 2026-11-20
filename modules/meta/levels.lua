-- Campaign: level number -> generator params on a sawtooth difficulty curve.
-- Every level is solvable without boosters (level_gen guarantee); peaks alternate with breathers.
-- Hand-made levels can override any number: put plain level data into HANDMADE[n].
local level_gen = require("modules.sim.level_gen")

local M = {}

M.HANDMADE = {}

-- 0..1 inside a 5-level tooth: 1, 2, 3 rise, 4 = peak, 5 = breather; the base rises every tooth
local TOOTH = { 0.15, 0.35, 0.6, 1.0, 0.05 }

function M.difficulty(n)
	local base = math.min(1, (n - 1) / 60)
	local t = TOOTH[(n - 1) % #TOOTH + 1]
	return math.min(1, base * 0.6 + t * 0.4), t
end

-- 7 long, so shapes don't line up with the 5-level difficulty tooth
local SHAPES = { "grid", "frames", "diagonal", "rings", "grid", "fan", "diagonal" }

function M.params(n)
	local d, tooth = M.difficulty(n)
	local p = {
		seed = 1000 + n * 7717,
		template = n <= 3 and "grid" or SHAPES[(n - 1) % #SHAPES + 1],
		count = math.floor(12 + d * 43),            -- 12..55 vehicles
		colors = math.floor(3 + d * 5),             -- 3..8
		window = (n <= 2) and 1 or ((d > 0.55) and 3 or 2),
		hidden = (n >= 10) and d * 0.3 or 0,
		garages = (n >= 15 and tooth >= 0.6) and 1 or 0,
	}
	if n == 1 then p.count = 6 end                 -- first tap in 3 seconds
	return p
end

function M.get(n)
	if M.HANDMADE[n] then return M.HANDMADE[n] end
	local level = level_gen.generate(M.params(n))
	level.number = n
	return level
end

return M
