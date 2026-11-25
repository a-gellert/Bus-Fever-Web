-- 3D Lot and bays on screen: 3D buses, 3D garages/barriers, 3D park props, bay pier, sim events -> animations.
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
local camera3d = require("modules.view.camera3d")

local M = {}
M.__index = M

local BUS_FACTORIES = {
	s    = "/level#bus_s_factory",
	m    = "/level#bus_m_factory",
	l    = "/level#bus_l_factory",
	limo = "/level#bus_limo_factory",
	xl   = "/level#bus_xl_factory",
}
local GARAGE_FACTORY  = "/level#garage_factory"
local BARRIER_FACTORY = "/level#barrier_factory"
local BENCH_FACTORY   = "/level#bench_factory"
local BUSH_FACTORY    = "/level#bush_factory"
local FLOWERS_FACTORY = "/level#flowers_factory"

local IMG_ARROW = 32
local Z_BACK, Z_LOT, Z_BAY, Z_GROUND = -0.9, -0.5, 0.0, 0.0
local ROOF_Z = { s = 0.90, m = 0.90, l = 0.90, limo = 0.80, xl = 1.02 }

local function url(id, comp) return msg.url(nil, id, comp) end

function M.new(st, L)
	local self = setmetatable({
		st = st, L = L, buses = {}, bays = {}, bay_ads = {},
		garages = {}, garage_labels = {}, barriers = {},
		props = {}, park_paths = {},
		belt_tracks = {}, belt_ghosts = {}, movers = {}, labels = true,
	}, M)
	self.park_bg = tile.new(Z_BACK + 0.05, nil, "bg")
	self.lot_bg = tile.new(Z_BACK + 0.06, nil, "bg")
	self.lot_bg2 = tile.new(Z_BACK + 0.06, nil, "bg")
	self.lot_border = tile.new(Z_LOT - 0.01, nil, "mid")
	self.lot = tile.new(Z_LOT, nil, "mid")
	self.pier_rim = tile.new(Z_BAY - 0.03, nil, "mid")
	self.pier = tile.new(Z_BAY - 0.02, nil, "mid")
	self.road_rings = { tile.new(Z_LOT + 0.01, "ring"), tile.new(Z_LOT + 0.01, "ring") }
	for i in ipairs(st.bays) do
		self.bays[i] = tile.new(Z_BAY, "slot")
		self.bay_ads[i] = tile.new(Z_BAY + 0.01, "icon_ad")
	end
	for i in ipairs(st.garages) do
		self.garages[i] = factory.create(GARAGE_FACTORY, vmath.vector3(0, 0, Z_GROUND))
		self.garage_labels[i] = tile.new(30, nil, "overlay")
	end
	for i in ipairs(st.barriers) do
		self.barriers[i] = factory.create(BARRIER_FACTORY, vmath.vector3(0, 0, Z_GROUND))
	end
	for _, id in ipairs(st.order) do self:spawn(id) end
	self:relayout(L)
	-- level start: 3D vehicles pop in one after another
	for i, id in ipairs(st.order) do
		local root = self.buses[id].root
		go.set_scale(0.01, root)
		go.animate(root, "scale", go.PLAYBACK_ONCE_FORWARD, vmath.vector3(1, 1, 1), go.EASING_OUTBACK, 0.3, math.min(0.6, i * 0.02))
	end
	return self
end

local function shadow_scale(u)
	local k = u / 31.5
	return vmath.vector3(k, k, 1)
end

function M:spawn(id)
	local bus = self.st.buses[id]
	local ids = collectionfactory.create(BUS_FACTORIES[bus.size] or BUS_FACTORIES.m, vmath.vector3(0, 0, Z_GROUND))
	local v = {
		root = ids[hash("/root")],
		body = ids[hash("/body")],
		mesh = ids[hash("/mesh")],
		top = ids[hash("/top")],
		badge = ids[hash("/badge")],
		shadow = ids[hash("/shadow")],
	}
	self.buses[id] = v
	go.set(url(v.shadow, "sprite"), "tint", palette.SHADOW)
	sprite.play_flipbook(url(v.shadow, "sprite"), "shadow_" .. bus.size)
	sprite.play_flipbook(url(v.top, "roof"), bus.turning and "turn" or "arrow")
	self:paint(id)
	return v
end

