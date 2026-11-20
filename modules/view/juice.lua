-- Game feel helpers on go.animate: squash & stretch, bumper shake, pop.
local M = {}

-- One squash per boarded passenger; `url` is a sprite (its scale is the base size)
function M.squash(id, base_scale)
	go.cancel_animations(id, "scale")
	go.set_scale(vmath.vector3(base_scale * 1.08, base_scale * 0.9, 1), id)
	go.animate(id, "scale", go.PLAYBACK_ONCE_FORWARD, vmath.vector3(base_scale, base_scale, 1), go.EASING_OUTBACK, 0.12)
end

-- Blocked bus: lurch `dist` px along (dx, dy) and spring back
function M.lurch(id, dx, dy, dist)
	local p = go.get_position(id)
	go.cancel_animations(id, "position")
	go.animate(id, "position", go.PLAYBACK_ONCE_PINGPONG, p + vmath.vector3(dx * dist, dy * dist, 0), go.EASING_OUTQUAD, 0.16,
		0, function() go.set_position(p, id) end)
end

function M.shake(id, amount)
	local p = go.get_position(id)
	go.cancel_animations(id, "position.x")
	go.animate(id, "position.x", go.PLAYBACK_ONCE_PINGPONG, p.x + amount, go.EASING_INOUTSINE, 0.06, 0,
		function() go.set_position(p, id) end)
end

function M.pop(id, base_scale)
	go.set_scale(base_scale * 0.6, id)
	go.animate(id, "scale", go.PLAYBACK_ONCE_FORWARD, vmath.vector3(base_scale, base_scale, 1), go.EASING_OUTBACK, 0.25)
end

return M
