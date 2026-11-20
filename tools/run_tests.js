// Headless tests for pure Lua modules (modules/sim, modules/view/path_loop, ...).
// fengari is Lua 5.3; Defold runs LuaJIT 5.1 — sim code sticks to the common subset.
// Run from anywhere: node tools/run_tests.js [tests/test_x.lua ...]
const path = require('path');
const fs = require('fs');
const { lua, lauxlib, lualib, to_luastring } = require('fengari');

const root = path.join(__dirname, '..');
process.chdir(root);
const files = process.argv.slice(2).length
  ? process.argv.slice(2)
  : fs.readdirSync(path.join(root, 'tests')).filter(f => /^test_.*\.lua$/.test(f)).map(f => 'tests/' + f);

let failed = 0;
for (const f of files) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  const boot = `package.path = "./?.lua;" .. package.path
    if not math.pow then math.pow = function(a, b) return a ^ b end end`;
  lauxlib.luaL_dostring(L, to_luastring(boot));
  const t0 = Date.now();
  if (lauxlib.luaL_dofile(L, to_luastring(f)) !== lua.LUA_OK) {
    failed++;
    console.log(`FAIL ${f}\n  ${lua.lua_tojsstring(L, -1)}`);
  } else {
    console.log(`ok   ${f} (${Date.now() - t0} ms)`);
  }
}
process.exit(failed ? 1 : 0);
