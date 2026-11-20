-- Screen zones for portrait and landscape. World units = window pixels (see main/render).
-- Pure math: compute(w, h, lot) -> zones, lot transform, bay and button positions.
local M = {}

local function rect(x, y, w, h) return { x = x, y = y, w = w, h = h } end

local function sub(r, fx, fy, fw, fh)
	return rect(r.x + r.w * fx, r.y + r.h * fy, r.w * fw, r.h * fh)
end

-- lot = {w, h} in lot units; n_bays = total bay count (vip + open + locked)
function M.compute(w, h, lot, n_bays)
	local L = { w = w, h = h, portrait = h >= w * 1.15 }
	local screen = rect(0, 0, w, h)
	if L.portrait then
		L.loop = sub(screen, 0.04, 0.72, 0.92, 0.26)
		L.bays = sub(screen, 0.03, 0.62, 0.94, 0.09)
		L.lot = sub(screen, 0.04, 0.13, 0.92, 0.48)
		L.buttons = sub(screen, 0.08, 0.02, 0.84, 0.09)
	else
		local left, right = sub(screen, 0.02, 0.03, 0.56, 0.94), sub(screen, 0.60, 0.03, 0.38, 0.94)
		L.lot = left
		L.loop = sub(right, 0, 0.50, 1, 0.50)
		L.bays = sub(right, 0, 0.34, 1, 0.14)
		L.buttons = sub(right, 0.05, 0.03, 0.9, 0.18)
	end

	-- lot units -> pixels, centred in the lot zone
	local unit = math.min(L.lot.w / lot.w, L.lot.h / lot.h)
	L.unit = unit
	L.lot_x = L.lot.x + (L.lot.w - lot.w * unit) * 0.5
	L.lot_y = L.lot.y + (L.lot.h - lot.h * unit) * 0.5

	-- bays: one row of vertical slots
	L.bay_pos = {}
	local slot_w = L.bays.w / n_bays
	L.bay_unit = math.min(slot_w / 1.25, L.bays.h / 4.2) -- a long bus (4 units) fits a bay
	for i = 1, n_bays do
		L.bay_pos[i] = { x = L.bays.x + slot_w * (i - 0.5), y = L.bays.y + L.bays.h * 0.5 }
	end

	-- booster / restart buttons in one row
	L.button_pos = {}
	local n = 4
	for i = 1, n do
		L.button_pos[i] = { x = L.buttons.x + L.buttons.w * (i - 0.5) / n, y = L.buttons.y + L.buttons.h * 0.5 }
	end
	L.button_size = { w = L.buttons.w / n * 0.86, h = L.buttons.h * 0.8 }
	return L
end

function M.lot_to_world(L, x, y)
	return L.lot_x + x * L.unit, L.lot_y + y * L.unit
end

function M.world_to_lot(L, x, y)
	return (x - L.lot_x) / L.unit, (y - L.lot_y) / L.unit
end

return M
