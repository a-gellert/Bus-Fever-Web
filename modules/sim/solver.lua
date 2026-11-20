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

local function settle(st)
	while true do
		local id = rules.board_one(st)
		if not id then return end
		if st.buses[id].left == 0 then rules.depart(st, id) end
	end
end

local function key(st)
	local parts = { st.head }
	for _, bay in ipairs(st.bays) do parts[#parts + 1] = bay.bus or 0 end
	for _, id in ipairs(st.order) do
		if st.buses[id].state == "lot" then parts[#parts + 1] = id end
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

-- Returns true (solved), false (proved unsolvable) or nil (budget exhausted); plus nodes visited.
function M.solve(st, budget)
	budget = budget or 20000
	local nodes, seen = 0, {}
	local exhausted = false

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
		for _, id in ipairs(rules.parked(s)) do
			if rules.exit_check(s, id) then
				cands[#cands + 1] = { id = id, u = urgency(s, s.buses[id]) }
			end
		end
		table.sort(cands, function(a, b) if a.u ~= b.u then return a.u < b.u end return a.id < b.id end)
		for _, c in ipairs(cands) do
			local n = clone(s)
			rules.send(n, c.id, bay)
			rules.arrive(n, c.id)
			if dfs(n) then return true end
			if exhausted then return false end
		end
		return false
	end

	local ok = dfs(clone(st))
	if not ok and exhausted then return nil, nodes end
	return ok, nodes
end

return M
