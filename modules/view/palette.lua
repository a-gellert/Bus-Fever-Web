-- Colour ids (sim) -> tints (view). Vibrant casual 3D toy palette matching Bus Fever Party aesthetic.
local M = {}

local function hex(s, a)
	return vmath.vector4(tonumber(s:sub(1, 2), 16) / 255, tonumber(s:sub(3, 4), 16) / 255, tonumber(s:sub(5, 6), 16) / 255, a or 1)
end
M.hex = hex

-- Vibrant candy colours for 3D buses & passengers
M.COLORS = {
	hex("ff3b4e"), -- coral red
	hex("1e90ff"), -- sky blue
	hex("ffbd00"), -- sunshine yellow
	hex("28d160"), -- emerald green
	hex("9b51e0"), -- vivid purple
	hex("ff5ca8"), -- candy pink
	hex("ff7b1c"), -- tangerine orange
	hex("3742fa"), -- deep cobalt
	hex("eef2f7"), -- pearl cream
}
M.HIDDEN = hex("333a45")
M.WHITE = hex("ffffff")
M.SHADOW = vmath.vector4(0.08, 0.12, 0.18, 0.42)

-- 3D Diorama Environment
M.PARK_GRASS = hex("8ed65b")
M.PARK_PATH = hex("e6dab5")
M.LOT_BORDER = hex("b5c4d6")
M.ASPHALT = hex("dce5ef") -- bright pale ice-blue parking floor so colorful 3D buses pop
M.PANEL = hex("5b6572")   -- smooth dark slate bay road
M.PIER_RIM = hex("f1f5f9")
M.TRACK = hex("f4f7fb")   -- crisp sidewalk queue walkway
M.TRACK_EDGE = hex("cbd5e1") -- raised stone sidewalk curb

M.BAY = hex("5b6572")
M.BAY_VIP = hex("ffb800")
M.BAY_LOCKED = hex("2ed573")
M.GARAGE = hex("7c5cbf")
M.BARRIER = hex("ffa502")
M.BELT = hex("2ed573")
M.TURN = hex("9b51e0")
M.GOLD = hex("ffb800")
M.BADGE = hex("ff3b4e")
M.CREAM = hex("ffffff")
M.DIM = vmath.vector4(0.08, 0.12, 0.18, 0.72)

-- Sleek 3D pill HUD cards
M.HUD_CARD = hex("54a0ff")
M.HUD_LIP = hex("2e86de")
M.HUD_TEXT = hex("ffffff")
M.HUD_OFF_CARD = hex("a4b0be")
M.HUD_OFF_LIP = hex("747d8c")
M.HUD_HEADER = hex("475569", 0.88)

M.BUTTONS = { vip = hex("ff9f1a"), arrange = hex("4fa3ff"), jumble = hex("2ed573") }
M.BUTTON_OFF = hex("94a3b8")
M.BUTTON_OK = hex("2ed573")
M.BUTTON_NEUTRAL = hex("475569")

function M.of(id) return M.COLORS[id] or M.HIDDEN end

return M
