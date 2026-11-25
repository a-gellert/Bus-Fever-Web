-- Pure math 3D diorama camera: shared by game.render_script (view/proj matrices)
-- and level.script / views (screen <-> 3D ground/roof raycasting & projection).
local M = {}

local function basis(w, h)
	local portrait = h >= w * 1.15
	local tilt = math.rad(portrait and 23 or 20)
	local fov = math.rad(30)
	local aspect = w / math.max(1, h)
	local tx = w * 0.5
	local ty = h * (portrait and 0.49 or 0.485)
	local tan_y = math.tan(fov * 0.5)
	local sin_t, cos_t = math.sin(tilt), math.cos(tilt)
	-- Pull distance slightly back so bottom corners + 3D bus roofs fit inside NDC [-0.96, 0.96]
	local d_vert = (h * 0.53 * cos_t) / tan_y
	local d_horiz = (h * 0.53) / tan_y + ty * sin_t * 0.52
	local d = math.max(d_vert, d_horiz)
	local ex, ey, ez = tx, ty - d * sin_t, d * cos_t

	-- Camera orthonormal basis (fz points from target to eye)
	local zx, zy, zz = ex - tx, ey - ty, ez
	local zl = math.sqrt(zx * zx + zy * zy + zz * zz)
	local fzx, fzy, fzz = zx / zl, zy / zl, zz / zl
	-- right = up(0,1,0) x fz = (fzz, 0, -fzx) normalized
	local fxx, fxy, fxz = fzz, 0, -fzx
	local xl = math.sqrt(fxx * fxx + fxz * fxz)
	fxx, fxz = fxx / xl, fxz / xl
	-- camera up = fz x fx
	local fyx = fzy * fxz - fzz * fxy
	local fyy = fzz * fxx - fzx * fxz
	local fyz = fzx * fxy - fzy * fxx

	return {
		w = w, h = h, fov = fov, aspect = aspect,
		near = math.max(50, d * 0.1), far = d * 3.5,
		tx = tx, ty = ty, ex = ex, ey = ey, ez = ez,
		fxx = fxx, fxy = fxy, fxz = fxz,
		fyx = fyx, fyy = fyy, fyz = fyz,
		fzx = fzx, fzy = fzy, fzz = fzz,
		tan_y = tan_y, tan_x = tan_y * aspect,
	}
end

M.basis = basis

-- Defold view & projection matrices for the 3D world pass
function M.matrices(w, h)
	local p = basis(w, h)
	local view = vmath.matrix4_look_at(
		vmath.vector3(p.ex, p.ey, p.ez),
		vmath.vector3(p.tx, p.ty, 0),
		vmath.vector3(0, 1, 0)
	)
	local proj = vmath.matrix4_perspective(p.fov, p.aspect, p.near, p.far)
	return view, proj, p
end

-- Screen pixel (sx, sy) -> intersection (wx, wy) on horizontal plane z = z_plane
function M.screen_to_plane(w, h, sx, sy, z_plane)
	local p = basis(w, h)
	local nx = (sx / math.max(1, w)) * 2 - 1
	local ny = (sy / math.max(1, h)) * 2 - 1
	local dx = p.fxx * (nx * p.tan_x) + p.fyx * (ny * p.tan_y) - p.fzx
	local dy = p.fxy * (nx * p.tan_x) + p.fyy * (ny * p.tan_y) - p.fzy
	local dz = p.fxz * (nx * p.tan_x) + p.fyz * (ny * p.tan_y) - p.fzz
	if math.abs(dz) < 1e-6 then return sx, sy end
	local t = ((z_plane or 0) - p.ez) / dz
	return p.ex + t * dx, p.ey + t * dy
end

-- World 3D (wx, wy, wz) -> screen pixel (sx, sy) for HUD hand / indicators
function M.world_to_screen(w, h, wx, wy, wz)
	local p = basis(w, h)
	local vx = wx - p.ex
	local vy = wy - p.ey
	local vz = (wz or 0) - p.ez
	local cx = vx * p.fxx + vy * p.fxy + vz * p.fxz
	local cy = vx * p.fyx + vy * p.fyy + vz * p.fyz
	local cz = -(vx * p.fzx + vy * p.fzy + vz * p.fzz)
	if cz <= 1 then return w * 0.5, h * 0.5 end
	local nx = cx / (cz * p.tan_x)
	local ny = cy / (cz * p.tan_y)
	return (nx + 1) * 0.5 * w, (ny + 1) * 0.5 * h
end

return M
