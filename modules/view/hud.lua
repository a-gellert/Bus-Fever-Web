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
M.NAMES = NAMES

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
	self.sound = { bg = tile.new(Z), icon = tile.new(Z + 0.01, "icon_sound") }
	self.bar_bg = tile.new(Z, "bar")
	self.bar = tile.new(Z + 0.01, "bar")
	self.coin = tile.new(Z + 0.01, "coin")
	self.coin_txt = tile.new(Z + 0.02)
	self.coin_value = 0
	self.progress = 0
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
	tile.set(self.sound.bg, { x = L.sound_pos.x, y = L.sound_pos.y, w = hs * 0.9, h = hs * 0.9, tint = palette.PANEL })
	tile.set(self.sound.icon, { x = L.sound_pos.x, y = L.sound_pos.y, w = hs * 0.62, h = hs * 0.62, tint = palette.CREAM,
		anim = audio.is_user_muted() and "icon_mute" or "icon_sound" })
	self.sound.rect = { x = L.sound_pos.x, y = L.sound_pos.y, w = math.max(48, hs), h = math.max(48, hs) }
	self:set_progress(self.progress)
	self:set_coins(self.coin_value)
	if self.popup then self:show_popup(self.popup.title, self.popup.options, self.popup.info) end
	if self.hand_target then self:point(self.hand_target.x, self.hand_target.y) end
end

-- Coin balance under the right end of the progress bar
function M:set_coins(n)
	self.coin_value = n or 0
	local L = self.L
	local hs = L.restart_size
	local w = math.min(L.header.w * 0.5, hs * 4.5) * 0.8
	local s = hs * 0.34
	local x = L.title_pos.x + w * 0.5 + s * 1.15
	local y = L.title_pos.y - hs * 0.6
	tile.set(self.coin, { x = x, y = y, w = s, h = s, tint = palette.GOLD })
	local text = self.coin_value > 999 and "999" or tostring(self.coin_value)
	tile.set(self.coin_txt, { x = x + s * 1.3, y = y, text = text, text_px = hs * 0.24, text_color = palette.CREAM })
	local visible = not self.popup
	tile.show(self.coin, visible)
	tile.show(self.coin_txt, visible)
end

-- Thin level progress bar under the title (passengers boarded / total)
function M:set_progress(f)
	self.progress = math.max(0, math.min(1, f or 0))
	local L = self.L
	local hs = L.restart_size
	local w = math.min(L.header.w * 0.5, hs * 4.5) * 0.8
	local h = math.max(6, hs * 0.16)
	local y = L.title_pos.y - hs * 0.6
	tile.set(self.bar_bg, { x = L.title_pos.x, y = y, w = w, h = h, tint = palette.PANEL })
	local fw = math.max(h, w * self.progress)
	tile.set(self.bar, { x = L.title_pos.x - w * 0.5 + fw * 0.5, y = y, w = fw, h = h, tint = palette.GOLD })
	tile.show(self.bar, self.progress > 0)
end

-- Touch feedback: a ring that grows and fades where the finger landed
function M:ripple(x, y)
	local s = math.max(36, (self.L.unit or 30) * 1.4)
	local t = tile.new(0.99, "ring")
	tile.set(t, { x = x, y = y, w = s, h = s, tint = vmath.vector4(1, 1, 1, 0.55) })
	go.set_scale(0.35, t.id)
	go.animate(t.id, "scale", go.PLAYBACK_ONCE_FORWARD, vmath.vector3(1.1, 1.1, 1), go.EASING_OUTQUAD, 0.3)
	go.animate(t.sprite, "tint.w", go.PLAYBACK_ONCE_FORWARD, 0, go.EASING_INQUAD, 0.3, 0, function() tile.delete(t) end)
end

