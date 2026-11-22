# Release checklist (Poki)

Status 2026-11-22: MVP + party mechanics. Checked headlessly; no real-device test yet.

## Done

- [x] Poki SDK through `modules/platform/ads.lua` only, extension pinned to 4.1.0
- [x] `gameplay_start` on the first board tap; `gameplay_stop` on win, on Out of Spots and before every ad
- [x] Interstitial only between levels, from level 5, at most once per 150 s; a rewarded video counts as the break
- [x] Rewarded only on the player's request: "+" bays (with a confirm popup), boosters at 0 stock, rescue options; no ad overlap
- [x] Audio muted during ads
- [x] Zero-friction start: level 1 opens directly, with a tutorial hand on the right bus
- [x] Levels 1–3 can't be lost; levels 1–6 have one free rescue
- [x] Every campaign level is solvable without boosters, also for a fast real-time player (`tests/test_replay.lua`)
- [x] Sawtooth difficulty, tuned per level (casual-player fail rate: breather 7%, rising 13/26/37%, peak 60%)
- [x] Portrait and landscape layouts; 360x640 phone checked
- [x] Party mechanics: up to 8 waiting spots, two garages, belt stacks, hidden colours, static barriers, switching buses, long 16/40-seat buses, limousines
- [x] Filled buses reverse out of the waiting spot, turn onto the road and leave sideways
- [x] One shared bus scale in the waiting row: short buses are not stretched to fill a slot
- [x] Coins for level wins; booster refills, extra spots and "clear spots" for coins or a rewarded video
- [x] Own name, palette, font and UI (Poki "inspired, not imitated")
- [x] Bundle: about 1.7 MB gzipped / 3.3 MB raw for the browser (single-threaded wasm)
- [x] Headless smoke on the HTML5 build: no console errors, autoplay clears levels (`tools/web_smoke.js`)
- [x] Licenses: Lilita One (OFL, `assets/fonts/OFL.txt`); all other art and audio generated in-repo

## Before upload

- [ ] Final name: "Park & Pop" is a working title. Check that it is free on Poki and in the stores.
- [ ] Hand-made 512/628 px icon. `docs/store/thumb_*.png` are gameplay crops that can stand in.
- [ ] Release bundle: `--variant release` (see README). Upload the folder that holds `index.html`.
- [ ] Test on a real phone (touch, high-DPI, audio unlock) in the Poki Inspector.
- [ ] Player Fit Test, then tune `modules/meta/levels.lua` with real fail rates. Telemetry: `ads.measure` level start/complete/stuck/restart, booster and rescue use.

## Store material

`docs/store/`: `thumb_628.png`, `thumb_314.png`, `screenshot_portrait.png`, `screenshot_phone.png`, `screenshot_landscape.png`.
