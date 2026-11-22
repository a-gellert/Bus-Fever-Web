-- Bounded DFS over rules.lua with instant moves and no boosters.
-- Used by tests and level tuning (solvability, how many dead ends a level has).
-- Knows hidden colours, so it answers "is the level solvable", not "is it fair".
local rules = require("modules.sim.rules")

local M = {}

local function clone(st)
	local c = {}
	for k, v in pairs(st) do c[k] = v end
	c.buses = {}
	for id, b in pairs(st.buses) do
		local nb = {}
		for k, v in pairs(b) do nb[k] = v end
		c.buses[id] = nb
	end
	c.bays = {}
	for i, bay in ipairs(st.bays) do c.bays[i] = { kind = bay.kind, bus = bay.bus } end
	c.garages = {}
	for i, g in ipairs(st.garages) do
		local ng = {}
		for k, v in pairs(g) do ng[k] = v end
		ng.queue = {}
		for j, spec in ipairs(g.queue) do ng.queue[j] = spec end
		c.garages[i] = ng
	end
	c.order = {}
	for i, id in ipairs(st.order) do c.order[i] = id end
	return c -- queue is shared: nothing here mutates it
end

-- Copy of a live (real-time) state with every pending move finished: driving buses arrive,
-- full buses leave. The solver works only on such settled states.
function M.instant(st)
	local s = clone(st)
	for _, id in ipairs(s.order) do
		local bus = s.buses[id]
		if bus.state == "to_bay" then rules.arrive(s, id) end
		if bus.state == "full" then rules.depart(s, id) end
	end
	return s
end

local function settle(st)
	while true do
		local id = rules.board_one(st)
		if not id then return end
		if st.buses[id].left == 0 then rules.depart(st, id) end
	end
end

local function key(st)
	local parts = { st.head }
	-- buses in bays in boarding-priority (tap) order; bay positions don't matter
	local inbay = {}
	for _, bay in ipairs(st.bays) do
		if bay.bus then inbay[#inbay + 1] = st.buses[bay.bus] end
	end
	table.sort(inbay, function(a, b) return a.seq < b.seq end)
	for _, b in ipairs(inbay) do parts[#parts + 1] = b.id .. ":" .. b.left end
	parts[#parts + 1] = "|"
	for _, id in ipairs(st.order) do
		local bus = st.buses[id]
		if bus.state == "lot" then
			-- switching buses change orientation, so it is part of the position
			if bus.turning then
				parts[#parts + 1] = id .. "@" .. string.format("%.2f", bus.box.angle)
			else
				parts[#parts + 1] = id
			end
		end
	end
	return table.concat(parts, ",")
end

-- How soon the bus colour is needed in the queue (lower = better candidate)
local function urgency(st, bus)
	for i = st.head, #st.queue do
		if st.queue[i] == bus.color then return i - st.head end
	end
	return #st.queue
end

-- Returns true (solved), false (proved unsolvable) or nil (budget exhausted); nodes visited;
-- and the winning tap order (bus ids) when solved.
function M.solve(st, budget)
	budget = budget or 20000
	local nodes, seen = 0, {}
	local exhausted = false
	local plan = {}

	local function dfs(s)
		settle(s)
		if s.head > #s.queue then return true end
		local bay = rules.free_bay(s, "open")
		if not bay then return false end
		local k = key(s)
		if seen[k] then return false end
		seen[k] = true
		nodes = nodes + 1
		if nodes > budget then exhausted = true return false end

		local cands = {}
		for _, id in ipairs(rules.free_buses(s)) do
			cands[#cands + 1] = { id = id, u = urgency(s, s.buses[id]) }
		end
		table.sort(cands, function(a, b) if a.u ~= b.u then return a.u < b.u end return a.id < b.id end)
		for _, c in ipairs(cands) do
			local n = clone(s)
			rules.send(n, c.id, bay)
			rules.arrive(n, c.id)
			plan[#plan + 1] = c.id
			if dfs(n) then return true end
			plan[#plan] = nil
			if exhausted then return false end
		end
		return false
	end

	local ok = dfs(M.instant(st))
	if not ok and exhausted then return nil, nodes end
	return ok, nodes, ok and plan or nil
end

-- Model of a casual but attentive player, for difficulty tuning (not a solver):
-- among free vehicles picks the colour needed soonest in the next `look` passengers, with
-- `noise` slots of misjudgement; hidden vehicles are unknown (scored as "later").
-- Returns true if the level was cleared without boosters.
function M.play_casual(st, rng, look, noise)
	local s = M.instant(st)
	look, noise = look or 40, noise or 8
	while true do
		settle(s)
		if s.head > #s.queue then return true end
		local bay = rules.free_bay(s, "open")
		if not bay then return false end
		local best, best_u
		for _, id in ipairs(rules.free_buses(s)) do
			local bus = s.buses[id]
			local u = look
			if not bus.hidden then
				for i = s.head, math.min(#s.queue, s.head + look - 1) do
					if s.queue[i] == bus.color then u = i - s.head break end
				end
			end
			u = u + rng:float() * noise
			if not best_u or u < best_u then best, best_u = id, u end
		end
		if not best then return false end
		rules.send(s, best, bay)
		rules.arrive(s, best)
	end
end

return M
