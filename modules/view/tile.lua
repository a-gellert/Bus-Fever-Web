-- Tile helper: supports three render layers:
--   "ground" (default): /level#panel_factory & #tile_factory (flat on z=0 ground plane)
--   "overlay":          /level#overlay_panel_factory & #overlay_tile_factory (above 3D models in 3D space)
--   "hud":              /level#hud_panel_factory & #hud_tile_factory (2D orthographic screen HUD)
local M = {}

local FACTORIES = {
	bg      = { panel = "/level#bg_panel_factory",      tile = "/level#bg_tile_factory" },
	mid     = { panel = "/level#mid_panel_factory",     tile = "/level#mid_tile_factory" },
	ground  = { panel = "/level#panel_factory",         tile = "/level#tile_factory" },
	overlay = { panel = "/level#overlay_panel_factory", tile = "/level#overlay_tile_factory" },
	hud     = { panel = "/level#hud_panel_factory",     tile = "/level#hud_tile_factory" },
}
local FONT_PX = 40
M.MIN_TEXT = 12

local PANELS = {
	round = true, ui_card = true, ui_card_off = true, ui_pill = true,
	ui_modal = true, ui_modal_head = true, ui_btn_green = true,
	ui_btn_grey = true, ui_btn_gold = true,
}

local SIZES = {
	slot = { 32, 96 }, slot_vip = { 32, 96 }, slot_locked = { 32, 96 },
	garage = 64, backdrop = { 4, 256 }, ring = 64, hand = 64, spark = 16,
	icon_vip = 128, icon_arrange = 128, icon_jumble = 128,
	icon_restart = 64, icon_lock = 64, icon_ad = 64, disc = 64, ui_badge = 64,
	icon_sound = 64, icon_mute = 64, star = 96, stop = { 96, 128 },
	bar = { 64, 16 }, ui_bar = { 64, 16 }, barrier = 64, coin = 96, belt = { 64, 32 },
	bus_s = { 64, 36 }, bus_m = { 96, 36 }, bus_l = { 128, 36 },
	bus_xl = { 192, 36 }, bus_limo = { 160, 36 },
}

local function img_size(anim)
	local s = SIZES[anim] or 64
	if type(s) == "table" then return s[1], s[2] end
	return s, s
end

function M.new(z, anim, layer)
	local panel = anim == nil or PANELS[anim] == true
	local f = FACTORIES[layer or "ground"] or FACTORIES.ground
	local id = factory.create(panel and f.panel or f.tile, vmath.vector3(0, 0, z or 0))
	local t = { id = id, sprite = msg.url(nil, id, "sprite"), label = msg.url(nil, id, "label"),
		anim = "round", panel = panel, visible = true }
	if anim and anim ~= "round" then M.anim(t, anim) end
	return t
end

function M.anim(t, anim)
	if t.anim ~= anim then
		sprite.play_flipbook(t.sprite, anim)
		t.anim = anim
	end
end

local function size(t, w, h)
	if not w then
		go.set(t.sprite, t.panel and "size" or "scale", vmath.vector3(0, 0, 0))
	elseif t.panel then
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

function M.text(t, s, px, color)
	go.set(t.label, "text", s or "")
	local k = math.max(M.MIN_TEXT, px or 24) / FONT_PX
	go.set(t.label, "scale", vmath.vector3(k, k, 1))
	if color then go.set(t.label, "color", color) end
end

function M.show(t, visible)
	if t.visible == visible then return end
	t.visible = visible
	msg.post(t.id, visible and "enable" or "disable")
end

function M.delete(t)
	if t and t.id and go.exists(t.id) then
		t.alive = false
		go.delete(t.id)
	end
end

return M
