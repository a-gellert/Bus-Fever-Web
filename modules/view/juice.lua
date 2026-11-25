-- Game feel helpers on go.animate: squash & stretch, lurch, shake, pop, flash, pulse, confetti.
local M = {}

-- One squash per boarded passenger (3D-safe uniform base scale)
function M.squash(id, base_scale)
	go.cancel_animations(id, "scale")
	go.set_scale(vmath.vector3(base_scale * 1.12, base_scale * 0.90, base_scale * 0.90), id)
	go.animate(id, "scale", go.PLAYBACK_ONCE_FORWARD, vmath.vector3(base_scale, base_scale, base_scale), go.EASING_OUTBACK, 0.12)
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
	go.cancel_animations(id, "scale")
	go.set_scale(base_scale * 0.6, id)
	go.animate(id, "scale", go.PLAYBACK_ONCE_FORWARD, vmath.vector3(base_scale, base_scale, base_scale), go.EASING_OUTBACK, 0.25)
end

-- White flash on a sprite, back to `tint`
function M.flash(sprite_url, tint)
	go.cancel_animations(sprite_url, "tint")
	go.set(sprite_url, "tint", vmath.vector4(1, 1, 1, 1))
	go.animate(sprite_url, "tint", go.PLAYBACK_ONCE_FORWARD, tint, go.EASING_OUTQUAD, 0.25)
end

-- Small camera kick (render script shakes the view and lets it settle)
function M.shake_screen(px)
	msg.post("@render:", "shake", { amount = px })
end

-- Endless gentle pulse (tutorial pointer, "+" bays)
function M.pulse(id, amount, period)
	go.cancel_animations(id, "scale")
	go.set_scale(1, id)
	go.animate(id, "scale", go.PLAYBACK_LOOP_PINGPONG, vmath.vector3(1 + amount, 1 + amount, 1), go.EASING_INOUTSINE, period or 0.6)
end

-- Burst of coloured sparks from (x, y); `make()` returns a fresh sprite game object
function M.confetti(x, y, n, size, colors, make, img)
	img = img or 16 -- source sprite size, px
	for i = 1, n do
		local id = make()
		local a = math.random() * math.pi * 2
		local d = size * (4 + math.random() * 8)
		go.set_position(vmath.vector3(x, y, 0.95), id)
		go.set(id, "euler.z", math.random() * 360)
		local spr = msg.url(nil, id, "sprite")
		go.set(spr, "tint", colors[(i - 1) % #colors + 1])
		local s = size / img * (0.6 + math.random() * 0.6)
		go.set(spr, "scale", vmath.vector3(s, s, 1))
		local t = 0.7 + math.random() * 0.5
		go.animate(id, "position", go.PLAYBACK_ONCE_FORWARD, vmath.vector3(x + math.cos(a) * d, y + math.sin(a) * d - size * 3, 0.95),
			go.EASING_OUTCUBIC, t)
		go.animate(id, "euler.z", go.PLAYBACK_ONCE_FORWARD, math.random() * 720 - 360, go.EASING_LINEAR, t)
		go.animate(spr, "tint.w", go.PLAYBACK_ONCE_FORWARD, 0, go.EASING_INQUAD, t, 0, function() go.delete(id) end)
	end
end

return M
