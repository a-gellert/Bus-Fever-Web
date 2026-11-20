-- Sound by name. Sound components live on /audio (main.collection).
-- Only names listed in SOUNDS are played, so code can call sounds before the assets exist.
-- Two independent mutes: the player's choice (header button, saved) and ads (Poki: silence during ads).
local M = {}

-- add a name here when its sound component is added to /audio
M.SOUNDS = { board = true, deny = true, depart = true, go = true, honk = true, stuck = true, tap = true, unlock = true, vip = true, win = true, }

local user_muted, ad_muted = false, false

function M.set_muted(v) ad_muted = v end          -- ads
function M.set_user_muted(v) user_muted = v end   -- player
function M.is_user_muted() return user_muted end

-- board sounds rise in pitch along a streak (speed 1 .. 2)
function M.play(name, speed, gain)
	if user_muted or ad_muted or not M.SOUNDS[name] then return end
	sound.play("/audio#" .. name, { speed = speed or 1, gain = gain or 1 })
end

return M