function M:paint(id)
	local bus, v = self.st.buses[id], self.buses[id]
	if not v then return end
	local tint = bus.hidden and palette.HIDDEN or palette.of(bus.color)
	go.set(url(v.mesh, "model"), "tint", tint)
	local roof = bus.hidden and vmath.vector4(1, 1, 1, 0) or palette.WHITE
	go.set(url(v.top, "roof"), "tint", roof)
	local text = ""
	if bus.state ~= "lot" and bus.left > 0 then text = tostring(bus.left) end
	go.set(url(v.badge, "count"), "text", self.labels and text or "")
end

-- Where a bus stands for its current state (pixels, degrees, lot unit used for its size)
function M:pose(id)
	local bus, L = self.st.buses[id], self.L
	if bus.state == "lot" then
		local x, y = layout.lot_to_world(L, bus.box.x, bus.box.y)
		return vmath.vector3(x, y, Z_GROUND), math.deg(bus.box.angle), L.unit
	end
	local p = L.bay_pos[bus.bay]
	return vmath.vector3(p.x, p.y, Z_GROUND), 90, L.bay_unit
end

local function set_size(self, id, u)
	local v, bus = self.buses[id], self.st.buses[id]
	go.set_scale(vmath.vector3(u, u, u), v.mesh)
	local bs = shadow_scale(u)
	go.set(url(v.shadow, "sprite"), "scale", bs)
	go.set_position(vmath.vector3(u * 0.08, -u * 0.12, 0.02), v.shadow)
	local roof_h = (ROOF_Z[bus.size] or 0.90) * u
	go.set_position(vmath.vector3(0, 0, roof_h + 1), v.top)
	local a = u * 0.56 / IMG_ARROW
	go.cancel_animations(url(v.top, "roof"), "scale")
	go.set(url(v.top, "roof"), "scale", vmath.vector3(a, a, 1))
	v.roof_scale, v.free = a, nil -- mark_free re-applies the pulse
	go.set_position(vmath.vector3(0, 0, roof_h + u * 0.35), v.badge)
	local text = bus.hidden and u * 0.95 or u * 0.58
	local s = math.max(tile.MIN_TEXT, text) / 40
	go.set(url(v.badge, "count"), "scale", vmath.vector3(s, s, 1))
end

local function place(self, id)
	local v = self.buses[id]
	self.movers[id] = nil
	go.cancel_animations(v.mesh, "scale")
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
	local ph = L.bay_unit * (L.max_bus_len + 0.55)
	local px = L.portrait and (L.w * 0.5) or (L.bays.x + L.bays.w * 0.5)
	local pw = L.portrait and (L.w * 2.2) or (L.slot_w * n + L.slot_w * 0.3)
	local py = L.bays.y + L.bays.h * 0.5
	tile.set(self.pier_rim, { x = px, y = py, w = pw + 8, h = ph + 10, tint = palette.PIER_RIM })
	tile.set(self.pier, { x = px, y = py, w = pw, h = ph, tint = palette.PANEL })
	for i, bay in ipairs(self.st.bays) do
		local p = L.bay_pos[i]
		local anim, tint, text = "slot", palette.WHITE, ""
		if bay.kind == "vip" then
			anim, text = "slot_vip", "VIP"
		elseif bay.kind == "locked" then
			anim, text = "slot_locked", ""
		end
		local w, h = math.max(L.slot_w * 0.8, 20), L.bay_unit * (L.max_bus_len + 0.15)
		tile.set(self.bays[i], { x = p.x, y = p.y, w = w, h = h, anim = anim, tint = tint,
			text = self.labels and (bay.kind == "vip" and text or "") or "",
			text_px = math.min(w * 0.44, h * 0.28),
			text_color = palette.GOLD })
		local ad = self.bay_ads[i]
		local s = math.min(w * 0.55, h * 0.22)
		tile.set(ad, { x = p.x, y = p.y - h * 0.30, w = s, h = s, tint = palette.WHITE })
		tile.show(ad, bay.kind == "locked" and self.labels)
	end
end

