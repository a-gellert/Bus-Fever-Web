-- Lot and bays on screen: backdrop, lot, bay pier, garages, vehicles; sim events -> animations.
-- Vehicles are visual only (no scripts); this module owns their game objects.
local config = require("modules.config")
local layout = require("modules.view.layout")
local palette = require("modules.view.palette")
local juice = require("modules.view.juice")
local audio = require("modules.view.audio")
local geometry = require("modules.sim.geometry")
local rules = require("modules.sim.rules")
local tile = require("modules.view.tile")
local route = require("modules.view.route")

local M = {}
M.__index = M

local BUS_FACTORY = "/level#bus_factory" -- collectionfactory: /root (label) + /body (sprites) + /shadow
local IMG_BUS = vmath.vector3(72, 36, 1)  -- bus.png / shadow.png, facing +x; body is 70x30 of it
local IMG_ARROW = 32

local Z_BACK, Z_LOT, Z_BAY, Z_BUS, Z_BUS_MOVING = -0.9, -0.5, 0.05, 0.2, 0.5

local function url(id, comp) return msg.url(nil, id, comp) end

function M.new(st, L)
	local self = setmetatable({ st = st, L = L, buses = {}, bays = {}, bay_ads = {}, garages = {}, movers = {}, labels = true }, M)
	self.backdrop = tile.new(Z_BACK, "backdrop")
	self.lot_border = tile.new(Z_LOT - 0.01)
	self.lot = tile.new(Z_LOT)
	self.pier_rim = tile.new(Z_BAY - 0.03)
	self.pier = tile.new(Z_BAY - 0.02)
	for i, bay in ipairs(st.bays) do
		self.bays[i] = tile.new(Z_BAY, "slot")
		self.bay_ads[i] = tile.new(Z_BAY + 0.01, "icon_ad")
	end
	for i in ipairs(st.garages) do self.garages[i] = tile.new(Z_BUS, "garage") end
	for _, id in ipairs(st.order) do self:spawn(id) end
	self:relayout(L)
	return self
end

-- unit for a bus parked in a bay: every bus fills its bay, short or long (reads better, like toys)
local function bay_unit(L, bus)
	local s = config.SIZES[bus.size]
	return math.min(L.slot_w * 0.62 / s.wid, L.bay_unit * 3.9 / s.len)
end

-- pixel size of a vehicle with lot unit `u`
local function body_scale(bus, u)
	local s = config.SIZES[bus.size]
	return vmath.vector3(s.len * u / 70, s.wid * u * 0.92 / 30, 1)
end

function M:spawn(id)
	local ids = collectionfactory.create(BUS_FACTORY, vmath.vector3(0, 0, Z_BUS))
	local v = { root = ids[hash("/root")], body = ids[hash("/body")], shadow = ids[hash("/shadow")] }
	self.buses[id] = v
	go.set(url(v.shadow, "sprite"), "tint", palette.SHADOW)
	self:paint(id)
	return v
end

function M:paint(id)
	local bus, v = self.st.buses[id], self.buses[id]
	if not v then return end
	go.set(url(v.body, "body"), "tint", bus.hidden and palette.HIDDEN or palette.of(bus.color))
	go.set(url(v.body, "roof"), "tint", bus.hidden and vmath.vector4(1, 1, 1, 0.5) or palette.WHITE)
	local text = ""
	if bus.hidden then text = "?" elseif bus.state ~= "lot" and bus.left > 0 then text = tostring(bus.left) end
	go.set(url(v.root, "count"), "text", self.labels and text or "")
end

-- Where a bus stands for its current state (pixels, degrees, lot unit used for its size)
function M:pose(id)
	local bus, L = self.st.buses[id], self.L
	if bus.state == "lot" then
		local x, y = layout.lot_to_world(L, bus.box.x, bus.box.y)
		return vmath.vector3(x, y, Z_BUS), math.deg(bus.box.angle), L.unit
	end
	local p = L.bay_pos[bus.bay]
	return vmath.vector3(p.x, p.y, Z_BUS), 90, bay_unit(L, bus)
end

local function set_size(self, id, u)
	local v, bus = self.buses[id], self.st.buses[id]
	local bs = body_scale(bus, u)
	go.set(url(v.body, "body"), "scale", bs)
	go.set(url(v.shadow, "sprite"), "scale", bs)
	go.set(v.shadow, "position", vmath.vector3(u * 0.10, -u * 0.16, -0.02)) -- light from the top-left
	local a = u * 0.62 / IMG_ARROW
	go.cancel_animations(url(v.body, "roof"), "scale")
	go.set(url(v.body, "roof"), "scale", vmath.vector3(a, a, 1))
	v.roof_scale, v.free = a, nil -- mark_free re-applies the pulse
	local text = bus.hidden and u * 0.95 or u * 0.55
	local s = math.max(tile.MIN_TEXT, text) / 40
	go.set(url(v.root, "count"), "scale", vmath.vector3(s, s, 1))
