-- Portal SDK wrapper (Poki now; Famobi/Playgama later behind the same functions).
-- No-op outside the portal: rewarded calls succeed, breaks complete at once.
local config = require("modules.config")

local M = {}

local playing = false
local ad_active = false
local last_break = -math.huge
local on_pause, on_resume -- hooks for audio/sim pause, set by the game

local function sdk() return rawget(_G, "poki_sdk") end

function M.now() return (socket and socket.gettime) and socket.gettime() or os.time() end

function M.set_hooks(pause, resume) on_pause, on_resume = pause, resume end

function M.is_ad_active() return ad_active end

-- Call on the first player input of a level and after every ad
function M.gameplay_start()
	if playing or ad_active then return end
	playing = true
	local s = sdk()
	if s then s.gameplay_start() end
end

function M.gameplay_stop()
	if not playing then return end
	playing = false
	local s = sdk()
	if s then s.gameplay_stop() end
end

function M.measure(category, what, action)
	local s = sdk()
	if s and s.measure then pcall(s.measure, category, what or "", action or "") end
end

local function begin_ad()
	M.gameplay_stop()
	ad_active = true
	if on_pause then on_pause() end
end

local function end_ad()
	ad_active = false
	if on_resume then on_resume() end
end

-- Natural break between levels: only from INTERSTITIAL_FROM_LEVEL and not more often than MIN_GAP
function M.level_break(level, done)
	local s = sdk()
	local now = M.now()
	if ad_active or not s or level < config.INTERSTITIAL_FROM_LEVEL or now - last_break < config.INTERSTITIAL_MIN_GAP then
		done()
		return
	end
	last_break = now
	begin_ad()
	local finished = false
	s.commercial_break(function(_, status)
		if status ~= s.COMMERCIAL_BREAK_START and not finished then
			finished = true
			end_ad()
			done()
		end
	end)
end

-- Rewarded: "+" bays, booster refills, rescue on Out of Spots. done(success)
function M.rewarded(done, size)
	local s = sdk()
	if not s then
		done(true)
		return
	end
	if ad_active then return done(false) end
	last_break = M.now() -- a rewarded video also counts as the break: no interstitial right after it
	begin_ad()
	local finished = false
	s.rewarded_break(size or "small", function(_, status)
		if status ~= s.REWARDED_BREAK_START and not finished then
			finished = true
			end_ad()
			done(status == s.REWARDED_BREAK_SUCCESS)
		end
	end)
end

return M
