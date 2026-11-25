-- Orthographic 2D HUD overlay: sleek glossy 9-slice cards, header pill, coin badge, modal dialogs, tutorial hand.
local palette = require("modules.view.palette")
local juice = require("modules.view.juice")
local tile = require("modules.view.tile")
local audio = require("modules.view.audio")

local M = {}
M.__index = M

local Z = 0.2

-- order matches layout.button_pos
M.BOOSTERS = { "vip", "arrange", "jumble" }
local ICONS = { vip = "icon_vip", arrange = "icon_arrange", jumble = "icon_jumble" }
local NAMES = { vip = "VIP", arrange = "Arrange", jumble = "Jumble" }
M.NAMES = NAMES

local function hit(r, x, y)
	return r and math.abs(x - r.x) <= r.w * 0.5 and math.abs(y - r.y) <= r.h * 0.5
end

function M.new(L)
	local self = setmetatable({ buttons = {}, popup = nil, state = {} }, M)
	for _, name in ipairs(M.BOOSTERS) do
		self.buttons[name] = {
			bg = tile.new(Z, "ui_card", "hud"),
			icon = tile.new(Z + 0.02, ICONS[name], "hud"),
			badge = tile.new(Z + 0.03, "ui_badge", "hud"),
			lock = tile.new(Z + 0.03, "icon_lock", "hud"),
			txt = tile.new(Z + 0.03, nil, "hud"),
		}
	end
	self.title = tile.new(Z, "ui_pill", "hud")
	self.restart = { bg = tile.new(Z, "ui_pill", "hud"), icon = tile.new(Z + 0.01, "icon_restart", "hud") }
	self.sound = { bg = tile.new(Z, "ui_pill", "hud"), icon = tile.new(Z + 0.01, "icon_sound", "hud") }
	self.bar_bg = tile.new(Z, "ui_bar", "hud")
	self.bar = tile.new(Z + 0.01, "ui_bar", "hud")
	self.coin_bg = tile.new(Z, "ui_pill", "hud")
	self.coin = tile.new(Z + 0.01, "coin", "hud")
	self.coin_txt = tile.new(Z + 0.02, nil, "hud")
	self.coin_value = 0
	self.progress = 0
	self.hand = tile.new(0.92, "hand", "hud")
	tile.show(self.hand, false)
	self:relayout(L)
	return self
end

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
		local anim = st.unlocked and (st.active and "ui_btn_gold" or "ui_card") or "ui_card_off"
		local label = st.active and "TAP BUS" or (st.unlocked and NAMES[name] or ("LV " .. st.unlock_level))
		tile.set(b.bg, { x = p.x, y = p.y, w = bw, h = bh, anim = anim, tint = palette.WHITE })
		local s = math.min(bh * 0.70, bw * 0.48)
		tile.set(b.icon, { x = p.x, y = p.y + bh * 0.16, w = s, h = s,
			tint = st.unlocked and palette.WHITE or vmath.vector4(1, 1, 1, 0.80) })
		tile.set(b.txt, { x = p.x, y = p.y - bh * 0.27, text = label,
			text_px = bh * (st.unlocked and 0.21 or 0.22),
			text_color = palette.WHITE })

		local bs = bh * 0.34
		tile.set(b.badge, { x = p.x + bw * 0.43, y = p.y + bh * 0.43, w = bs, h = bs,
			tint = st.count > 0 and palette.BADGE or palette.BUTTON_OK,
			text = st.count > 0 and tostring(st.count) or "+", text_px = bs * 0.68, text_color = palette.WHITE })
		tile.show(b.badge, st.unlocked and not self.popup)
		tile.set(b.lock, { x = p.x + bw * 0.43, y = p.y + bh * 0.43, w = bs, h = bs, tint = palette.WHITE })
		tile.show(b.lock, not st.unlocked)
		if self.popup then tile.text(b.txt, "", 12) end
	end
	local hs = L.restart_size
	tile.set(self.title, { x = L.title_pos.x, y = L.title_pos.y, w = math.min(L.header.w * 0.48, hs * 4.2), h = hs * 0.84,
		tint = palette.WHITE, text = self.popup and "" or (self.title_text or ""), text_px = hs * 0.48, text_color = palette.CREAM })
	tile.set(self.restart.bg, { x = L.restart_pos.x, y = L.restart_pos.y, w = hs * 0.88, h = hs * 0.88, tint = palette.WHITE })
	tile.set(self.restart.icon, { x = L.restart_pos.x, y = L.restart_pos.y, w = hs * 0.56, h = hs * 0.56, tint = palette.WHITE })
	self.restart.rect = { x = L.restart_pos.x, y = L.restart_pos.y, w = math.max(48, hs), h = math.max(48, hs) }
	tile.set(self.sound.bg, { x = L.sound_pos.x, y = L.sound_pos.y, w = hs * 0.88, h = hs * 0.88, tint = palette.WHITE })
	tile.set(self.sound.icon, { x = L.sound_pos.x, y = L.sound_pos.y, w = hs * 0.58, h = hs * 0.58, tint = palette.WHITE,
		anim = audio.is_user_muted() and "icon_mute" or "icon_sound" })
	self.sound.rect = { x = L.sound_pos.x, y = L.sound_pos.y, w = math.max(48, hs), h = math.max(48, hs) }
	self:set_progress(self.progress)
	self:set_coins(self.coin_value)
	if self.popup then self:show_popup(self.popup.title, self.popup.options, self.popup.info) end
	if self.hand_target then self:point(self.hand_target.x, self.hand_target.y) end