end

local function place(self, id)
	local v = self.buses[id]
	self.movers[id] = nil
	go.cancel_animations(url(v.body, "body"), "scale")
	go.cancel_animations(url(v.shadow, "sprite"), "scale")
	local pos, deg, u = self:pose(id)
	go.cancel_animations(v.root, "position")
	go.cancel_animations(v.body, "euler.z")
	go.cancel_animations(v.shadow, "euler.z")
	go.set_position(pos, v.root)
	go.set(v.body, "euler.z", deg)
	go.set(v.shadow, "euler.z", deg)
	set_size(self, id, u)
end

function M:paint_bays()
	local L = self.L
	local n = #self.st.bays
	local pw, ph = L.slot_w * n + L.slot_w * 0.2, L.bay_unit * 4.6
	local px, py = L.bays.x + L.bays.w * 0.5, L.bays.y + L.bays.h * 0.5
	tile.set(self.pier_rim, { x = px, y = py, w = pw + 4, h = ph + 4, tint = palette.PIER_RIM })
	tile.set(self.pier, { x = px, y = py, w = pw, h = ph, tint = palette.PANEL })
	for i, bay in ipairs(self.st.bays) do
		local p = L.bay_pos[i]
		local tint, text = palette.BAY, ""
		if bay.kind == "vip" then tint, text = palette.BAY_VIP, "VIP" end
		if bay.kind == "locked" then tint, text = palette.BAY_LOCKED, "+" end
		local w, h = math.max(L.slot_w * 0.8, 20), L.bay_unit * 4.3
		tile.set(self.bays[i], { x = p.x, y = p.y, w = w, h = h, tint = tint,
			text = self.labels and text or "", text_px = math.min(w * (bay.kind == "vip" and 0.42 or 0.7), h * 0.3),
			text_color = bay.kind == "locked" and palette.GOLD or palette.WHITE })
		local ad = self.bay_ads[i]
		local s = math.min(w * 0.8, h * 0.3)
		tile.set(ad, { x = p.x, y = p.y - h * 0.28, w = s, h = s, tint = palette.GOLD })
		tile.show(ad, bay.kind == "locked" and self.labels)
	end
end

-- Garage: rotated roller door with the number of vehicles still inside
function M:paint_garages()
	local L = self.L
	for i, g in ipairs(self.st.garages) do
		local x, y = layout.lot_to_world(L, g.x, g.y)
		local count = #g.queue
		tile.set(self.garages[i], { x = x, y = y, w = g.len * L.unit, h = g.wid * L.unit * 0.95,
			tint = count > 0 and palette.GARAGE or palette.BUTTON_OFF, rot = math.deg(g.angle),
			text = (self.labels and count > 0) and tostring(count) or "", text_px = L.unit * 0.7 })
	end
end

function M:relayout(L)
	self.L = L
	tile.set(self.backdrop, { x = L.w * 0.5, y = L.h * 0.5, w = L.w, h = L.h, tint = palette.WHITE })
	local lw, lh = self.st.lot.w * L.unit, self.st.lot.h * L.unit
	local cx, cy = L.lot_x + lw * 0.5, L.lot_y + lh * 0.5
	local pad = L.unit * 0.35
	tile.set(self.lot_border, { x = cx, y = cy, w = lw + pad * 2 + 6, h = lh + pad * 2 + 6, tint = palette.LOT_BORDER })
	tile.set(self.lot, { x = cx, y = cy, w = lw + pad * 2, h = lh + pad * 2, tint = palette.ASPHALT })
	self:paint_bays()
	self:paint_garages()
	for id in pairs(self.buses) do
		if self.st.buses[id].state ~= "gone" then place(self, id) end
	end
end

-- Vehicles that can leave right now: their arrow disc breathes, teaching the rule without text
function M:mark_free()
	for id, v in pairs(self.buses) do
		local bus = self.st.buses[id]
		local free = bus.state == "lot" and rules.exit_check(self.st, id) or false
		if free ~= v.free and v.roof_scale then
			v.free = free
			local roof = url(v.body, "roof")
			local a = v.roof_scale
			go.cancel_animations(roof, "scale")
			go.set(roof, "scale", vmath.vector3(a, a, 1))
			if free then
				go.animate(roof, "scale", go.PLAYBACK_LOOP_PINGPONG, vmath.vector3(a * 1.18, a * 1.18, 1), go.EASING_INOUTSINE, 0.45)
			end
		end
	end
