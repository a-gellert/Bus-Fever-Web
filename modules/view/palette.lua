-- Colour ids (sim) -> tints (view). Own palette: not the reference game's.
local M = {}

local function hex(s)
	return vmath.vector4(tonumber(s:sub(1, 2), 16) / 255, tonumber(s:sub(3, 4), 16) / 255, tonumber(s:sub(5, 6), 16) / 255, 1)
end

M.COLORS = {
	hex("ff4f6d"), -- coral
	hex("2fb7ff"), -- sky
	hex("ffc93c"), -- sun
	hex("4ade80"), -- mint
	hex("a77bff"), -- violet
	hex("ff8c3a"), -- tangerine
	hex("ff6fd8"), -- bubblegum
	hex("18c7b0"), -- teal
	hex("8b5a3c"), -- cocoa
}
M.HIDDEN = hex("2b2d42")
M.BACKGROUND = hex("e9eef5")
M.ASPHALT = hex("c9d1dc")
M.BAY = hex("ffffff")
M.BAY_VIP = hex("ffb020")
M.BAY_LOCKED = hex("3ccf7a")
M.GARAGE = hex("7c3aed")
M.BUTTON = hex("3b82f6")
M.BUTTON_OFF = hex("9aa5b4")
M.TEXT = hex("1f2937")

function M.of(id) return M.COLORS[id] or M.HIDDEN end

return M
