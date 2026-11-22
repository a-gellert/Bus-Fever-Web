# Park & Pop

Web-first parking puzzle for HTML5 portals (Poki first). Tap a vehicle whose way out is clear. It parks at the stop, and passengers of its colour hop in. Keep the stop from filling up with the wrong colours.

- Engine: Defold 1.14, HTML5 (wasm-web), Poki SDK extension 4.1.0 (pinned)
- Bundle: about 3.3 MB downloaded by the player
- Portrait and landscape, mouse and touch
- Every campaign level can be finished without boosters (checked by tests)
- Party mechanics: long 16/40-seat buses, two garages, belt stacks, hidden colours, static barriers, switching buses, 8 waiting spots, coins
- Filled buses reverse out of the spot and leave along the road; every bus keeps its own length (no stretching to fit a slot)

## Run

Open `game.project` in the Defold editor and press Build (Ctrl+B).

Dev options (engine `--config=...`; in the browser smoke test as `?arg=--config=...`):

| option | effect |
|---|---|
| `bus.start_level=N` | start at level N |
| `bus.dev_popup=1` | open the Out of Spots popup right away |
| `bus.dev_popup=2` | open the "+1 slot" video offer |
| `bus.autoplay=1` | the game plays itself with the solver plan (smoke tests) |

## Tools

```
cd tools && npm install           # once: fengari (Lua in Node) for tests
node tools/run_tests.js           # sim tests: geometry, rules, mechanics, solvable levels, real-time replay, boosters, difficulty
node tools/tune_levels.js 100     # re-pick level seeds against the difficulty targets (minutes)
node tools/gen_placeholders.js    # regenerate sprites
node tools/gen_sounds.js          # regenerate sound effects
node tools/web_smoke.js <bundle dir> <out dir>   # headless Chrome: screenshots, console errors, autoplay clears levels
```

HTML5 bundle without the editor (bob ships inside the editor jar):

```
J="C:/Program Files (x86)/Defold/packages"
"$J/jdk-25.0.4.1+1/bin/java.exe" -cp "$J/defold-<sha>.jar" com.dynamo.bob.Bob \
  --root . --platform wasm-web --archive --variant release --bundle-output ../bus-web resolve build bundle
```

The bundle output must be outside `build/`. Test it with `tools/web_smoke.js`: it runs headless, so no window opens on the desktop.

## Docs

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): modules, data flow, decisions
- [docs/RELEASE.md](docs/RELEASE.md): Poki submission checklist and status
- [AGENTS.md](AGENTS.md): rules for coding agents

## Credits

- Font: Lilita One by Juan Montoreano, SIL Open Font License 1.1 (`assets/fonts/OFL.txt`)
- Sprites and sounds: generated procedurally by `tools/gen_placeholders.js` and `tools/gen_sounds.js`