end

-- Pulse the "+" bays while the player is one step from Out of Spots
function M:warn(on)
	if on == (self.warning or false) then return end
	self.warning = on
	for i, bay in ipairs(self.st.bays) do
		local id = self.bays[i].id
		if on and bay.kind == "locked" then
			juice.pulse(id, 0.1, 0.35)
		else
			go.cancel_animations(id, "scale")
			go.set_scale(1, id)
		end
	end
end

-- Hide numbers under popups (labels ignore z order in the render script)
function M:set_labels(visible)
	self.labels = visible
	for id in pairs(self.buses) do self:paint(id) end
	self:paint_bays()
	self:paint_garages()
end

-- Tap -> bus id under the point (lot buses only)
function M:pick(x, y)
	local lx, ly = layout.world_to_lot(self.L, x, y)
	local best, best_d
	for _, id in ipairs(self.st.order) do
		local bus = self.st.buses[id]
		if bus.state == "lot" and geometry.contains(bus.box, lx, ly, 0.25) then
			local d = (bus.box.x - lx) ^ 2 + (bus.box.y - ly) ^ 2
			if not best_d or d < best_d then best, best_d = id, d end
		end
	end
	return best
end

-- Tap -> bay index under the point
function M:pick_bay(x, y)
	local L = self.L
	for i, p in ipairs(L.bay_pos) do
		if math.abs(x - p.x) < L.slot_w * 0.5 and math.abs(y - p.y) < L.bay_unit * 2.3 then return i end
	end
end

local SPEED = 22                 -- lot units per second along the route
local MIN_TIME, MAX_TIME = 0.5, 1.35

-- Road route from the bus's parking spot to a bay (pixels)
function M:route(id, bay)
	local bus, L = self.st.buses[id], self.L
	local x, y = layout.lot_to_world(L, bus.box.x, bus.box.y)
	local x1, y1 = layout.lot_to_world(L, self.st.lot.w, self.st.lot.h)
	local p = L.bay_pos[bay]
	return route.build({ x = x, y = y, ux = bus.box.ux, uy = bus.box.uy },
		{ x0 = L.lot_x, y0 = L.lot_y, x1 = x1, y1 = y1 },
		p, L.bay_unit * 3.2, L.unit * 0.8, L.unit * 0.7)
end

-- Seconds the drive takes (the sim waits for this before passengers board)
function M:travel_time(id, bay)
	local len = self:route(id, bay).length / self.L.unit
	return math.min(MAX_TIME, math.max(MIN_TIME, len / SPEED))
end

local function smooth(k) return k * k * (3 - 2 * k) end -- pull away, cruise, brake
local function accelerate(k) return k * k end          -- leaving: floor it

-- exhaust puff at the back of a moving bus
local function puff(self, x, y, size)
	local t = tile.new(Z_BUS - 0.05, "disc")
	tile.set(t, { x = x, y = y, w = size, h = size, tint = vmath.vector4(0.85, 0.9, 1, 0.3) })
	local life = 0.35
	go.animate(t.id, "scale", go.PLAYBACK_ONCE_FORWARD, vmath.vector3(1.7, 1.7, 1), go.EASING_OUTQUAD, life)
	go.animate(t.sprite, "tint.w", go.PLAYBACK_ONCE_FORWARD, 0, go.EASING_OUTQUAD, life, 0, function() tile.delete(t) end)
end

local function start_mover(self, id, m)
	local v = self.buses[id]
	m.v, m.t, m.puff_t = v, 0, 0
	m.half = config.SIZES[self.st.buses[id].size].len * 0.5
	self.movers[id] = m
	go.cancel_animations(v.root, "position")
	juice.squash(v.body, 1) -- pull-away stretch
end

-- Drive along the road route: position and heading per frame (see M:update)
local function drive(self, id, time)
	local bus = self.st.buses[id]
	start_mover(self, id, { path = self:route(id, bus.bay), time = time, ease = smooth,
		from = body_scale(bus, self.L.unit), to = body_scale(bus, bay_unit(self.L, bus)), unit_from = self.L.unit,
		unit_to = bay_unit(self.L, bus) })
end

-- Full bus leaves: straight ahead out of the bay and off the screen, accelerating
local function depart(self, id, time)
	local L = self.L
	local p = L.bay_pos[self.st.buses[id].bay]
	local path = route.line(p.x, p.y, p.x, L.h + L.unit * 4)
	local bu = bay_unit(L, self.st.buses[id])
	local s = body_scale(self.st.buses[id], bu)
	start_mover(self, id, { path = path, time = time, ease = accelerate, from = s, to = s,
		unit_from = bu, unit_to = bu, leaving = true })
end