-- Praise for quick chains of departures: pops at (x, y) with a star, floats up, shrinks away
function M:praise(text, x, y)
	local L = self.L
	local px = math.max(22, math.min(L.w * 0.08, 46))
	local star = tile.new(0.95, "star")
	tile.set(star, { x = x, y = y, w = px * 2.2, h = px * 2.2, tint = vmath.vector4(1, 0.82, 0.25, 0.9) })
	if self.praised then -- only the newest praise stays on screen
		for _, o in ipairs(self.praised) do tile.delete(o) end
	end
	local t = tile.new(0.96) -- label sits +0.01 above: keep it under the far plane (z < 1)
	tile.set(t, { x = x, y = y, text = text, text_px = px, text_color = palette.GOLD })
	self.praised = { t, star }
	for _, o in ipairs({ t, star }) do
		juice.pop(o.id, 1)
		go.animate(o.id, "position.y", go.PLAYBACK_ONCE_FORWARD, y + px * 1.6, go.EASING_OUTQUAD, 0.9)
	end
	go.animate(star.id, "euler.z", go.PLAYBACK_ONCE_FORWARD, 120, go.EASING_OUTQUAD, 0.9)
	timer.delay(0.7, false, function()
		for _, o in ipairs({ t, star }) do
			if o.alive ~= false and self.praised and (self.praised[1] == o or self.praised[2] == o) then
				go.animate(o.id, "scale", go.PLAYBACK_ONCE_FORWARD, vmath.vector3(0.01, 0.01, 1), go.EASING_INBACK, 0.25, 0,
					function() tile.delete(o) end)
			end
		end
	end)
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
	if hit(self.sound.rect, x, y) then
		juice.pop(self.sound.bg.id, 1)
		return "sound"
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
-- info (optional) = { icon = "icon_vip", tint = vector4, lines = { "SEND ANY BUS", "TO THE VIP SPOT" } }
function M:show_popup(title, options, info)
	self:hide_popup(true)
	local L = self.L
	local w = math.min(L.w * 0.82, 560)
	local h = math.max(52, math.min(L.h * 0.075, 84))
	local items = {}
	local dim = tile.new(Z + 0.05)
	tile.set(dim, { x = L.w * 0.5, y = L.h * 0.5, w = L.w, h = L.h, tint = palette.DIM })
	local info_h = info and h * (1.9 + 0.62 * #info.lines) or 0
	local total = h * 1.25 * #options + h * 1.6 + info_h
	local panel = tile.new(Z + 0.06)
	tile.set(panel, { x = L.w * 0.5, y = L.h * 0.5, w = w + 36, h = total + 36, tint = palette.PANEL })
	local head = tile.new(Z + 0.07)
	local top = L.h * 0.5 + total * 0.5
	tile.set(head, { x = L.w * 0.5, y = top - h * 0.7, text = title, text_px = h * 0.55, text_color = palette.GOLD })
	local extra = {}
	if info then
		local icon = tile.new(Z + 0.07, info.icon)
		local s = h * 1.4
		tile.set(icon, { x = L.w * 0.5, y = top - h * 1.5 - s * 0.5, w = s, h = s, tint = info.tint or palette.WHITE })
		juice.pulse(icon.id, 0.08, 0.5)
		extra[#extra + 1] = icon
		for i, line in ipairs(info.lines) do
			local t = tile.new(Z + 0.07)
			tile.set(t, { x = L.w * 0.5, y = top - h * 1.6 - s - (i - 0.3) * h * 0.62, text = line, text_px = h * 0.4,
				text_color = palette.CREAM })
			extra[#extra + 1] = t
		end
	end
	for i, o in ipairs(options) do
		local y = top - h * 1.6 - info_h - (i - 0.5) * h * 1.25
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
	self.popup = { title = title, options = options, info = info, items = items, dim = dim, panel = panel, head = head, extra = extra }
	self:relayout_labels()
end

function M:hide_popup(silent)
	if not self.popup then return end
	for _, o in ipairs(self.popup.items) do tile.delete(o.bg); tile.delete(o.icon) end
	tile.delete(self.popup.dim); tile.delete(self.popup.panel); tile.delete(self.popup.head)
	for _, t in ipairs(self.popup.extra or {}) do tile.delete(t) end
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
	tile.show(self.coin, false)
	tile.show(self.coin_txt, false)
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
	tile.delete(self.sound.bg); tile.delete(self.sound.icon); tile.delete(self.bar_bg); tile.delete(self.bar)
	tile.delete(self.coin); tile.delete(self.coin_txt)
end

return M
