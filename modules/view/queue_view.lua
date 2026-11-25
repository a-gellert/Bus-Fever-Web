-- 3D Passenger crowd on the loop: a paved sidewalk ribbon with raised stone curb, a pool of 3D
-- jelly-bean figures 3 abreast coloured from the queue, and a "N LEFT" counter. On boarding the crowd slides forward.
local path_loop = require("modules.view.path_loop")
local palette = require("modules.view.palette")
local tile = require("modules.view.tile")

local M = {}
M.__index = M

local FACTORY = "/level#passenger_factory"
local Z, Z_TRACK = 0.0, -0.02

function M.new(st, L, shape)
	local self = setmetatable({ st = st, shape = shape or "u", pool = {}, tints = {}, track = {}, offset = 0 }, M)
	self.counter = tile.new(24, nil, "overlay")
	self.stop = tile.new(18, "stop", "overlay")
	self.time = 0
	self:relayout(L)
	return self
end

local function build_track(self)
	for _, t in ipairs(self.track) do tile.delete(t) end
	self.track = {}
	local width = self.width
	local step = width * 0.45
	-- raised light-grey stone curb under the crisp paved walkway
	for layer = 1, 2 do
		local pad = layer == 1 and 8 or 0
		local layer_tag = layer == 1 and "mid" or "ground"
		local d = 0
		while d < self.path.length do
			local x, y, a = self.path:at(d)
			local t = tile.new(Z_TRACK + layer * 0.002, nil, layer_tag)
			tile.set(t, { x = x, y = y, w = step * 2.3 + pad, h = width + pad,
				tint = layer == 1 and palette.TRACK_EDGE or palette.TRACK, rot = math.deg(a) })
			self.track[#self.track + 1] = t
			d = d + step
		end
	end
end

function M:relayout(L)
	self.L = L
	self.path = path_loop.in_rect(self.shape, L.loop)
	self.lanes = 3
	local max_ribbon = L.loop.h * 0.28
	self.size = math.max(12, math.min(L.loop.w * 0.044, max_ribbon / (self.lanes + 0.6)))
	self.width = self.size * (self.lanes + 0.6)
	self.row_step = self.size * 1.25
	local rows = math.floor(self.path.length / self.row_step)
	local want = rows * self.lanes
	while #self.pool < want do
		self.pool[#self.pool + 1] = factory.create(FACTORY, vmath.vector3(0, 0, Z))
	end
	while #self.pool > want do go.delete(table.remove(self.pool)) end
	local s = self.size * 1.30
	for _, id in ipairs(self.pool) do
		go.set_scale(vmath.vector3(s, s, s), id)
	end
	self.tints = {}
	build_track(self)
	local c = L.loop
	local cp = path_loop.COUNTER_POS[self.shape] or { 0.5, 0.52 }
	tile.set(self.counter, { x = c.x + c.w * cp[1], y = c.y + c.h * cp[2], z = self.size * 1.8, text = "",
		text_px = math.max(14, c.h * (L.w <= 400 and 0.1 or 0.12)), text_color = palette.CREAM })
	self.parked = {}
	local hx, hy, ha = self.path:at(0)
	local nx, ny = -math.sin(ha), math.cos(ha)
	local ss = math.max(32, self.size * 3.0)
	local stop_x = hx + nx * self.width * 0.72
	local stop_y = hy + ny * self.width * 0.72
	stop_x = math.max(c.x + ss * 0.5, math.min(c.x + c.w - ss * 0.5, stop_x))
	stop_y = math.max(c.y + ss * 0.5, math.min(c.y + c.h - ss * 0.5, stop_y))
	tile.set(self.stop, { x = stop_x, y = stop_y, z = self.size * 1.3, w = ss * 0.75, h = ss, tint = palette.WHITE })
	self.counter_value = nil
end

-- i-th passenger from the head -> x, y, angle, on_path
function M:slot_pos(i)
	local row = math.floor(i / self.lanes)
	local lane = i % self.lanes - (self.lanes - 1) * 0.5
	local x, y, a, on = self.path:at(row * self.row_step + self.offset * self.row_step / self.lanes)
	local nx, ny = -math.sin(a), math.cos(a)
	return x + nx * lane * self.size * 0.88, y + ny * lane * self.size * 0.88, a, on
end

function M:on_board()
	self.offset = self.offset + 1
end

function M:set_counter_visible(v)
	self.counter_hidden = not v
	self.counter_value = nil
end

function M:update(dt)
	self.offset = self.offset * math.exp(-dt * 15)
	self.time = self.time + dt
	local bob = self.size * 0.18
	if self.offset < 0.01 then self.offset = 0 end
	local st = self.st

	local px, py, pa, p_vis = {}, {}, {}, {}
	for i in ipairs(self.pool) do
		local c = st.queue[st.head + i - 1]
		local x, y, a, on = self:slot_pos(i - 1)
		local visible = c ~= nil and on
		p_vis[i] = visible
		if visible then
			px[i], py[i], pa[i] = x, y, a
		end
	end

	-- Contact relaxation pass: guarantees zero overlapping passengers on any curve
	local min_d = self.size * 0.88
	local min_d2 = min_d * min_d
	for _ = 1, 3 do
		for i = 1, #self.pool do
			if p_vis[i] then
				local max_j = math.min(#self.pool, i + 8)
				for j = i + 1, max_j do
					if p_vis[j] then
						local dx, dy = px[j] - px[i], py[j] - py[i]
						local d2 = dx * dx + dy * dy
						if d2 < min_d2 and d2 > 0.001 then
							local d = math.sqrt(d2)
							local push = (min_d - d) * 0.5 / d
							px[i], py[i] = px[i] - dx * push, py[i] - dy * push
							px[j], py[j] = px[j] + dx * push, py[j] + dy * push
						end
					end
				end
			end
		end
	end

	local s = self.size * 1.30
	for i, id in ipairs(self.pool) do
		local visible = p_vis[i]
		local c = st.queue[st.head + i - 1]
		if visible then
			self.parked[i] = nil
			local near = i <= self.lanes * 2 and 1.3 or 1
			local hop = math.abs(math.sin(self.time * 6 + i * 0.7)) * bob * near
			go.set_position(vmath.vector3(px[i], py[i], hop), id)
			go.set(id, "euler.z", math.deg(pa[i]))
			go.set_scale(vmath.vector3(s, s, s), id)
			if self.tints[i] ~= c then
				self.tints[i] = c
				go.set(msg.url(nil, id, "model"), "tint", palette.of(c))
			end
		elseif not self.parked[i] then
			self.parked[i] = true
			go.set_position(vmath.vector3(-9999, -9999, -500), id)
		end
	end

	local left = #st.queue - st.head + 1
	local value = self.counter_hidden and -1 or left
	if value ~= self.counter_value then
		self.counter_value = value
		go.set(self.counter.label, "text", (value > 0) and (left .. " LEFT") or "")
	end
end

-- World position of the passenger at the head (for the 3D jump into a bus)
function M:head_pos()
	local x, y = self:slot_pos(0)
	return vmath.vector3(x, y, self.size * 0.35)
end

function M:delete()
	for _, id in ipairs(self.pool) do go.delete(id) end
	for _, t in ipairs(self.track) do tile.delete(t) end
	tile.delete(self.counter)
	tile.delete(self.stop)
	self.pool, self.track = {}, {}
end

return M
