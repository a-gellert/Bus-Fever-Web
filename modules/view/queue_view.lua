-- Passenger crowd on the loop: a fixed pool of sprites, 3 abreast, coloured from the queue.
-- On every boarding the crowd slides one place forward (offset eases back to 0).
local path_loop = require("modules.view.path_loop")
local palette = require("modules.view.palette")

local M = {}
M.__index = M

local FACTORY = "/level#passenger_factory"
local IMG = 32            -- dot.png
local LANES = 3
local Z = 0.3

function M.new(st, L, shape)
	local self = setmetatable({ st = st, shape = shape or "u", pool = {}, tints = {}, offset = 0 }, M)
	self:relayout(L)
	return self
end

function M:relayout(L)
	self.L = L
	self.path = path_loop.in_rect(self.shape, L.loop)
	self.size = math.min(L.loop.w, L.loop.h) * 0.07       -- passenger diameter, px
	self.row_step = self.size * 0.95
	local rows = math.floor(self.path.length / self.row_step)
	local want = rows * LANES
	while #self.pool < want do
		self.pool[#self.pool + 1] = factory.create(FACTORY, vmath.vector3(0, 0, Z))
	end
	while #self.pool > want do go.delete(table.remove(self.pool)) end
	for _, id in ipairs(self.pool) do
		go.set(msg.url(nil, id, "sprite"), "scale", vmath.vector3(self.size / IMG, self.size / IMG, 1))
	end
	self.tints = {}
end

-- Head passenger index left -> slot position (fractional for the slide)
function M:slot_pos(i)
	local row = math.floor(i / LANES)
	local lane = i % LANES - (LANES - 1) * 0.5
	local x, y, a, on = self.path:at(row * self.row_step + self.offset * self.row_step / LANES)
	local nx, ny = -math.sin(a), math.cos(a)
	return x + nx * lane * self.size, y + ny * lane * self.size, on
end

function M:on_board()
	self.offset = self.offset + 1
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
end

-- World position of the passenger at the head (for the jump into a bus)
function M:head_pos()
	local x, y = self:slot_pos(0)
	return vmath.vector3(x, y, Z + 0.1)
end

function M:delete()
	for _, id in ipairs(self.pool) do go.delete(id) end
	self.pool = {}
end

return M
