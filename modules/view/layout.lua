-- Screen zones for portrait and landscape. World units = window pixels (see main/render).
-- Pure math: compute(w, h, lot, n_bays) -> zones, lot transform, bay and button positions.
local M = {}

local function rect(x, y, w, h) return { x = x, y = y, w = w, h = h } end

local function sub(r, fx, fy, fw, fh)
	return rect(r.x + r.w * fx, r.y + r.h * fy, r.w * fw, r.h * fh)
end

M.N_BUTTONS = 3 -- boosters; restart lives in the header

-- lot = {w, h} in lot units; n_bays = bays on screen (vip + open + locked)
function M.compute(w, h, lot, n_bays)
	local L = { w = w, h = h, portrait = h >= w * 1.15 }
	local screen = rect(0, 0, w, h)
	if L.portrait then
		-- the lot gets the most height: it is where the decisions are
		L.header = sub(screen, 0.03, 0.948, 0.94, 0.047)
		L.loop = sub(screen, 0.04, 0.745, 0.92, 0.2)
		L.bays = sub(screen, 0.03, 0.64, 0.94, 0.09)
		L.lot = sub(screen, 0.025, 0.122, 0.95, 0.465) -- leaves a road between the lot and the pier
		L.buttons = sub(screen, 0.04, 0.01, 0.92, 0.1)
	else
		-- very wide windows: keep the play area at most 2:1 and centre it
		local pw = math.min(w, h * 2)
		local play = rect((w - pw) * 0.5, 0, pw, h)
		local left, right = sub(play, 0.02, 0.03, 0.58, 0.94), sub(play, 0.62, 0.03, 0.36, 0.94)
		L.lot = left
		L.header = sub(right, 0, 0.92, 1, 0.08)
		L.loop = sub(right, 0, 0.52, 1, 0.38)
		L.bays = sub(right, 0, 0.35, 1, 0.14)
		L.buttons = sub(right, 0, 0.02, 1, 0.15)
	end

	-- lot units -> pixels, centred in the lot zone
	local unit = math.min(L.lot.w / lot.w, L.lot.h / lot.h)
	L.unit = unit
	L.lot_x = L.lot.x + (L.lot.w - lot.w * unit) * 0.5
	L.lot_y = L.lot.y + (L.lot.h - lot.h * unit) * 0.5

	-- bays: one row of vertical slots that nearly touch (a pier with dividers)
	L.bay_pos = {}
	local slot_w = L.bays.w / n_bays
	L.slot_w = slot_w
	L.bay_unit = math.min(slot_w / 1.2, L.bays.h / 4.3) -- a long bus (4 units) fits a bay
	for i = 1, n_bays do
		L.bay_pos[i] = { x = L.bays.x + slot_w * (i - 0.5), y = L.bays.y + L.bays.h * 0.5 }
	end

	-- booster buttons in one row, touch targets >= 48 px
	L.button_pos = {}
	local n = M.N_BUTTONS
	for i = 1, n do
		L.button_pos[i] = { x = L.buttons.x + L.buttons.w * (i - 0.5) / n, y = L.buttons.y + L.buttons.h * 0.5 }
	end
	L.button_size = { w = math.max(48, L.buttons.w / n * 0.9), h = math.max(48, L.buttons.h * 0.86) }

	-- header: level title in the middle, restart on the right
	local hs = math.max(44, L.header.h)
	L.title_pos = { x = L.header.x + L.header.w * 0.5, y = L.header.y + L.header.h * 0.5 }
	L.restart_pos = { x = L.header.x + L.header.w - hs * 0.5, y = L.title_pos.y }
	L.restart_size = hs
	L.sound_pos = { x = L.header.x + hs * 0.5, y = L.title_pos.y }
	return L
end

function M.lot_to_world(L, x, y)
	return L.lot_x + x * L.unit, L.lot_y + y * L.unit
end

function M.world_to_lot(L, x, y)
	return (x - L.lot_x) / L.unit, (y - L.lot_y) / L.unit
end

return M
