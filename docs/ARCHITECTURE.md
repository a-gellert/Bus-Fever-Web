# Architecture

Web-first parking puzzle with a passenger loop. Defold 1.14, HTML5 (Poki first). Target build size 3–5 MB.

## Layers

```
modules/
  config.lua            all tuning knobs (sizes, capacities, timings, booster unlocks, ads)
  sim/                  PURE Lua: no Defold API, deterministic, runs in tests
    geometry.lua        OBB, SAT overlap, exit sweep (first_hit) — no Box2D, no grid
    rules.lua           discrete rules + state: lot, garages, barriers, hidden, bays, queue, win/stuck
    sim.lua             real-time driver: tap, timers, boarding pace, events for the view
    boosters.lua        VIP, Arrange, Jumble, "+" bay unlock (effects only)
    templates.lua       lot shapes: grid, diagonal, rings, frames, fan, fill
    level_gen.lua       template -> reverse disassembly -> colours/queue (solvable by construction)
    solver.lua          bounded DFS over rules (tests, Jumble guard) + casual-player model (tuning)
    rng.lua             seeded RNG, same sequence on LuaJIT and Lua 5.3
  meta/
    levels.lua          level n -> generator params on a sawtooth curve; HANDMADE overrides
    level_seeds.lua     per-level seed offsets picked by tools/tune_levels.js (generated)
    progress.lua        level, booster stock, tutorial flag (the only owner of save data; validates old saves)
  platform/
    ads.lua             Poki wrapper: gameplay start/stop, interstitial gate, rewarded; no-op off-portal
    save.lua            sys.save/sys.load
  view/                 Defold-side presentation, no rules
    layout.lua          portrait/landscape zones, lot->pixel transform (pure math)
    path_loop.lua       passenger path by arc length (pure math)
    route.lua           driving route lot -> road ring -> bay, local corner fillets (pure math, tested)
    board_view.lua      backdrop, lot, bay pier, garages, belts, barriers, vehicles; sim events -> animations; picking
    queue_view.lua      passenger crowd on a road ribbon: sprite pool, 2-3 abreast, slide on boarding, "N LEFT"
    hud.lua             header, coins, booster buttons, modal popups, tutorial hand, win banner
    tile.lua            tile prefabs: 9-slice panels, images, text (one object type for UI)
    juice.lua           squash, lurch, shake, pop, flash, pulse, confetti
    audio.lua           named sounds (only registered names play)
    palette.lua         colour ids -> tints (own palette)
entities/
  level/level.script    the ONLY flow script: input, start/restart/advance, boosters, ads
  bus/                  bus.collection = root (label) + body (sprites) + shadow; no script
  passenger/, tile/, panel/  sprite-only prefabs (tile = image + label, panel = 9-slice + label)
  audio/audio.go        sound components (assets/sounds)
main/
  main.collection       /level controller + /audio
  render/               pixel render: world units = window pixels
assets/                 game.atlas + images (tools/gen_placeholders.js), sounds (tools/gen_sounds.js), fonts (Lilita One, OFL)
tests/                  headless Lua tests (node tools/run_tests.js)
```

## Data flow

```
input -> level.script -> sim:tap / sim:use_* -> rules (state change)
                               |
              sim:update(dt) -> events {drive, blocked, board, full, depart, reveal, spawn, won, stuck ...}
                               |
          board_view / queue_view / hud animate events; nothing in the view decides rules
```

- The sim owns time (drive, board rate, depart). Views only animate towards sim state.
- Vehicles and passengers have no scripts and no `update()`; one controller moves everything.
- No `msg.post` between game parts: direct Lua calls into modules.
- Level data is plain tables (see the header of `rules.lua`), so hand-made levels and generated ones are the same thing.

## Key decisions

