-- Lot and bays on screen: spawns vehicles and bays, maps sim events to animations.
-- Vehicles are visual only (no scripts); this module owns their game objects.
local config = require("modules.config")
local layout = require("modules.view.layout")
local palette = require("modules.view.palette")
local juice = require("modules.view.juice")
local audio = require("modules.view.audio")
local geometry = require("modules.sim.geometry")

local M = {}
M.__index = M

local BUS_FACTORY = "/level#bus_factory"   -- collectionfactory: /root (label) + /body (sprites)
local TILE_FACTORY = "/level#tile_factory" -- sprite + label
local IMG_BUS = vmath.vector3(64, 32, 1)   -- bus.png, facing +x
local IMG_TILE = 64                        -- round.png
local LABEL_PX = 24                        -- builtin font at scale 1

local Z_LOT, Z_BAY, Z_BUS, Z_BUS_MOVING = 0.05, 0.1, 0.2, 0.5

function M.new(st, L)
	local self = setmetatable({ st = st, L = L, buses = {}, bays = {}, bg = nil }, M)
	self.bg = factory.create(TILE_FACTORY, vmath.vector3(0, 0, Z_LOT))
	for i in ipairs(st.bays) do
		self.bays[i] = factory.create(TILE_FACTORY, vmath.vector3(0, 0, Z_BAY))
	end
	self.garages = {}
	for i in ipairs(st.garages) do
		self.garages[i] = factory.create(TILE_FACTORY, vmath.vector3(0, 0, Z_BUS))
	end
	for _, id in ipairs(st.order) do self:spawn(id) end
	self:relayout(L)
	return self
end

local function url(id, comp) return msg.url(nil, id, comp) end

-- pixel size of a vehicle with lot unit `u`
local function body_scale(bus, u)
	local s = config.SIZES[bus.size]
	return vmath.vector3(s.len * u / IMG_BUS.x, s.wid * u * 0.86 / IMG_BUS.y, 1)
end

function M:spawn(id)
	local ids = collectionfactory.create(BUS_FACTORY, vmath.vector3(0, 0, Z_BUS))
	local v = { root = ids[hash("/root")], body = ids[hash("/body")] }
	self.buses[id] = v
	self:paint(id)
	return v
end

function M:paint(id)
	local bus, v = self.st.buses[id], self.buses[id]
	go.set(url(v.body, "body"), "tint", bus.hidden and palette.HIDDEN or palette.of(bus.color))
	local text = ""
	if bus.hidden then text = "?" elseif bus.state ~= "lot" then text = tostring(bus.left) end
	go.set(url(v.root, "count"), "text", text)
end

-- Where a bus stands for its current state (pixels, degrees, lot unit used for its size)
function M:pose(id)
	local bus, L = self.st.buses[id], self.L
	if bus.state == "lot" then
		local x, y = layout.lot_to_world(L, bus.box.x, bus.box.y)
		return vmath.vector3(x, y, Z_BUS), math.deg(bus.box.angle), L.unit
	end
	local p = L.bay_pos[bus.bay]
	return vmath.vector3(p.x, p.y, Z_BUS), 90, L.bay_unit
end

local function place(self, id)
	local v = self.buses[id]
	local pos, deg, u = self:pose(id)
	go.set_position(pos, v.root)
	go.set(v.body, "euler.z", deg)
	go.set(url(v.body, "body"), "scale", body_scale(self.st.buses[id], u))
	go.set(url(v.root, "count"), "scale", vmath.vector3(u / 40, u / 40, 1))
	go.set(url(v.body, "roof"), "scale", vmath.vector3(u * 0.6 / 32, u * 0.6 / 32, 1))
end

local function tile(id, x, y, w, h, tint, text)
	go.set_position(vmath.vector3(x, y, go.get_position(id).z), id)
	go.set(url(id, "sprite"), "scale", vmath.vector3(w / IMG_TILE, h / IMG_TILE, 1))
	go.set(url(id, "sprite"), "tint", tint)
	go.set(url(id, "label"), "text", text or "")
	go.set(url(id, "label"), "scale", vmath.vector3(1, 1, 1) * math.min(w, h) / (LABEL_PX * 2.2))
end

function M:paint_bays()
	local L = self.L
	for i, bay in ipairs(self.st.bays) do
		local p = L.bay_pos[i]
		local tint, text = palette.BAY, ""
		if bay.kind == "vip" then tint, text = palette.BAY_VIP, "VIP" end
		if bay.kind == "locked" then tint, text = palette.BAY_LOCKED, "+" end
		tile(self.bays[i], p.x, p.y, L.bay_unit * 1.15, L.bay_unit * 4.1, tint, text)
	end
end