end

function M:set_coins(n)
	self.coin_value = n or 0
	local L = self.L
	local hs = L.restart_size
	local w = math.min(L.header.w * 0.48, hs * 4.2) * 0.8
	local s = hs * 0.36
	local cx = L.title_pos.x + w * 0.5 + hs * 0.82
	local y = L.title_pos.y - hs * 0.62
	tile.set(self.coin_bg, { x = cx + hs * 0.25, y = y, w = hs * 1.45, h = hs * 0.50, tint = palette.WHITE })
	tile.set(self.coin, { x = cx - hs * 0.22, y = y, w = s, h = s, tint = palette.WHITE })
	local text = self.coin_value > 999 and "999" or tostring(self.coin_value)
	tile.set(self.coin_txt, { x = cx + hs * 0.42, y = y, text = text, text_px = hs * 0.28, text_color = palette.CREAM })
	local visible = not self.popup
	tile.show(self.coin_bg, visible)
	tile.show(self.coin, visible)
	tile.show(self.coin_txt, visible)
end

function M:set_progress(f)
	self.progress = math.max(0, math.min(1, f or 0))
	local L = self.L
	local hs = L.restart_size
	local w = math.min(L.header.w * 0.48, hs * 4.2) * 0.78
	local h = math.max(8, hs * 0.20)
	local y = L.title_pos.y - hs * 0.62
	tile.set(self.bar_bg, { x = L.title_pos.x, y = y, w = w, h = h, tint = palette.hex("334155", 0.85) })
	local fw = math.max(h, w * self.progress)
	tile.set(self.bar, { x = L.title_pos.x - w * 0.5 + fw * 0.5, y = y, w = fw, h = h, tint = palette.GOLD })
	tile.show(self.bar, self.progress > 0)
end

function M:ripple(x, y)
	local s = math.max(36, (self.L.unit or 30) * 1.4)
	local t = tile.new(0.95, "ring", "hud")
	tile.set(t, { x = x, y = y, w = s, h = s, tint = vmath.vector4(1, 1, 1, 0.55) })
	go.set_scale(0.35, t.id)
	go.animate(t.id, "scale", go.PLAYBACK_ONCE_FORWARD, vmath.vector3(1.1, 1.1, 1), go.EASING_OUTQUAD, 0.3)
	go.animate(t.sprite, "tint.w", go.PLAYBACK_ONCE_FORWARD, 0, go.EASING_INQUAD, 0.3, 0, function() tile.delete(t) end)
end

function M:praise(text, x, y)
	local L = self.L
	local px = math.max(22, math.min(L.w * 0.08, 46))
	local star = tile.new(0.85, "star", "hud")
	tile.set(star, { x = x, y = y, w = px * 2.2, h = px * 2.2, tint = vmath.vector4(1, 1, 1, 0.92) })
	if self.praised then
		for _, o in ipairs(self.praised) do tile.delete(o) end
	end
	local t = tile.new(0.86, nil, "hud")
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

