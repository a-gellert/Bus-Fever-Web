-- World-space HUD: booster buttons, restart, level number, Out of Spots popup.
-- Buttons are tile game objects + rect hit tests (one coordinate system with the board).
-- Swap for a Druid GUI later without touching the sim: the controller only calls these functions.
local palette = require("modules.view.palette")
local juice = require("modules.view.juice")

local M = {}
M.__index = M

local TILE_FACTORY = "/level#tile_factory"
local IMG_TILE = 64
local LABEL_PX = 24
local Z = 0.8

-- order matches layout.button_pos
M.BUTTONS = { "vip", "arrange", "jumble", "restart" }

local function tile_set(id, x, y, w, h, tint, text)
	go.set_position(vmath.vector3(x, y, go.get_position(id).z), id)
	go.set(msg.url(nil, id, "sprite"), "scale", vmath.vector3(w / IMG_TILE, h / IMG_TILE, 1))
	go.set(msg.url(nil, id, "sprite"), "tint", tint)
	go.set(msg.url(nil, id, "label"), "text", text)
	local s = math.min(h / (LABEL_PX * 2.4), w / (LABEL_PX * 0.6 * math.max(4, #text)))
	go.set(msg.url(nil, id, "label"), "scale", vmath.vector3(s, s, 1))
end

function M.new(L)
	local self = setmetatable({ buttons = {}, popup = nil, state = {} }, M)
	for _, name in ipairs(M.BUTTONS) do
		self.buttons[name] = { id = factory.create(TILE_FACTORY, vmath.vector3(0, 0, Z)) }
	end
	self.title = factory.create(TILE_FACTORY, vmath.vector3(0, 0, Z))
	self:relayout(L)
	return self
end

-- state[name] = { text = "VIP 1", enabled = bool }; title = "Level 7"
function M:set(state, title)
	self.state = state
	self.title_text = title
	self:relayout(self.L)
end

function M:relayout(L)
	self.L = L
	for i, name in ipairs(M.BUTTONS) do
		local b = self.buttons[name]
		local p, s = L.button_pos[i], L.button_size
		local st = self.state[name] or { text = name, enabled = true }
		b.rect = { x = p.x, y = p.y, w = s.w, h = s.h }
		b.enabled = st.enabled
		tile_set(b.id, p.x, p.y, s.w, s.h, st.enabled and palette.BUTTON or palette.BUTTON_OFF, st.text)
	end
	local w = L.portrait and L.w * 0.4 or L.w * 0.2
	tile_set(self.title, L.loop.x + L.loop.w * 0.5, L.loop.y + L.loop.h * 0.5, w, L.h * 0.05, palette.BAY, self.title_text or "")
	if self.popup then self:show_popup(self.popup.options) end
end

local function hit(r, x, y)
	return math.abs(x - r.x) <= r.w * 0.5 and math.abs(y - r.y) <= r.h * 0.5
end

-- Returns the action name under the point, or nil. Popup swallows all taps while open.
function M:pick(x, y)
	if self.popup then
		for _, o in ipairs(self.popup.items) do
			if hit(o.rect, x, y) then
				juice.pop(o.id, 1)
				return o.action
			end
		end
		return "popup_miss"
	end
	for _, name in ipairs(M.BUTTONS) do
		local b = self.buttons[name]
		if hit(b.rect, x, y) then
			juice.pop(b.id, 1)
			return b.enabled and name or nil
		end
	end
end

-- options = { {action = "rescue", text = "+1 slot (ad)"}, {action = "restart", text = "Restart"} }
function M:show_popup(options)
	self:hide_popup()
	local L = self.L
	local items = {}
	local w, h = math.min(L.w * 0.7, 520), L.h * 0.08
	for i, o in ipairs(options) do
		local id = factory.create(TILE_FACTORY, vmath.vector3(0, 0, Z + 0.1))
		local y = L.h * 0.5 - (i - (#options + 1) * 0.5) * h * 1.3
		tile_set(id, L.w * 0.5, y, w, h, i == 1 and palette.BAY_LOCKED or palette.BUTTON, o.text)
		juice.pop(id, 1)
		items[i] = { id = id, action = o.action, rect = { x = L.w * 0.5, y = y, w = w, h = h } }
	end
	self.popup = { options = options, items = items }
end

function M:hide_popup()
	if not self.popup then return end
	for _, o in ipairs(self.popup.items) do go.delete(o.id) end
	self.popup = nil
end

function M:delete()
	self:hide_popup()
	for _, b in pairs(self.buttons) do go.delete(b.id) end
	go.delete(self.title)
end

return M
