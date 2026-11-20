-- World-space HUD: header (level, restart), booster buttons, popups, tutorial hand, win banner.
-- Buttons are tile objects + rect hit tests (one coordinate system with the board).
-- The controller only calls these functions, so the HUD can move to a GUI later in this file alone.
local palette = require("modules.view.palette")
local juice = require("modules.view.juice")
local tile = require("modules.view.tile")
local audio = require("modules.view.audio")

local M = {}
M.__index = M

local Z = 0.8

-- order matches layout.button_pos
M.BOOSTERS = { "vip", "arrange", "jumble" }
local ICONS = { vip = "icon_vip", arrange = "icon_arrange", jumble = "icon_jumble" }
local NAMES = { vip = "VIP", arrange = "SORT", jumble = "MIX" }

local function hit(r, x, y)
	return r and math.abs(x - r.x) <= r.w * 0.5 and math.abs(y - r.y) <= r.h * 0.5
end

function M.new(L)
	local self = setmetatable({ buttons = {}, popup = nil, state = {} }, M)
	for _, name in ipairs(M.BOOSTERS) do
		self.buttons[name] = {
			bg = tile.new(Z), icon = tile.new(Z + 0.01, ICONS[name]),
			badge = tile.new(Z + 0.02, "disc"), lock = tile.new(Z + 0.02, "icon_lock"), txt = tile.new(Z + 0.02),
		}
	end
	self.title = tile.new(Z)
	self.restart = { bg = tile.new(Z), icon = tile.new(Z + 0.01, "icon_restart") }
	self.hand = tile.new(0.97, "hand")
	tile.show(self.hand, false)
	self:relayout(L)
	return self
end

-- state[name] = { count = n, unlocked = bool, unlock_level = n, active = bool }; title = "LEVEL 7"
function M:set(state, title)
	self.state = state
	self.title_text = title
	self:relayout(self.L)
end

function M:relayout(L)
	self.L = L
	local bw, bh = L.button_size.w, L.button_size.h
	for i, name in ipairs(M.BOOSTERS) do
		local b = self.buttons[name]
		local p = L.button_pos[i]
		local st = self.state[name] or { count = 0, unlocked = false, unlock_level = 0 }
		b.rect = { x = p.x, y = p.y, w = bw, h = bh }
		b.enabled = st.unlocked
		local tint = st.unlocked and palette.BUTTONS[name] or palette.BUTTON_OFF
		if st.active then tint = palette.GOLD end
		local label = st.active and "TAP BUS" or (st.unlocked and NAMES[name] or ("LV " .. st.unlock_level))
		tile.set(b.bg, { x = p.x, y = p.y, w = bw, h = bh, tint = tint })
		local s = math.min(bh * 0.55, bw * 0.4)
		tile.set(b.icon, { x = p.x, y = p.y + bh * 0.13, w = s, h = s,
			tint = st.unlocked and palette.WHITE or vmath.vector4(1, 1, 1, 0.35) })
		tile.set(b.txt, { x = p.x, y = p.y - bh * 0.3, text = label, text_px = bh * (st.unlocked and 0.2 or 0.24), text_color = palette.WHITE })

		-- count badge (or "+" = watch an ad for one) at the top-right corner
		local bs = bh * 0.34
		tile.set(b.badge, { x = p.x + bw * 0.42, y = p.y + bh * 0.4, w = bs, h = bs,
			tint = st.count > 0 and palette.BADGE or palette.BUTTON_OK,
			text = st.count > 0 and tostring(st.count) or "+", text_px = bs * 0.7, text_color = palette.WHITE })
		tile.show(b.badge, st.unlocked and not self.popup)
		tile.set(b.lock, { x = p.x + bw * 0.42, y = p.y + bh * 0.4, w = bs, h = bs, tint = palette.CREAM })
		tile.show(b.lock, not st.unlocked)
		if self.popup then tile.text(b.txt, "", 12) end
	end
	-- header
	local hs = L.restart_size
	tile.set(self.title, { x = L.title_pos.x, y = L.title_pos.y, w = math.min(L.header.w * 0.5, hs * 4.5), h = hs * 0.86,
		tint = palette.PANEL, text = self.popup and "" or (self.title_text or ""), text_px = hs * 0.5, text_color = palette.CREAM })
	tile.set(self.restart.bg, { x = L.restart_pos.x, y = L.restart_pos.y, w = hs * 0.9, h = hs * 0.9, tint = palette.PANEL })
	tile.set(self.restart.icon, { x = L.restart_pos.x, y = L.restart_pos.y, w = hs * 0.6, h = hs * 0.6, tint = palette.CREAM })
	self.restart.rect = { x = L.restart_pos.x, y = L.restart_pos.y, w = math.max(48, hs), h = math.max(48, hs) }
	if self.popup then self:show_popup(self.popup.title, self.popup.options) end
	if self.hand_target then self:point(self.hand_target.x, self.hand_target.y) end
end