-- VIP: vanish from the lot, pop up in the VIP bay
local function teleport(self, id, time)
	local v = self.buses[id]
	go.cancel_animations(v.root, "scale")
	go.animate(v.root, "scale", go.PLAYBACK_ONCE_FORWARD, vmath.vector3(0.01, 0.01, 1), go.EASING_INBACK, time * 0.5, 0, function()
		if self.buses[id] then
			place(self, id)
			juice.pop(v.root, 1)
		end
	end)
end

function M:update(dt)
	for id, m in pairs(self.movers) do
		local v = m.v
		m.t = m.t + dt
		local k = math.min(1, m.t / m.time)
		local x, y, a = m.path:at(m.ease(k) * m.path.length)
		go.set_position(vmath.vector3(x, y, Z_BUS_MOVING), v.root)
		local deg = math.deg(a)
		go.set(v.body, "euler.z", deg)
		go.set(v.shadow, "euler.z", deg)
		local g = math.max(0, (k - 0.6) / 0.4) -- shrink to bay size on the last stretch
		local s = vmath.lerp(g, m.from, m.to)
		go.set(url(v.body, "body"), "scale", s)
		go.set(url(v.shadow, "sprite"), "scale", s)
		-- exhaust while moving
		m.puff_t = m.puff_t - dt
		if m.puff_t <= 0 and k < 0.92 then
			m.puff_t = 0.06
			local u = m.unit_from + (m.unit_to - m.unit_from) * g
			local back = m.half * u + u * 0.15
			puff(self, x - math.cos(a) * back, y - math.sin(a) * back, u * 0.22)
		end
		if k >= 1 then
			self.movers[id] = nil
			if m.leaving then
				go.delete(v.root, true)
			elseif self.buses[id] then
				place(self, id)
				juice.squash(v.body, 1) -- parking bump
			end
		end
	end
end
function M:bus_world_pos(id)
	local v = self.buses[id]
	return v and go.get_position(v.root) or vmath.vector3(self.L.w * 0.5, self.L.h * 0.5, 0)
end

-- Sim events -> animation. Unknown events are ignored.
function M:on_event(ev)
	local id = ev.bus
	local t = ev.type
	if t == "spawn" then
		self:spawn(id)
		place(self, id)
		juice.pop(self.buses[id].root, 1)
		self:paint_garages()
	elseif t == "reveal" or t == "recolor" then
		for _, bid in ipairs(ev.buses or { id }) do
			if self.buses[bid] then
				self:paint(bid)
				set_size(self, bid, self.L.unit)
				juice.pop(self.buses[bid].body, 1)
			end
		end
	elseif t == "drive" or t == "teleport" then
		self:paint(id)
		if t == "drive" then drive(self, id, ev.time) else teleport(self, id, ev.time) end
		audio.play(t == "drive" and "go" or "vip")
	elseif t == "blocked" then
		local bus = self.st.buses[id]
		juice.lurch(self.buses[id].root, bus.box.ux, bus.box.uy, math.min(ev.dist * self.L.unit, self.L.unit * 0.5))
		local blocker = ev.blocker and ev.blocker > 0 and self.buses[ev.blocker]
		if blocker then
			juice.shake(blocker.root, self.L.unit * 0.12)
			juice.flash(url(blocker.body, "body"), palette.of(self.st.buses[ev.blocker].color))
		end
		audio.play("honk")
	elseif t == "no_bay" then
		for _, b in ipairs(self.bays) do juice.shake(b.id, self.L.unit * 0.1) end
		audio.play("deny")
	elseif t == "board" then
		self:paint(id)
		juice.squash(self.buses[id].body, 1)
	elseif t == "full" then
		juice.flash(url(self.buses[id].body, "body"), palette.of(self.st.buses[id].color))
	elseif t == "depart" then
		depart(self, id, ev.time * 1.6)
		self.buses[id] = nil
		audio.play("depart")
	elseif t == "bay_unlocked" then
		self:paint_bays()
		juice.pop(self.bays[ev.bay].id, 1)
		audio.play("unlock")
	end
end

function M:delete()
	for _, m in pairs(self.movers) do
		if m.leaving then go.delete(m.v.root, true) end -- departing buses are no longer in self.buses
	end
	for _, v in pairs(self.buses) do go.delete(v.root, true) end
	self.buses, self.movers = {}, {} -- pending timers check these tables
	for i in ipairs(self.bays) do tile.delete(self.bays[i]); tile.delete(self.bay_ads[i]) end
	for _, g in ipairs(self.garages) do tile.delete(g) end
	for _, t in ipairs({ self.backdrop, self.lot_border, self.lot, self.pier, self.pier_rim }) do tile.delete(t) end
end

return M