| Decision | Why |
|---|---|
| OBB + SAT exit sweep instead of a grid | 45°, rings and spirals need free angles; ~100 lines, no physics |
| Discrete `rules` + timed `sim` | solver and tests reuse the exact game rules |
| Boarding priority = tap order | a fast player and the instant solver get the same result (no timing-dependent dead ends) |
| Seeds tuned offline | each level picks the seed whose casual-player fail rate is closest to its sawtooth target |
| Solvable by construction | exit order from reverse disassembly; queue mixes at most `window` vehicles, neighbours in a window never share a colour; `window` <= open bays |
| Initial facings retried, never flipped mid-run | a switching bus's start angle must not depend on disassembly history |
| One scale for every bus in the waiting row | short buses stay short; the longest bus in the level sets `bay_unit`, no per-size stretching |
| Reverse out, then sideways | a full bus backs out of its spot, turns onto the road under the pier and leaves sideways (it never drives through the passenger loop) |
| Long buses and belt garages | l/xl carry 16/40; some late garages show their stack on a conveyor belt (same chained rules, readable visually) |
| Coins + rewarded ads | level wins pay coins; booster refills, extra spots and "clear spots" can be bought or earned with a video |
| World-space HUD (not GUI) for now | one coordinate system, no dependency; swap to Druid inside `view/hud.lua` only |
| Own render script | exact pixel mapping for any window size and orientation |
| Seeded `rng.lua` | the same level everywhere: in tests, in the browser, after a restart |

## Rules for changes

- `modules/sim/*` must stay pure: no `go`, `msg`, `vmath`, `sys`. Lua 5.1 subset (no `//`, no `goto`, no bit ops).
- Tuning goes into `config.lua` or `meta/levels.lua`, never into views.
- New booster or vehicle feature: rules/boosters first, an event for the view, then a test if it can silently break solvability.
- Switching buses rotate inside `rules.send`; the generator and solver must use the same rotation, and a turner's initial angle is never changed mid-disassembly.
- Tests only for logic that breaks silently: geometry, rules, solvability, real-time replay, boosters, difficulty, barriers/turners.
- After any change to rules, templates, generator or the curve: `node tools/tune_levels.js 100`, then the tests.

## Commands

```
node tools/run_tests.js            # sim tests (+ all campaign levels solvable), npm i in tools/ once
node tools/tune_levels.js 100      # re-pick level seeds; TUNE_JOBS=4 by default
node tools/gen_placeholders.js     # regenerate placeholder sprites
node tools/web_smoke.js <bundle> <out>  # headless Chrome check of the HTML5 build
# build check without the editor (bob is inside the editor jar):
"C:/Program Files (x86)/Defold/packages/jdk-25.0.4.1+1/bin/java.exe" -cp "C:/Program Files (x86)/Defold/packages/defold-<sha>.jar" com.dynamo.bob.Bob --root . --output build/bobtest build
```

## Roadmap mapped to modules

| Sprint days | Work | Where |
|---|---|---|
| 1–3 lot core | OBB exits, tap, drive to bay, blocked lurch + honk | geometry, rules, sim, board_view, juice |
| 4–6 loop and boarding | path, crowd slide, machine-gun boarding, depart, Out of Spots, instant restart | path_loop, queue_view, sim, hud |
| 7–9 content and boosters | VIP/Arrange/Jumble, "+" bays, garages, hidden, 30 shaped levels | boosters, templates, level_gen, levels |
| 10–12 web polish and SDK | landscape, juice and sounds, Poki SDK, first player test | layout, audio, ads |
| 13+ party update | reverse departures, one bus scale, long buses, barriers, switching buses, belt stacks, coins | board_view, rules, level_gen, levels, progress |

Status 2026-11-22: MVP + party mechanics, seeds tuned (breather 7%, peak 60%), waiting for a real-device pass. See docs/RELEASE.md.

## Open decisions (for the director)

- Final name (working title "Park & Pop") and a hand-made store icon.
- HUD: keep world-space or move to Druid GUI.
