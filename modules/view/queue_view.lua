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
	self.stop = tile.new(Z - 0.01, "stop") -- behind the crowd: never covers passengers
	self.time = 0
	self:relayout(L)
	return self
end

local function build_track(self)
	for _, t in ipairs(self.track) do tile.delete(t) end
	self.track = {}
	local width = self.size * (self.lanes + 0.6)
	local step = width * 0.5
	-- two layers: a fresh mint-green meadow edge under the clean white walking ribbon
	for layer = 1, 2 do
		local pad = layer == 1 and 6 or 0
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
	self.lanes = L.loop.w < 360 and 3 or 4
	-- big, readable passengers that fill the ribbon like the reference: size follows both
	-- the width and the height of the loop, with a readable floor on a 360-wide phone
	self.size = math.max(10, math.min(L.loop.w * 0.055, L.loop.h * 0.11))
	self.row_step = self.size * 0.95
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
	-- bus stop sign outside the queue, near the right curb (the reference keeps stops off the path)
	local s = math.max(36, self.size * 3.6)
	tile.set(self.stop, { x = c.x + c.w * 0.93, y = c.y + c.h * 0.16, w = s * 0.75, h = s,
		tint = palette.GOLD })
	self.counter_value = nil
end

-- i-th passenger from the head -> position (fractional offset for the slide)
function M:slot_pos(i)
	local row = math.floor(i / self.lanes)
	local lane = i % self.lanes - (self.lanes - 1) * 0.5
	local x, y, a, on = self.path:at(row * self.row_step + self.offset * self.row_step / self.lanes)
	local nx, ny = -math.sin(a), math.cos(a)
	return x + nx * lane * self.size * 0.92, y + ny * lane * self.size * 0.92, on
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
	local bob = self.size * 0.09
	if self.offset < 0.01 then self.offset = 0 end
	local st = self.st
	for i, id in ipairs(self.pool) do
		local c = st.queue[st.head + i - 1]
		local x, y, on = self:slot_pos(i - 1)
		local visible = c ~= nil and on
		-- little idle hop, out of phase along the line (the crowd looks alive)
		local near = i <= self.lanes * 2 and 1.25 or 1
		local hop = math.abs(math.sin(self.time * 6 + i * 0.7)) * bob * near
		go.set_position(vmath.vector3(x, y + hop, visible and Z or -2), id) -- z -2: outside the projection
		local s = self.size / IMG
		go.set(msg.url(nil, id, "sprite"), "scale", vmath.vector3(s, s, 1))
		if visible and self.tints[i] ~= c then
			self.tints[i] = c
			sprite.play_flipbook(msg.url(nil, id, "sprite"), "dot_" .. c)
			go.set(msg.url(nil, id, "sprite"), "tint", palette.WHITE)
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
	tile.delete(self.stop)
	self.pool, self.track = {}, {}
end

return M
