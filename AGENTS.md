# Agent rules

Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) before changing code.

1. **Target**: HTML5 portals (Poki first), Defold 1.14, build 3–5 MB, portrait and landscape.
2. **No physics components.** Collisions are OBB math in `modules/sim/geometry.lua`.
3. **`modules/sim/` is pure Lua**: no Defold API, deterministic (`rng.lua`), Lua 5.1 subset. It must run in `node tools/run_tests.js`.
4. **One flow script**: `entities/level/level.script`. Prefabs (bus, passenger, tile) have no scripts.
5. **Views never decide rules**: they animate sim events. Legality lives in `rules.lua`.
6. **Every campaign level is solvable without boosters, also for a fast real-time player.** `tests/test_level_gen.lua` and `tests/test_replay.lua` check it. After any change to rules, templates, generator or the curve, re-run `node tools/tune_levels.js 100` and then all tests.
7. **Poki SDK only through `modules/platform/ads.lua`**: `gameplay_start` on the first input, `gameplay_stop` on level end and before ads; interstitials from level 5, at most once per 150 s; rewarded for "+" bays, boosters, rescue.
8. **Tuning in data**: `modules/config.lua`, `modules/meta/levels.lua`.
9. **Own identity**: no names, icons, UI or palette copied from the reference game.
10. **Test without opening windows.** Never start `dmengine.exe` (or any game window) on the developer's desktop. Use `node tools/run_tests.js` for logic and `node tools/web_smoke.js` (headless Chrome on an HTML5 bundle) for the real game: screenshots, console errors, `bus.autoplay=1` playthroughs.
