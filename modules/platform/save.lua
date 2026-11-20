-- Save file via sys.save (HTML5 build persists it in the browser's IndexedDB).
local M = {}

local APP = "bus_loop"
local FILE = "save.dat"

function M.load()
	local ok, data = pcall(sys.load, sys.get_save_file(APP, FILE))
	if not ok or not data or next(data) == nil then return nil end
	return data
end

function M.save(data)
	local ok, res = pcall(sys.save, sys.get_save_file(APP, FILE), data)
	return ok and res
end

return M
