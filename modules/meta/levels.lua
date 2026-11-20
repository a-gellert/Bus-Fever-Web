-- Campaign: level number -> generator params on a sawtooth difficulty curve.
-- Every level is solvable without boosters (level_gen guarantee); peaks alternate with breathers.
-- Tune with tests/test_difficulty.lua (casual-player fail rates), not by feel alone.
-- Hand-made levels can override any number: put plain level data into HANDMADE[n].
local config = require("modules.config")
local level_gen = require("modules.sim.level_gen")

local M = {}

M.HANDMADE = {}

-- 0..1 inside a 5-level tooth: 3 rising, 4 = peak, 5 = breather
local TOOTH = { 0.2, 0.4, 0.6, 1.0, 0.0 }

-- Gentle first levels (window 1 = no colour mixing in the queue for 1..3)
local INTRO = {
	{ count = 7, colors = 3 },
	{ count = 9, colors = 3 },
	{ count = 12, colors = 3 },
	{ count = 15, colors = 4 },
}

-- 7 long, so shapes don't line up with the 5-level tooth
local SHAPES = { "grid", "frames", "diagonal", "rings", "grid", "fan", "diagonal" }

local MAX_COUNT = 34 -- what the 13x17 lot really holds with breathing room

-- returns d (0..1 overall), t (position in the tooth), peak (bool)
function M.difficulty(n)
	local base = math.min(1, (n - 1) / 80)
	local t = TOOTH[(n - 1) % #TOOTH + 1]
	-- the tooth dominates: a breather late in the game is still a breather
	return math.min(1, base * 0.45 + t * 0.55), t, t >= 1
end

function M.unlocked_vip(n) return n >= config.BOOSTERS.vip.unlock_level end

function M.params(n)
	local d, t, peak = M.difficulty(n)
	local wide = peak and n >= 30 -- 3 vehicles mixed in the queue: only late peaks, with a 5th bay
	local p = {
		seed = 1000 + n * 7717,
		template = n <= 3 and "grid" or SHAPES[(n - 1) % #SHAPES + 1],
		count = math.min(MAX_COUNT, math.floor(14 + d * 22)),
		colors = math.min(7, math.floor(3 + d * 4.5)),
		window = wide and 3 or 2,
		hidden = (n >= 10) and d * 0.2 or 0,
		garages = (n >= 15 and t >= 0.6) and 1 or 0,
		bays = {
			open = config.BAYS_OPEN + (wide and 1 or 0),
			locked = config.BAYS_LOCKED,
			vip = M.unlocked_vip(n),
		},
	}
	if wide then p.colors = math.max(p.colors, 5) end
	local intro = INTRO[n]
	if intro then
		p.count, p.colors = intro.count, intro.colors
		p.window = n <= 3 and 1 or 2
		p.hidden = 0
	end
	return p
end

function M.get(n)
	if M.HANDMADE[n] then return M.HANDMADE[n] end
	local level = level_gen.generate(M.params(n))
	level.number = n
	return level
end

return M
