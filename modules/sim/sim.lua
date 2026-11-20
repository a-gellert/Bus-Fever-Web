-- Real-time driver over rules.lua: input (tap, boosters), timers, boarding pace, win/stuck.
-- The view calls sim:update(dt) each frame and sim:drain() to get events to animate.
-- No Defold API: runs the same in tests.
local config = require("modules.config")
local rules = require("modules.sim.rules")
local boosters = require("modules.sim.boosters")

local M = {}
M.__index = M

function M.new(level, seed)
	local self = setmetatable({}, M)
	self.st = rules.new(level)
	self.seed = seed or level.seed or 1
	self.events = {}
	self.timers = {}
	self.board_acc = 0
	self.result = nil     -- "won" | "stuck" once reached
	self.time = 0
	return self
end

local function push(self, ev) self.events[#self.events + 1] = ev end

local function push_all(self, list)
	for _, ev in ipairs(list) do push(self, ev) end
end

local function after(self, delay, fn)
	self.timers[#self.timers + 1] = { t = self.time + delay, fn = fn }
end

function M:drain()
	local ev = self.events
	self.events = {}
	return ev
end

local function dispatch(self, id, bay, kind, travel)
	push_all(self, rules.send(self.st, id, bay))
	push(self, { type = kind, bus = id, bay = bay, time = travel })
	after(self, travel, function()
		rules.arrive(self.st, id)
		push(self, { type = "arrive", bus = id, bay = bay })
	end)
	self.result = nil
end

-- Player tapped a bus in the lot
function M:tap(id)
	local bus = self.st.buses[id]
	if not bus or bus.state ~= "lot" or self.result == "won" then return end
	local free, blocker, dist = rules.exit_check(self.st, id)
	if not free then
		push(self, { type = "blocked", bus = id, blocker = blocker, dist = dist })
		return
	end
	local bay = rules.free_bay(self.st, "open")
	if not bay then
		push(self, { type = "no_bay", bus = id })
		return
	end
	dispatch(self, id, bay, "drive", config.DRIVE_TIME)
end

-- Boosters: return true when applied (the caller spends the booster only then)
function M:use_vip(id)
	local bay = boosters.vip_target(self.st, id)
	if not bay then return false end
	dispatch(self, id, bay, "teleport", config.TELEPORT_TIME)
	return true
end

function M:use_arrange()
	if not boosters.arrange(self.st) then return false end
	push(self, { type = "queue_changed" })
	self.result = nil
	return true
end

function M:use_jumble()
	self.seed = self.seed + 7919
	local changed = boosters.jumble(self.st, self.seed)
	if not changed then return false end
	push(self, { type = "recolor", buses = changed })
	self.result = nil
	return true
end

function M:unlock_bay()
	local i = boosters.unlock_bay(self.st)
	if not i then return false end
	push(self, { type = "bay_unlocked", bay = i })
	self.result = nil
	return true
end

local function run_timers(self)
	local i = 1
	while i <= #self.timers do
		local tm = self.timers[i]
		if tm.t <= self.time then
			table.remove(self.timers, i)
			tm.fn()
		else
			i = i + 1
		end
	end
end

local function board(self, dt)
	local step = 1 / config.BOARD_RATE
	self.board_acc = self.board_acc + dt
	while self.board_acc >= step do
		local id = rules.board_one(self.st)
		if not id then
			self.board_acc = step -- nobody to board: don't bank a burst
			return
		end
		self.board_acc = self.board_acc - step
		local bus = self.st.buses[id]
		push(self, { type = "board", bus = id, color = bus.color, left = bus.left, head = self.st.head })
		if bus.left == 0 then
			push(self, { type = "full", bus = id })
			after(self, config.DEPART_DELAY, function()
				local bay = bus.bay
				rules.depart(self.st, id)
				push(self, { type = "depart", bus = id, bay = bay, time = config.DEPART_TIME })
			end)
		end
	end
end

function M:update(dt)
	self.time = self.time + dt
	run_timers(self)
	board(self, dt)
	if not self.result and #self.timers == 0 then
		local s = rules.status(self.st)
		if s ~= "play" then
			self.result = s
			push(self, { type = s })
		end
	end
end

return M