-- Garage: 3D building with floating count badge
function M:paint_garages()
	local L = self.L
	for i, g in ipairs(self.st.garages) do
		local x, y = layout.lot_to_world(L, g.x, g.y)
		local gid = self.garages[i]
		local count = #g.queue
		go.set_position(vmath.vector3(x, y, 0), gid)
		go.set(gid, "euler.z", math.deg(g.angle))
		go.set_scale(vmath.vector3(g.len * L.unit / 1.50, g.wid * L.unit / 1.05, L.unit), gid)
		go.set(url(gid, "model"), "tint", count > 0 and palette.WHITE or palette.BUTTON_OFF)
		tile.set(self.garage_labels[i], {
			x = x, y = y, z = L.unit * 1.18,
			text = (self.labels and count > 0) and tostring(count) or "",
			text_px = L.unit * 0.72, text_color = palette.CREAM,
		})
	end
end

-- Static barriers: 3D striped hazard roadblocks
function M:paint_barriers()
	local L = self.L
	for i, b in ipairs(self.st.barriers) do
		local x, y = layout.lot_to_world(L, b.x, b.y)
		local bid = self.barriers[i]
		go.set_position(vmath.vector3(x, y, 0), bid)
		go.set(bid, "euler.z", math.deg(b.angle))
		go.set_scale(vmath.vector3(b.len * L.unit / 1.9, b.wid * L.unit / 0.54, L.unit), bid)
	end
end

-- Park decoration: beige footpaths + 3D benches, bushes & flowers along the outer grass pockets
local function clear_park_props(self)
	for _, id in ipairs(self.props) do
		if go.exists(id) then go.delete(id) end
	end
	for _, t in ipairs(self.park_paths) do tile.delete(t) end
	self.props, self.park_paths = {}, {}
end