-- Garage: rotated tile with the number of vehicles still inside
function M:paint_garages()
	local L = self.L
	for i, g in ipairs(self.st.garages) do
		local x, y = layout.lot_to_world(L, g.x, g.y)
		local count = #g.queue
		tile(self.garages[i], x, y, g.len * L.unit, g.wid * L.unit, count > 0 and palette.GARAGE or palette.BUTTON_OFF,
			count > 0 and tostring(count) or "")
		go.set(self.garages[i], "euler.z", math.deg(g.angle))
	end
end

function M:relayout(L)
	self.L = L
	tile(self.bg, L.lot_x + self.st.lot.w * L.unit * 0.5, L.lot_y + self.st.lot.h * L.unit * 0.5,
		self.st.lot.w * L.unit, self.st.lot.h * L.unit, palette.ASPHALT)
	self:paint_bays()
	self:paint_garages()
	for id, v in pairs(self.buses) do
		if self.st.buses[id].state ~= "gone" then place(self, id) end
	end
end

-- Tap -> bus id under the point (lot buses only)
function M:pick(x, y)
	local lx, ly = layout.world_to_lot(self.L, x, y)
	for _, id in ipairs(self.st.order) do
		local bus = self.st.buses[id]
		if bus.state == "lot" and geometry.contains(bus.box, lx, ly, 0.15) then return id end
	end
end

-- Tap -> bay index under the point
function M:pick_bay(x, y)
	local L = self.L
	for i, p in ipairs(L.bay_pos) do
		if math.abs(x - p.x) < L.bay_unit * 0.6 and math.abs(y - p.y) < L.bay_unit * 2 then return i end
	end
end

local function drive(self, id, time)
	local v = self.buses[id]
	local pos, deg, u = self:pose(id)
	pos.z = Z_BUS_MOVING
	go.animate(v.root, "position", go.PLAYBACK_ONCE_FORWARD, pos, go.EASING_INOUTQUAD, time, 0,
		function() local p = go.get_position(v.root); p.z = Z_BUS; go.set_position(p, v.root) end)
	local cur = go.get(v.body, "euler.z")
	local d = (deg - cur + 180) % 360 - 180 -- shortest turn
	go.animate(v.body, "euler.z", go.PLAYBACK_ONCE_FORWARD, cur + d, go.EASING_INOUTQUAD, time)
	go.animate(url(v.body, "body"), "scale", go.PLAYBACK_ONCE_FORWARD, body_scale(self.st.buses[id], u), go.EASING_INOUTQUAD, time)
	go.animate(url(v.body, "roof"), "scale", go.PLAYBACK_ONCE_FORWARD, vmath.vector3(u * 0.6 / 32, u * 0.6 / 32, 1), go.EASING_INOUTQUAD, time)
	go.set(url(v.root, "count"), "scale", vmath.vector3(u / 40, u / 40, 1))
end

function M:bus_world_pos(id)
	return go.get_position(self.buses[id].root)
end

-- Sim events -> animation. Returns nothing; unknown events are ignored.
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
			self:paint(bid)
			juice.pop(self.buses[bid].body, 1)
		end
	elseif t == "drive" or t == "teleport" then
		self:paint(id)
		drive(self, id, ev.time)
		audio.play(t == "drive" and "go" or "vip")
	elseif t == "blocked" then
		local bus = self.st.buses[id]
		juice.lurch(self.buses[id].root, bus.box.ux, bus.box.uy, math.min(ev.dist * self.L.unit, self.L.unit * 0.5))
		if ev.blocker and ev.blocker > 0 then juice.shake(self.buses[ev.blocker].root, self.L.unit * 0.08) end
		audio.play("honk")
	elseif t == "no_bay" then
		for _, b in ipairs(self.bays) do juice.shake(b, self.L.unit * 0.1) end
		audio.play("deny")
	elseif t == "board" then
		self:paint(id)
		juice.squash(self.buses[id].body, 1)
	elseif t == "depart" then
		local v = self.buses[id]
		local p = go.get_position(v.root)
		go.animate(v.root, "position.y", go.PLAYBACK_ONCE_FORWARD, p.y + self.L.h * 0.6, go.EASING_INQUAD, ev.time, 0,
			function() go.delete(v.root, true) end)
		self.buses[id] = nil
		audio.play("depart")
	elseif t == "bay_unlocked" then
		self:paint_bays()
		juice.pop(self.bays[ev.bay], 1)
	end
end

function M:delete()
	for _, v in pairs(self.buses) do go.delete(v.root, true) end
	for _, b in ipairs(self.bays) do go.delete(b) end
	for _, g in ipairs(self.garages) do go.delete(g) end
	go.delete(self.bg)
end

return M
