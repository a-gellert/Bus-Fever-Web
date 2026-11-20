-- Passenger crowd on the loop: a road ribbon, a fixed pool of sprites 2-3 abreast coloured from
-- the queue, and a "N left" counter in the middle. On every boarding the crowd slides forward.
local path_loop = require("modules.view.path_loop")
local palette = require("modules.view.palette")
local tile = require("modules.view.tile")

local M = {}
M.__index = M

local FACTORY = "/level#passenger_factory"
local IMG = 32            -- dot.png
local Z, Z_TRACK = 0.3, 0.0

function M.new(st, L, shape)
	local self = setmetatable({ st = st, shape = shape or "u", pool = {}, tints = {}, track = {}, offset = 0 }, M)
	self.counter = tile.new(Z_TRACK + 0.01)
	self:relayout(L)
	return self
end

local function build_track(self)
	for _, t in ipairs(self.track) do tile.delete(t) end
	self.track = {}
	local width = self.size * (self.lanes + 0.6)
	local step = width * 0.5
	-- two layers: a lighter edge under the road so it reads on the navy backdrop
	for layer = 1, 2 do
		local pad = layer == 1 and 4 or 0
		local d = 0
		while d < self.path.length do
			local x, y, a = self.path:at(d)
			local t = tile.new(Z_TRACK + layer * 0.001)
			tile.set(t, { x = x, y = y, w = step * 2.2 + pad, h = width + pad,
				tint = layer == 1 and palette.TRACK_EDGE or palette.TRACK, rot = math.deg(a) })
			self.track[#self.track + 1] = t
			d = d + step
		end
	end
end

function M:relayout(L)
	self.L = L
	self.path = path_loop.in_rect(self.shape, L.loop)
	self.lanes = L.loop.w < 420 and 2 or 3
	self.size = math.max(9, math.min(L.loop.w, L.loop.h) * 0.058) -- passenger diameter, px
	self.row_step = self.size * 1.12
	local rows = math.floor(self.path.length / self.row_step)
	local want = rows * self.lanes
	while #self.pool < want do
		self.pool[#self.pool + 1] = factory.create(FACTORY, vmath.vector3(0, 0, Z))
	end
	while #self.pool > want do go.delete(table.remove(self.pool)) end
	for _, id in ipairs(self.pool) do
		go.set(msg.url(nil, id, "sprite"), "scale", vmath.vector3(self.size / IMG, self.size / IMG, 1))
	end
	self.tints = {}
	build_track(self)
	local c = L.loop
	tile.set(self.counter, { x = c.x + c.w * 0.5, y = c.y + c.h * 0.52, text = "", text_px = math.max(14, c.h * (L.w <= 400 and 0.1 or 0.12)),
		text_color = palette.CREAM })
	self.counter_value = nil
end

-- i-th passenger from the head -> position (fractional offset for the slide)
function M:slot_pos(i)
	local row = math.floor(i / self.lanes)
	local lane = i % self.lanes - (self.lanes - 1) * 0.5
	local x, y, a, on = self.path:at(row * self.row_step + self.offset * self.row_step / self.lanes)
	local nx, ny = -math.sin(a), math.cos(a)
	return x + nx * lane * self.size * 1.02, y + ny * lane * self.size * 1.02, on
end

function M:on_board()
	self.offset = self.offset + 1
end

function M:set_counter_visible(v)
	self.counter_hidden = not v
	self.counter_value = nil
end

function M:update(dt)
	self.offset = self.offset * math.exp(-dt * 18)
	if self.offset < 0.01 then self.offset = 0 end
	local st = self.st
	for i, id in ipairs(self.pool) do
		local c = st.queue[st.head + i - 1]
		local x, y, on = self:slot_pos(i - 1)
		local visible = c ~= nil and on
		go.set_position(vmath.vector3(x, y, visible and Z or -2), id) -- z -2: outside the projection
		if visible and self.tints[i] ~= c then
			self.tints[i] = c
			go.set(msg.url(nil, id, "sprite"), "tint", palette.of(c))
		end
	end
	local left = #st.queue - st.head + 1
	local value = self.counter_hidden and -1 or left
	if value ~= self.counter_value then
		self.counter_value = value
		go.set(self.counter.label, "text", (value > 0) and (left .. " LEFT") or "")
	end
end

-- World position of the passenger at the head (for the jump into a bus)
function M:head_pos()
	local x, y = self:slot_pos(0)
	return vmath.vector3(x, y, Z + 0.1)
end

function M:delete()
	for _, id in ipairs(self.pool) do go.delete(id) end
	for _, t in ipairs(self.track) do tile.delete(t) end
	tile.delete(self.counter)
	self.pool, self.track = {}, {}
end

return M