-- Returns the action name under the point, or nil. A popup swallows all taps while open.
function M:pick(x, y)
	if self.popup then
		for _, o in ipairs(self.popup.items) do
			if hit(o.rect, x, y) then
				juice.pop(o.bg.id, 1)
				audio.play("tap")
				return o.action
			end
		end
		return "popup_miss"
	end
	if hit(self.restart.rect, x, y) then
		juice.pop(self.restart.bg.id, 1)
		audio.play("tap")
		return "restart"
	end
	for _, name in ipairs(M.BOOSTERS) do
		local b = self.buttons[name]
		if hit(b.rect, x, y) then
			juice.pop(b.bg.id, 1)
			if b.enabled then
				audio.play("tap")
				return name
			end
			audio.play("deny")
			return "locked"
		end
	end
end

-- Modal popup. options = { {action =, text =, icon = "icon_ad"|nil, tint = vector4|nil}, ... }
function M:show_popup(title, options)
	self:hide_popup(true)
	local L = self.L
	local w = math.min(L.w * 0.82, 560)
	local h = math.max(52, math.min(L.h * 0.075, 84))
	local items = {}
	local dim = tile.new(Z + 0.05)
	tile.set(dim, { x = L.w * 0.5, y = L.h * 0.5, w = L.w, h = L.h, tint = palette.DIM })
	local total = h * 1.25 * #options + h * 1.6
	local panel = tile.new(Z + 0.06)
	tile.set(panel, { x = L.w * 0.5, y = L.h * 0.5, w = w + 36, h = total + 36, tint = palette.PANEL })
	local head = tile.new(Z + 0.07)
	local top = L.h * 0.5 + total * 0.5
	tile.set(head, { x = L.w * 0.5, y = top - h * 0.7, text = title, text_px = h * 0.55, text_color = palette.GOLD })
	for i, o in ipairs(options) do
		local y = top - h * 1.6 - (i - 0.5) * h * 1.25
		local bg = tile.new(Z + 0.08)
		tile.set(bg, { x = L.w * 0.5, y = y, w = w, h = h, tint = o.tint or (i == 1 and palette.BUTTON_OK or palette.BUTTON_NEUTRAL),
			text = o.text, text_px = h * 0.42, text_color = palette.WHITE })
		local icon
		if o.icon then
			icon = tile.new(Z + 0.09, o.icon)
			tile.set(icon, { x = L.w * 0.5 - w * 0.5 + h * 0.6, y = y, w = h * 0.6, h = h * 0.6, tint = palette.WHITE })
		end
		juice.pop(bg.id, 1)
		items[i] = { bg = bg, icon = icon, action = o.action, rect = { x = L.w * 0.5, y = y, w = w, h = h } }
	end
	self.popup = { title = title, options = options, items = items, dim = dim, panel = panel, head = head }
	self:relayout_labels()
end

function M:hide_popup(silent)
	if not self.popup then return end
	for _, o in ipairs(self.popup.items) do tile.delete(o.bg); tile.delete(o.icon) end
	tile.delete(self.popup.dim); tile.delete(self.popup.panel); tile.delete(self.popup.head)
	self.popup = nil
	if not silent then self:relayout(self.L) end
end

-- labels draw above every sprite: blank the HUD's own texts while a popup is up
function M:relayout_labels()
	for _, name in ipairs(M.BOOSTERS) do
		local b = self.buttons[name]
		tile.text(b.txt, "", 12)
		tile.show(b.badge, false)
	end
	go.set(self.title.label, "text", "")
end

function M:is_modal() return self.popup ~= nil end

-- Tutorial pointer: hand tip at (x, y), pulsing. nil hides it.
function M:point(x, y)
	if not x then
		self.hand_target = nil
		tile.show(self.hand, false)
		return
	end
	local s = math.max(44, self.L.unit and self.L.unit * 2.2 or 60)
	local first = not self.hand_target
	self.hand_target = { x = x, y = y }
	tile.show(self.hand, true)
	tile.set(self.hand, { x = x + s * 0.1, y = y - s * 0.45, w = s, h = s, tint = palette.WHITE })
	if first then juice.pulse(self.hand.id, 0.12, 0.45) end
end

-- Big centred message that pops and fades (LEVEL COMPLETE!)
function M:banner(text, color)
	local L = self.L
	local t = tile.new(0.98)
	tile.set(t, { x = L.w * 0.5, y = L.h * 0.55, text = text, text_px = math.min(L.w * 0.1, 64), text_color = color or palette.GOLD })
	juice.pop(t.id, 1)
	-- label alpha does not animate: shrink the object away instead, then delete it
	timer.delay(1.1, false, function()
		go.animate(t.id, "scale", go.PLAYBACK_ONCE_FORWARD, vmath.vector3(0.01, 0.01, 1), go.EASING_INBACK, 0.3, 0,
			function() tile.delete(t) end)
	end)
end

function M:delete()
	self:hide_popup(true)
	for _, b in pairs(self.buttons) do
		tile.delete(b.bg); tile.delete(b.icon); tile.delete(b.badge); tile.delete(b.lock); tile.delete(b.txt)
	end
	tile.delete(self.title); tile.delete(self.restart.bg); tile.delete(self.restart.icon); tile.delete(self.hand)
end

return M
