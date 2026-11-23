-- Colour ids (sim) -> tints (view). Fresh, bright, modern 3D casual palette matching reference.
local M = {}

local function hex(s, a)
	return vmath.vector4(tonumber(s:sub(1, 2), 16) / 255, tonumber(s:sub(3, 4), 16) / 255, tonumber(s:sub(5, 6), 16) / 255, a or 1)
end
M.hex = hex

-- vehicle / passenger colours, hue families kept far apart
M.COLORS = {
	hex("ff4757"), -- coral red
	hex("1e90ff"), -- sky blue / cyan
	hex("ffa502"), -- warm sunshine yellow
	hex("2ed573"), -- lime green
	hex("9c88ff"), -- cheerful violet
	hex("ff70a6"), -- bubblegum pink
	hex("ff7f50"), -- tangerine orange
	hex("3742fa"), -- deep cobalt
	hex("f1f2f6"), -- pearl white
}
M.HIDDEN = hex("353b48")
M.WHITE = hex("ffffff")
M.SHADOW = vmath.vector4(0, 0, 0, 0.35)

M.LOT_BORDER = hex("7b8fa7")
M.ASPHALT = hex("9bb0c6")
M.PANEL = hex("8fa3b8")
M.TRACK = hex("ffffff") -- clean white queue path
M.TRACK_EDGE = hex("85d4ac") -- fresh meadow mint curb
M.BAY = hex("7b8fa7")
M.BAY_VIP = hex("ffa502")
M.BAY_LOCKED = hex("2ed573")
M.GARAGE = hex("8854d0")
M.BARRIER = hex("ffa502")
M.BELT = hex("2ed573")
M.TURN = hex("9c88ff")
M.GOLD = hex("ffa502")
M.BADGE = hex("ff4757")
M.PIER_RIM = hex("72869e")
M.CREAM = hex("f8f9fa")
M.DIM = vmath.vector4(0.08, 0.12, 0.18, 0.7)

-- booster buttons: one accent each; restart stays neutral
M.BUTTONS = { vip = hex("ffa502"), arrange = hex("ff4757"), jumble = hex("2ed573") }
M.BUTTON_OFF = hex("95a5a6")
M.BUTTON_OK = hex("2ed573")
M.BUTTON_NEUTRAL = hex("576574")

function M.of(id) return M.COLORS[id] or M.HIDDEN end

return M
