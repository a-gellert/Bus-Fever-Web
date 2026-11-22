-- All tuning knobs in one place. Pure data: safe to require from sim, view and tests.
local M = {}

-- Palette ids are what the sim stores; view/palette.lua maps them to RGB.
M.COLOR_COUNT = 9

-- Vehicle sizes in lot units (1 unit = one lane width).
-- l/xl are the long "party" buses: more seats, harder to place and to free.
M.SIZES = {
	s = { len = 2, wid = 1, cap = 4 },
	m = { len = 3, wid = 1, cap = 8 },
	l = { len = 4, wid = 1, cap = 16 },
	xl = { len = 6, wid = 1, cap = 40 }, -- long party bus
	limo = { len = 5, wid = 1, cap = 6 }, -- business vehicle: long body, only six seats
}

-- Waiting row
M.BAYS_OPEN = 4
M.BAYS_LOCKED = 3         -- unlocked per level by a rewarded ad / coins
M.HAS_VIP_BAY = true

-- Coins (earned per level, spent on booster refills and "+" spots)
M.COIN_REWARD = 20
M.COIN_BOOSTER = 80

-- Timing (seconds) — the sim owns time, the view only animates towards it
M.DRIVE_TIME = 0.45       -- lot -> bay
M.TELEPORT_TIME = 0.30    -- VIP booster
M.BOARD_RATE = 13         -- passengers per second ("machine-gun" boarding)
M.DEPART_DELAY = 0.15     -- full bus waits, then leaves
M.DEPART_TIME = 0.40
M.NEXT_LEVEL_DELAY = 1.0  -- banner + confetti, then auto-advance

-- Boosters: level from which each one unlocks, and free starting stock
M.BOOSTERS = {
	vip = { unlock_level = 4, start = 1 },
	arrange = { unlock_level = 8, start = 1 },
	jumble = { unlock_level = 13, start = 1 },
}

-- Ads
M.INTERSTITIAL_FROM_LEVEL = 5
M.INTERSTITIAL_MIN_GAP = 150  -- seconds between commercial breaks

-- Passenger loop view
M.PASSENGER_SPACING = 0.022   -- fraction of loop length between two passengers

return M