local function spawn_prop(self, fact, x, y, scale, rot_deg)
	local id = factory.create(fact, vmath.vector3(x, y, 0))
	go.set_scale(vmath.vector3(scale, scale, scale), id)
	go.set(id, "euler.z", rot_deg or 0)
	self.props[#self.props + 1] = id
end

local function paint_park_props(self)
	clear_park_props(self)
	local L = self.L
	local lp = L.loop
	local s = math.max(20, math.min(lp.w, lp.h) * 0.17)
	if L.portrait then
		-- Side garden paths leading out from left/right grass pockets like Bus Fever Party
		for _, side in ipairs({ -1, 1 }) do
			local px = side < 0 and (lp.x + lp.w * 0.04) or (lp.x + lp.w * 0.96)
			local py = lp.y + lp.h * 0.25
			local pt = tile.new(Z_BACK + 0.10, nil, "mid")
			tile.set(pt, { x = px, y = py, w = lp.w * 0.20, h = s * 0.72, tint = palette.PARK_PATH, rot = side * 12 })
			self.park_paths[#self.park_paths + 1] = pt
			spawn_prop(self, BENCH_FACTORY, px, py + s * 0.55, s * 0.95, side * -12)
			spawn_prop(self, BUSH_FACTORY, px - side * s * 0.35, py + s * 1.35, s * 1.15, side * 25)
			spawn_prop(self, FLOWERS_FACTORY, px + side * s * 0.18, py - s * 0.50, s * 1.25, 0)
		end
	else
		local rx = lp.x + lp.w * 0.10
		local lx = lp.x + lp.w * 0.90
		local py = lp.y + lp.h * 0.12
		spawn_prop(self, BUSH_FACTORY, rx, py, s * 1.0, 15)
		spawn_prop(self, BENCH_FACTORY, lx, py + s * 0.35, s * 0.85, -15)
		spawn_prop(self, FLOWERS_FACTORY, rx + s * 0.9, py - s * 0.2, s * 1.1, 0)
	end
end

-- Belt garages: a visible conveyor with queued sprites behind the gate
function M:paint_belts()
	local L = self.L
	for _, t in ipairs(self.belt_tracks) do tile.delete(t) end
	for _, list in pairs(self.belt_ghosts) do
		for _, t in ipairs(list) do tile.delete(t) end
	end
	self.belt_tracks, self.belt_ghosts = {}, {}
	for gi, g in ipairs(self.st.garages) do
		if g.belt and #g.queue > 0 then
			local gx, gy = layout.lot_to_world(L, g.x, g.y)
			local dx, dy = -math.cos(g.angle), -math.sin(g.angle)
			local d = 0
			local ghosts = {}
			for _, spec in ipairs(g.queue) do
				local len = config.SIZES[spec.size].len
				local dist = g.len * 0.5 + 0.45 + d + len * 0.5
				local t = tile.new(0.03, "bus_" .. spec.size)
				tile.set(t, { x = gx + dx * dist * L.unit, y = gy + dy * dist * L.unit,
					w = len * L.unit, h = L.unit, tint = palette.of(spec.color), rot = math.deg(g.angle) })
				ghosts[#ghosts + 1] = t
				d = d + len + 0.3
			end
			local track_len = 0.6 + d
			local mid = g.len * 0.5 + track_len * 0.5
			local track = tile.new(0.01, "belt", "mid")
			tile.set(track, { x = gx + dx * mid * L.unit, y = gy + dy * mid * L.unit,
				w = track_len * L.unit, h = L.unit * 0.95, tint = palette.BELT, rot = math.deg(g.angle) })
			self.belt_tracks[#self.belt_tracks + 1] = track
			self.belt_ghosts[gi] = ghosts
		end
	end
end

function M:relayout(L)
	self.L = L
	local pier_y = L.bays.y + L.bays.h * 0.5
	if L.portrait then
		tile.set(self.park_bg, { x = L.w * 0.5, y = pier_y + L.h * 0.75, w = L.w * 2.6, h = L.h * 1.5, tint = palette.PARK_GRASS })
		tile.set(self.lot_bg, { x = L.w * 0.5, y = pier_y - L.h * 0.75, w = L.w * 2.6, h = L.h * 1.5, tint = palette.hex("d2dce8") })
		tile.show(self.lot_bg2, false)
	else
		local split_x = (L.lot.x + L.lot.w + L.loop.x) * 0.5
		local left_w = L.w * 1.6
		local right_w = L.w * 1.6
		tile.show(self.lot_bg2, false)
		tile.set(self.lot_bg, { x = split_x - left_w * 0.5, y = L.h * 0.5, w = left_w, h = L.h * 2.6, tint = palette.hex("d2dce8") })
		tile.set(self.park_bg, { x = split_x + right_w * 0.5, y = L.h * 0.5, w = right_w, h = L.h * 2.6, tint = palette.PARK_GRASS })
	end
	local lw, lh = self.st.lot.w * L.unit, self.st.lot.h * L.unit
	local cx, cy = L.lot_x + lw * 0.5, L.lot_y + lh * 0.5
	local pad = L.unit * 0.35
	tile.set(self.lot_border, { x = cx, y = cy, w = lw + pad * 2 + 8, h = lh + pad * 2 + 8, tint = palette.LOT_BORDER })
	tile.set(self.lot, { x = cx, y = cy, w = lw + pad * 2, h = lh + pad * 2, tint = palette.ASPHALT })
	local min_dim = math.min(lw, lh)
	tile.set(self.road_rings[1], { x = cx, y = cy, w = min_dim * 0.48, h = min_dim * 0.48, tint = vmath.vector4(1, 1, 1, 0.45) })
	tile.set(self.road_rings[2], { x = cx, y = cy, w = min_dim * 0.82, h = min_dim * 0.82, tint = vmath.vector4(1, 1, 1, 0.45) })
	self:paint_bays()
	self:paint_garages()
	self:paint_barriers()
	self:paint_belts()
	paint_park_props(self)
	for id in pairs(self.buses) do
		if self.st.buses[id].state ~= "gone" then place(self, id) end
	end
end

-- Vehicles that can leave right now: their arrow disc breathes on the 3D roof
function M:mark_free()
	local free_now = {}
	for _, id in ipairs(rules.free_buses(self.st)) do free_now[id] = true end
	for id, v in pairs(self.buses) do
		local bus = self.st.buses[id]
		local free = bus.state == "lot" and free_now[id] or false
		if free ~= v.free and v.roof_scale then
			v.free = free
			local roof = url(v.top, "roof")
			local a = v.roof_scale
			go.cancel_animations(roof, "scale")
			go.set(roof, "scale", vmath.vector3(a, a, 1))
			if free then
				go.animate(roof, "scale", go.PLAYBACK_LOOP_PINGPONG, vmath.vector3(a * 1.20, a * 1.20, 1), go.EASING_INOUTSINE, 0.45)
			end
		end
	end
end

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

function M:set_labels(visible)
	self.labels = visible
	for id in pairs(self.buses) do self:paint(id) end
	self:paint_bays()
	self:paint_garages()
end

-- Screen tap -> raycast to bus mid-height in 3D space -> lot bus id
function M:pick(sx, sy)
	local L = self.L
	local wx, wy = camera3d.screen_to_plane(L.w, L.h, sx, sy, L.unit * 0.42)
	local lx, ly = layout.world_to_lot(L, wx, wy)
	local best, best_d
	for _, id in ipairs(self.st.order) do
		local bus = self.st.buses[id]
		if bus.state == "lot" and geometry.contains(bus.box, lx, ly, 0.28) then
			local d = (bus.box.x - lx) ^ 2 + (bus.box.y - ly) ^ 2
			if not best_d or d < best_d then best, best_d = id, d end
		end
	end
	return best
end

-- Screen tap -> raycast to ground plane -> bay index
function M:pick_bay(sx, sy)
	local L = self.L
	local wx, wy = camera3d.screen_to_plane(L.w, L.h, sx, sy, 0)
	for i, p in ipairs(L.bay_pos) do
		if math.abs(wx - p.x) < L.slot_w * 0.5 and math.abs(wy - p.y) < L.bays.h * 0.5 then return i end
	end
end

local SPEED = 22
local MIN_TIME, MAX_TIME = 0.5, 1.35

function M:route(id, bay)
	local bus, L = self.st.buses[id], self.L
	local x, y = layout.lot_to_world(L, bus.box.x, bus.box.y)
	local x1, y1 = layout.lot_to_world(L, self.st.lot.w, self.st.lot.h)
	local p = L.bay_pos[bay]
	return route.build({ x = x, y = y, ux = bus.box.ux, uy = bus.box.uy },
		{ x0 = L.lot_x, y0 = L.lot_y, x1 = x1, y1 = y1 },
		p, L.bay_unit * 3.2, L.unit * 0.8, L.unit * 0.7)
end

function M:travel_time(id, bay)
	local len = self:route(id, bay).length / self.L.unit
	return math.min(MAX_TIME, math.max(MIN_TIME, len / SPEED))
end

local function smooth(k) return k * k * (3 - 2 * k) end
local function accelerate(k) return k * k end

local function puff(self, x, y, size)
	local t = tile.new(self.L.unit * 0.22, "disc", "overlay")
	tile.set(t, { x = x, y = y, w = size, h = size, tint = vmath.vector4(0.92, 0.96, 1, 0.45) })
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
	juice.squash(v.body, 1)
end

local function drive(self, id, time)
	local bus = self.st.buses[id]
	start_mover(self, id, { path = self:route(id, bus.bay), time = time, ease = smooth,
		unit_from = self.L.unit, unit_to = self.L.bay_unit })
end

local function depart(self, id, time)
	local L = self.L
	local bus = self.st.buses[id]
	local v = self.buses[id]
	local p = L.bay_pos[bus.bay]
	local bu = L.bay_unit
	local side = (not L.portrait) and 1 or (p.x < L.w * 0.5 and -1 or 1)
	local road_y = math.min(p.y - L.unit * 0.8, L.bays.y - L.unit * 0.5)
	set_size(self, id, bu)
	start_mover(self, id, { kind = "depart", v = v, bus = bus, side = side,
		p0 = { x = p.x, y = p.y }, p1 = { x = p.x, y = road_y },
		exit_x = side > 0 and (L.w + L.unit * 8) or (-L.unit * 8), p1_y = road_y,
		time = math.max(0.7, time or 0.64), t = 0, phase = 1, leaving = true })
	go.cancel_animations(v.root, "position")
	go.set_position(vmath.vector3(p.x, p.y, Z_GROUND), v.root)
	go.set(v.body, "euler.z", 90)
	go.set(v.shadow, "euler.z", 90)
end

local function teleport(self, id, time)
	local v = self.buses[id]
	go.cancel_animations(v.root, "scale")
	go.animate(v.root, "scale", go.PLAYBACK_ONCE_FORWARD, vmath.vector3(0.01, 0.01, 0.01), go.EASING_INBACK, time * 0.5, 0, function()
		if self.buses[id] then
			place(self, id)
			juice.pop(v.root, 1)
		end
	end)
end

local function update_depart(self, m, dt)
	m.t = m.t + dt
	local v = m.v
	local bu = self.L.bay_unit
	if m.phase == 1 then
		local t = m.time * 0.34
		local k = math.min(1, m.t / t)
		local e = smooth(k)
		local x = m.p0.x + (m.p1.x - m.p0.x) * e
		local y = m.p0.y + (m.p1.y - m.p0.y) * e
		go.set_position(vmath.vector3(x, y, Z_GROUND), v.root)
		m.puff_t = (m.puff_t or 0) - dt
		if m.puff_t <= 0 then
			m.puff_t = 0.07
			puff(self, x, y - m.half * bu, bu * 0.25)
		end
		if k >= 1 then
			m.phase, m.t = 2, 0
			m.target_deg = m.side > 0 and 0 or 180
		end
	elseif m.phase == 2 then
		local t = m.time * 0.18
		local k = math.min(1, m.t / t)
		local e = smooth(k)
		local deg = 90 + (m.target_deg - 90) * e
		go.set(v.body, "euler.z", deg)
		go.set(v.shadow, "euler.z", deg)
		if k >= 1 then
			m.phase, m.t = 3, 0
			go.set(v.body, "euler.z", m.target_deg)
			go.set(v.shadow, "euler.z", m.target_deg)
		end
	else
		local t = m.time * 0.48
		local k = math.min(1, m.t / t)
		local e = accelerate(k)
		local x = m.p1.x + (m.exit_x - m.p1.x) * e
		go.set_position(vmath.vector3(x, m.p1_y, Z_GROUND), v.root)
		m.puff_t = (m.puff_t or 0) - dt
		if m.puff_t <= 0 and k < 0.9 then
			m.puff_t = 0.07
			local back = m.half * bu + bu * 0.15
			puff(self, x - math.cos(math.rad(m.target_deg)) * back,
				m.p1_y - math.sin(math.rad(m.target_deg)) * back, bu * 0.25)
		end
		if k >= 1 then
			self.movers[m.bus.id] = nil
			go.delete(v.root, true)
		end
	end
end

function M:update(dt)
	for id, m in pairs(self.movers) do
		if m.kind == "depart" then
			update_depart(self, m, dt)
		else
			local v = m.v
			m.t = m.t + dt
			local k = math.min(1, m.t / m.time)
			local x, y, a = m.path:at(m.ease(k) * m.path.length)
			go.set_position(vmath.vector3(x, y, Z_GROUND), v.root)
			local deg = math.deg(a)
			go.set(v.body, "euler.z", deg)
			go.set(v.shadow, "euler.z", deg)
			local g = math.max(0, (k - 0.6) / 0.4)
			local u = m.unit_from + (m.unit_to - m.unit_from) * g
			local w = math.sin(m.t * 26) * 0.04 * (1 - k)
			go.set_scale(vmath.vector3(u * (1 + w), u * (1 - w), u), v.mesh)
			go.set(url(v.shadow, "sprite"), "scale", shadow_scale(u))
			local roof_h = (ROOF_Z[self.st.buses[id].size] or 0.90) * u
			go.set_position(vmath.vector3(0, 0, roof_h + 1), v.top)
			go.set_position(vmath.vector3(0, 0, roof_h + u * 0.35), v.badge)
			local arr_s = u * 0.56 / IMG_ARROW
			go.set(url(v.top, "roof"), "scale", vmath.vector3(arr_s, arr_s, 1))
			m.puff_t = m.puff_t - dt
			if m.puff_t <= 0 and k < 0.92 then
				m.puff_t = 0.06
				local back = m.half * u + u * 0.15
				puff(self, x - math.cos(a) * back, y - math.sin(a) * back, u * 0.25)
			end
			if k >= 1 then
				self.movers[id] = nil
				if m.leaving then
					go.delete(v.root, true)
				elseif self.buses[id] then
					place(self, id)
					juice.squash(v.body, 1)
					local p = go.get_position(v.root)
					juice.confetti(p.x, p.y, 7, self.L.unit * 0.32, { palette.of(self.st.buses[id].color), palette.GOLD },
						function() return tile.new(self.L.bay_unit * 0.9, "star", "overlay").id end, 96)
				end
			end
		end
	end
end

function M:bus_world_pos(id)
	local v = self.buses[id]
	return v and go.get_position(v.root) or vmath.vector3(self.L.w * 0.5, self.L.h * 0.5, 0)
end

-- Passenger reaches the door: bright flash on 3D bus + expanding ring at the stop
function M:board_impact(id, color)
	local v = self.buses[id]
	if not v then return end
	juice.flash(url(v.mesh, "model"), palette.of(color))
	local p = go.get_position(v.root)
	local t = tile.new(self.L.bay_unit * 0.5, "ring", "overlay")
	local s = self.L.unit * 1.15
	tile.set(t, { x = p.x, y = p.y, w = s, h = s, tint = palette.of(color) })
	go.set_scale(0.25, t.id)
	go.animate(t.id, "scale", go.PLAYBACK_ONCE_FORWARD, vmath.vector3(1.8, 1.8, 1), go.EASING_OUTQUAD, 0.24)
	go.animate(t.sprite, "tint.w", go.PLAYBACK_ONCE_FORWARD, 0, go.EASING_INQUAD, 0.24, 0, function() tile.delete(t) end)
end

function M:on_event(ev)
	local id = ev.bus
	local t = ev.type
	if t == "spawn" then
		self:spawn(id)
		place(self, id)
		juice.pop(self.buses[id].root, 1)
		self:paint_garages()
		self:paint_belts()
	elseif t == "reveal" or t == "recolor" then
		for _, bid in ipairs(ev.buses or { id }) do
			if self.buses[bid] then
				self:paint(bid)
				set_size(self, bid, self.L.unit)
				juice.pop(self.buses[bid].body, 1)
			end
		end
	elseif t == "turn" then
		local v = self.buses[id]
		if v then
			local deg = math.deg(ev.angle)
			go.cancel_animations(v.body, "euler.z")
			go.cancel_animations(v.shadow, "euler.z")
			go.animate(v.body, "euler.z", go.PLAYBACK_ONCE_FORWARD, deg, go.EASING_OUTQUAD, 0.16)
			go.animate(v.shadow, "euler.z", go.PLAYBACK_ONCE_FORWARD, deg, go.EASING_OUTQUAD, 0.16)
			juice.pop(url(v.top, "roof"), v.roof_scale or 1)
			audio.play("tap", 0.7, 0.5)
		end
	elseif t == "drive" or t == "teleport" then
		self:paint(id)
		if t == "drive" then drive(self, id, ev.time) else teleport(self, id, ev.time) end
		audio.play(t == "drive" and "go" or "vip")
	elseif t == "blocked" then
		local bus = self.st.buses[id]
		juice.lurch(self.buses[id].root, bus.box.ux, bus.box.uy, math.min(ev.dist * self.L.unit, self.L.unit * 0.5))
		juice.shake_screen(3)
		local blocker = ev.blocker and ev.blocker > 0 and self.buses[ev.blocker]
		if blocker then
			juice.shake(blocker.root, self.L.unit * 0.12)
			juice.flash(url(blocker.mesh, "model"), palette.of(self.st.buses[ev.blocker].color))
		end
		audio.play("honk")
	elseif t == "no_bay" then
		for _, b in ipairs(self.bays) do juice.shake(b.id, self.L.unit * 0.1) end
		juice.shake_screen(4)
		audio.play("deny")
	elseif t == "board" then
		self:paint(id)
		juice.squash(self.buses[id].body, 1)
	elseif t == "full" then
		juice.flash(url(self.buses[id].mesh, "model"), palette.of(self.st.buses[id].color))
	elseif t == "depart" then
		depart(self, id, ev.time * 2.0)
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
		if m.leaving then go.delete(m.v.root, true) end
	end
	for _, v in pairs(self.buses) do go.delete(v.root, true) end
	self.buses, self.movers = {}, {}
	for i in ipairs(self.bays) do tile.delete(self.bays[i]); tile.delete(self.bay_ads[i]) end
	for _, g in ipairs(self.garages) do if go.exists(g) then go.delete(g) end end
	for _, gl in ipairs(self.garage_labels) do tile.delete(gl) end
	for _, b in ipairs(self.barriers) do if go.exists(b) then go.delete(b) end end
	clear_park_props(self)
	for _, t in ipairs(self.belt_tracks) do tile.delete(t) end
	for _, list in pairs(self.belt_ghosts) do
		for _, t in ipairs(list) do tile.delete(t) end
	end
	for _, t in ipairs({ self.park_bg, self.lot_bg, self.lot_bg2, self.lot_border, self.lot, self.pier, self.pier_rim, self.road_rings[1], self.road_rings[2] }) do
		tile.delete(t)
	end
end

return M