function M:show_popup(title, options, info)
	self:hide_popup(true)
	local L = self.L
	local w = math.min(L.w * 0.80, 520)
	local h = math.max(52, math.min(L.h * 0.075, 80))
	local items = {}
	local dim = tile.new(0.45, nil, "hud")
	tile.set(dim, { x = L.w * 0.5, y = L.h * 0.5, w = L.w, h = L.h, tint = palette.DIM })
	local info_h = info and h * (2.1 + 0.62 * #info.lines) or 0
	local total = h * 1.25 * #options + h * 1.7 + info_h
	local panel = tile.new(0.48, "ui_modal", "hud")
	tile.set(panel, { x = L.w * 0.5, y = L.h * 0.5, w = w + 38, h = total + 38, tint = palette.WHITE })
	local top = L.h * 0.5 + total * 0.5
	local head = tile.new(0.50, "ui_modal_head", "hud")
	tile.set(head, { x = L.w * 0.5, y = top - h * 0.55, w = w + 12, h = h * 0.96, tint = palette.WHITE,
		text = title, text_px = h * 0.48, text_color = palette.WHITE })
	local extra = {}
	if info then
		local s = h * 1.5
		local well = tile.new(0.49, "ui_pill", "hud")
		tile.set(well, { x = L.w * 0.5, y = top - h * 1.4 - s * 0.5, w = s * 1.3, h = s * 1.3, tint = palette.hex("e2e8f0", 0.45) })
		extra[#extra + 1] = well
		local icon = tile.new(0.51, info.icon, "hud")
		tile.set(icon, { x = L.w * 0.5, y = top - h * 1.4 - s * 0.5, w = s, h = s, tint = palette.WHITE })
		juice.pulse(icon.id, 0.08, 0.5)
		extra[#extra + 1] = icon
		local lines_y = top - h * 1.65 - s * 1.15
		local box_h = h * (0.65 * #info.lines + 0.25)
		local box = tile.new(0.49, "ui_pill", "hud")
		tile.set(box, { x = L.w * 0.5, y = lines_y - box_h * 0.5 + h * 0.25, w = w * 0.92, h = box_h, tint = palette.WHITE })
		extra[#extra + 1] = box
		for i, line in ipairs(info.lines) do
			local t = tile.new(0.51, nil, "hud")
			tile.set(t, { x = L.w * 0.5, y = lines_y - (i - 0.5) * h * 0.58, text = line, text_px = h * 0.36,
				text_color = palette.WHITE })
			extra[#extra + 1] = t
		end
	end
	for i, o in ipairs(options) do
		local y = top - h * 1.65 - info_h - (i - 0.5) * h * 1.25
		local anim = (i == 1) and (o.icon == "icon_ad" and "ui_btn_gold" or "ui_btn_green") or "ui_btn_grey"
		local bg = tile.new(0.52, anim, "hud")
		tile.set(bg, { x = L.w * 0.5, y = y, w = w, h = h, tint = palette.WHITE,
			text = o.text, text_px = h * 0.40, text_color = palette.WHITE })
		local icon
		if o.icon then
			icon = tile.new(0.54, o.icon, "hud")
			tile.set(icon, { x = L.w * 0.5 - w * 0.5 + h * 0.6, y = y + 2, w = h * 0.58, h = h * 0.58, tint = palette.WHITE })
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

function M:relayout_labels()
	for _, name in ipairs(M.BOOSTERS) do
		local b = self.buttons[name]
		tile.text(b.txt, "", 12)
		tile.show(b.badge, false)
	end
	go.set(self.title.label, "text", "")
	tile.show(self.coin_bg, false)
	tile.show(self.coin, false)
	tile.show(self.coin_txt, false)
end

function M:is_modal() return self.popup ~= nil end

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

function M:banner(text, color)
	local L = self.L
	local t = tile.new(0.88, nil, "hud")
	tile.set(t, { x = L.w * 0.5, y = L.h * 0.55, text = text, text_px = math.min(L.w * 0.1, 64), text_color = color or palette.GOLD })
	juice.pop(t.id, 1)
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
	tile.delete(self.coin_bg); tile.delete(self.coin); tile.delete(self.coin_txt)
end

return M
