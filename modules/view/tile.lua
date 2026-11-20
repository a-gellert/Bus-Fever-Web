-- Tile helper: one object type for backgrounds, bays, buttons, icons, popups and text.
--   panel (anim nil/"round"): /level#panel_factory, 9-slice sprite sized in pixels, crisp corners
--   image (any other anim):   /level#tile_factory, sprite scaled from its atlas size
-- Both prefabs carry a label "label". A tile set without w/h is text only (sprite hidden).
local M = {}

local PANEL_FACTORY = "/level#panel_factory"
local TILE_FACTORY = "/level#tile_factory"
local FONT_PX = 40     -- assets/fonts/main.font size
M.MIN_TEXT = 12        -- px, readable on a 360-wide phone

local SIZES = { slot = { 32, 96 }, garage = 64, backdrop = { 4, 256 }, ring = 64, hand = 64, spark = 16,
	icon_vip = 64, icon_arrange = 64, icon_jumble = 64, icon_restart = 64, icon_lock = 64, icon_ad = 64, disc = 64,
	icon_sound = 64, icon_mute = 64, star = 64, stop = { 48, 64 }, bar = { 64, 16 } }

local function img_size(anim)
	local s = SIZES[anim] or 64
	if type(s) == "table" then return s[1], s[2] end
	return s, s
end

function M.new(z, anim)
	local panel = anim == nil or anim == "round"
	local id = factory.create(panel and PANEL_FACTORY or TILE_FACTORY, vmath.vector3(0, 0, z or 0))
	local t = { id = id, sprite = msg.url(nil, id, "sprite"), label = msg.url(nil, id, "label"),
		anim = panel and "round" or "round", panel = panel, visible = true }
	if anim and not panel then M.anim(t, anim) end
	return t
end

function M.anim(t, anim)
	if t.anim ~= anim and not t.panel then
		sprite.play_flipbook(t.sprite, anim)
		t.anim = anim
	end
end

local function size(t, w, h)
	if not w then
		go.set(t.sprite, t.panel and "size" or "scale", vmath.vector3(0, 0, 0))
	elseif t.panel then
		-- 9-slice corners are 16 px: keep at least that much so small badges stay round
		go.set(t.sprite, "size", vmath.vector3(math.max(w, 2), math.max(h, 2), 0))
	else
		local iw, ih = img_size(t.anim)
		go.set(t.sprite, "scale", vmath.vector3(w / iw, h / ih, 1))
	end
end

-- o = {x, y, w, h, tint, text, text_px, text_color, rot (deg), anim, z}
function M.set(t, o)
	if o.anim then M.anim(t, o.anim) end
	local p = go.get_position(t.id)
	go.set_position(vmath.vector3(o.x, o.y, o.z or p.z), t.id)
	size(t, o.w, o.h)
	if o.tint then go.set(t.sprite, "tint", o.tint) end
	go.set(t.id, "euler.z", o.rot or 0)
	M.text(t, o.text or "", o.text_px or (o.h and o.h * 0.42) or 24, o.text_color)
end

function M.text(t, text, px, color)
	go.set(t.label, "text", text)
	local s = math.max(px, M.MIN_TEXT) / FONT_PX
	go.set(t.label, "scale", vmath.vector3(s, s, 1))
	if color then go.set(t.label, "color", color) end
end

function M.show(t, visible)
	if t.visible == visible then return end
	t.visible = visible
	msg.post(t.sprite, visible and "enable" or "disable")
	msg.post(t.label, visible and "enable" or "disable")
end

-- Safe to call twice (timers and replacements may both try)
function M.delete(t)
	if t and t.id then
		local id = t.id
		t.id = nil
		if go.exists(id) then go.delete(id) end
	end
end

return M
