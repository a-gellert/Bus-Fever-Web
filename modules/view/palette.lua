-- Colour ids (sim) -> tints (view). "Night city" identity: candy-neon vehicles on dark navy.
local M = {}

local function hex(s, a)
	return vmath.vector4(tonumber(s:sub(1, 2), 16) / 255, tonumber(s:sub(3, 4), 16) / 255, tonumber(s:sub(5, 6), 16) / 255, a or 1)
end
M.hex = hex

-- vehicle / passenger colours, hue families kept far apart
M.COLORS = {
	hex("ff4d6d"), -- coral
	hex("22d3ee"), -- electric cyan
	hex("ffc933"), -- warm lemon
	hex("5fd94a"), -- green (well away from lemon)
	hex("9d6bff"), -- violet
	hex("ff5cc8"), -- hot pink
	hex("ff8a1f"), -- orange
	hex("3b6cff"), -- deep blue
	hex("f1f5f9"), -- pearl
}
M.HIDDEN = hex("5d5a8a")
M.WHITE = hex("ffffff")
M.SHADOW = hex("000000", 0.35)

M.LOT_BORDER = hex("4a5a7a")
M.ASPHALT = hex("2c3a52")
M.PANEL = hex("1a2440", 0.92)
M.TRACK = hex("2b3a63") -- solid: overlapping ribbon pieces must not add up
M.TRACK_EDGE = hex("3e5086")
M.BAY = hex("5c70a6")
M.BAY_VIP = hex("ffd23f")
M.BAY_LOCKED = hex("6b7796")
M.GARAGE = hex("3b2a6b")
M.GOLD = hex("ffd23f")
M.BADGE = hex("e8344e")
M.PIER_RIM = hex("4a5c8f")
M.CREAM = hex("fff4d6")
M.DIM = hex("05080f", 0.7)

-- booster buttons: one accent each; restart stays neutral
M.BUTTONS = { vip = hex("ffb020"), arrange = hex("22b8e0"), jumble = hex("ff5c8a") }
M.BUTTON_OFF = hex("3a4466")
M.BUTTON_OK = hex("4ade80")
M.BUTTON_NEUTRAL = hex("5a6a92")

function M.of(id) return M.COLORS[id] or M.HIDDEN end

return M
