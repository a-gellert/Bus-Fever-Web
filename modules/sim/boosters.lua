-- Booster effects on rules state. Inventory and unlock levels live in meta/progress.lua.
local rules = require("modules.sim.rules")
local rng = require("modules.sim.rng")

local M = {}

-- VIP: any parked bus, even blocked, goes to the VIP bay. Returns the bay index or nil.
function M.vip_target(st, id)
	local bus = st.buses[id]
	if not bus or bus.state ~= "lot" then return nil end
	return rules.free_bay(st, "vip")
end

-- Arrange: passengers who already have a seat in a bay go to the front, order otherwise kept.
function M.arrange(st)
	local seats = {}
	for _, bay in ipairs(st.bays) do
		local bus = bay.bus and st.buses[bay.bus]
		if bus and (bus.state == "bay" or bus.state == "to_bay") then
			seats[bus.color] = (seats[bus.color] or 0) + bus.left
		end
	end
	local front, back = {}, {}
	for i = st.head, #st.queue do
		local c = st.queue[i]
		if (seats[c] or 0) > 0 then
			seats[c] = seats[c] - 1
			front[#front + 1] = c
		else
			back[#back + 1] = c
		end
	end
	if #front == 0 then return false end
	local i = st.head
	for _, c in ipairs(front) do st.queue[i] = c; i = i + 1 end
	for _, c in ipairs(back) do st.queue[i] = c; i = i + 1 end
	return true
end

-- Jumble: shuffle colours among parked buses of equal capacity, so the queue still adds up.
-- Returns the list of recoloured bus ids, or nil.
function M.jumble(st, seed)
	local r = rng.new(seed)
	local by_cap, caps = {}, {}
	for _, id in ipairs(rules.parked(st)) do
		local bus = st.buses[id]
		if not by_cap[bus.cap] then
			by_cap[bus.cap] = {}
			caps[#caps + 1] = bus.cap
		end
		table.insert(by_cap[bus.cap], bus)
	end
	table.sort(caps) -- fixed order keeps the shuffle deterministic
	local changed = {}
	for _, cap in ipairs(caps) do
		local group = by_cap[cap]
		local colors = {}
		for i, bus in ipairs(group) do colors[i] = bus.color end
		r:shuffle(colors)
		for i, bus in ipairs(group) do
			if bus.color ~= colors[i] then
				bus.color = colors[i]
				changed[#changed + 1] = bus.id
			end
		end
	end
	if #changed == 0 then return nil end
	return changed
end

-- "+" bay: rewarded unlock of the first locked bay
function M.unlock_bay(st)
	for i, bay in ipairs(st.bays) do
		if bay.kind == "locked" then
			bay.kind = "open"
			return i
		end
	end
end

return M
