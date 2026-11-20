-- Sound by name. Sound components live on /audio (main.collection).
-- Only names listed in SOUNDS are played, so code can call sounds before the assets exist.
local M = {}

-- add a name here when its sound component is added to /audio
M.SOUNDS = {}  -- e.g. honk = true, board = true, depart = true, win = true

local muted = false

function M.set_muted(v) muted = v end

-- board sounds rise in pitch along a streak (speed 1 .. 2)
function M.play(name, speed)
	if muted or not M.SOUNDS[name] then return end
	sound.play("/audio#" .. name, { speed = speed or 1 })
end

return M
