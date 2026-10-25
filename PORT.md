# Arcade Empire → Godot port plan

Handoff from the planning session (2026-10-23). Read this before starting port work.

## Goal

Rewrite **Arcade Empire** (https://github.com/agapoar/arcade, v0.30.0, Vite + TypeScript) as a
**Godot 4.7 web app**: exported with Godot's Web export and hosted on a website to play in the browser.

Order of work:
1. **Straight port with improved visuals** — feature parity with v0.30.0, new PixelLab art. No new
   gameplay, no rebalancing.
2. Then improvements, testing, new features.

## Decisions

| Topic | Decision |
|---|---|
| Engine | Godot 4.7.2 (`C:\Users\evans\Documents\Dev\Godot_v4.7.2-stable_win64.exe`) |
| Language | GDScript (not C#) |
| Architecture | Godot-native: custom `Resource` classes + `.tres`, scenes, signals, autoloads, `Theme`. Not "everything in scripts". |
| Platform | Web (browser). No native iOS/Android builds. |
| Input / layout | Touch-first, also fully usable with mouse (and keyboard where the original had it). Adapts to portrait phone and landscape desktop. |
| Art | PixelLab sprites from the start (no procedural cabinet drawing). Style anchored on a reference image the user supplies. |
| Renderer | GL Compatibility (only renderer supported on web). Nearest texture filtering. |
| Hosting | Not chosen yet (original used Azure Static Web Apps; itch.io / GitHub Pages / Netlify also fine). |

## Tooling

- **Godot MCP Pro v1.17.1** — server at `C:\Users\evans\Documents\Dev\godot-mcp-pro-v1.17.1\server`,
  addon in `addons/godot_mcp/` (enabled), configured in `.mcp.json`, approved in
  `.claude/settings.local.json`. Godot editor must be open on this project for it to connect.
- **PixelLab MCP** — Tier 2, 5000 generations/cycle, resets ~21st monthly (3,920 left on 2026-10-23).
- Write `.gd` scripts as plain files (diffable); use Godot MCP for scene building, running, errors,
  screenshots.
- **Godot MCP Pro is proprietary (no redistribution).** It is git-ignored, was stripped from the
  history on 2026-10-23, and is excluded from the web export. Never commit it. The local
  `backup/before-addon-strip` branch still contains it: never push that branch; delete it once
  the public repo is set up.
- **GitHub Pages test build:** `.github/workflows/pages.yml` runs the tests, exports the web build
  and deploys it on every push to `main`. One-time setup: repo Settings → Pages → Source:
  "GitHub Actions".

## Source repo overview

Clone it fresh to a scratch dir to read: `git clone --depth 1 https://github.com/agapoar/arcade.git`

~8.2k lines of TS:

- `src/main.ts` (~3,670 lines, `@ts-nocheck`) — view layer: canvas renderer, pathing, placement,
  UI panels, input, goals check. Biggest job.
- `src/sim/advanceDay.ts` — `runDay()`: DOM-free day resolution (events → earnings → degradation →
  repairs → costs). Talks to the view through `configureSim({log,toast,resetCustomers,spawnCoin,
  spawnRepairWorker,refresh})`.
- `src/sim/rng.ts` — seedable mulberry32. Port exactly so seeded results match.
- `src/state.ts` — global `G` state, economy helpers (rent/elec/wages/footfall), `makeMachine`,
  save/load (localStorage `ae_save`).
- `src/data/*.ts` — ~25 catalogs: machines, upgrades, staff, events, dips, loans, stock, goals,
  achievements, calendar, contracts, daily, decisions, decor, facilities, genres, marketing, meta,
  perks, research, rival, scenarios, themes, tournaments, towns, weather.
- `src/scene/` — layout (room geometry, slots, door, aisles), placement, zones, sprite loader.
- `src/minigames/` — 25 bespoke minigames (50–155 lines each) + `index.ts` registry (catalog id →
  game) + `shared.ts` (360×460 overlay canvas, pointer mapping, result screen).
- `src/sfx.ts` — synthesized Web Audio SFX.
- `tests/` — 19 Vitest files (economy golden values, layout, placement, zones, etc.). These are the
  correctness oracle for the sim port.
- `ART.md`, `PixelArt.md` — original art bible and prompts. `public/assets/sprites/` + `assets/raw/`
  — existing art (reference only; new art comes from PixelLab).
- `CLAUDE.md`, `HANDOVER.md`, `handoffs/` — original team docs; useful context on design intent.

## Godot mapping

| Original | Godot |
|---|---|
| `data/*.ts` catalogs | Custom `Resource` classes (`MachineDef`, `StaffDef`, `UpgradeDef`, `EventDef`, `GenreDef`, …) saved as `.tres`; one catalog resource per type. |
| `G` state | `GameState` Resource with `MachineInstance` sub-resources; save/load via `ResourceSaver`/`ResourceLoader` to `user://` (IndexedDB on web). |
| Globals | Autoloads: `Game` (state + day loop), `EventBus` (signals). |
| `configureSim` callbacks | Signals. |
| `runDay()` | Pure-data `Sim` class, no scene dependencies; testable in GUT. |
| Room floor/walls | `TileMapLayer` + `TileSet` resource. |
| `tilePath` / `walkRoute` | `AStarGrid2D`. |
| Customers / techs / cabinets | Scenes: `Customer.tscn`, `Technician.tscn`, `Cabinet.tscn`; `AnimatedSprite2D` + `SpriteFrames` resources; `Tween` for motion. |
| HTML panels (shop, staff, loans, stock, goals, log, charts, visitor popup) | `Control` scenes + shared `Theme.tres` (port the warm-UI palette from `index.html`). |
| Minigame registry | `MiniGame` base scene; each game its own scene; `MachineDef.minigame_scene: PackedScene`. |
| `sfx.ts` | `AudioStream` resources (render synthesized SFX to `.wav`, or `AudioStreamGenerator`). |
| Vitest | GUT tests; match `sim.test.ts` golden numbers. |

## Phases

0. **Setup** (done 2026-10-23, except export templates):
   - git repo (`main`), `.gitignore` (`.godot/`, `/build/`, local Claude settings), `.gitattributes` (LF).
   - Display: base 640×360, stretch `canvas_items`, aspect `expand`, scale mode `fractional`,
     snap 2D transforms to pixel, nearest filtering, desktop test window 1280×720.
     Integer scaling deliberately **not** on yet: on a high-DPI portrait phone it floors to 1× and
     makes everything tiny. Revisit after the art proof (likely a runtime UI scale from screen DPI).
   - Web export preset `Web` → `build/web/index.html`, single-threaded, no extensions, `*.md` excluded.
     MCP addon autoloads disable themselves outside the editor, so they're harmless in exports.
   - Export templates for 4.7.2 not installed yet (Editor → Manage Export Templates → Download).
   - Folders: `core/` (autoloads, Sim, RNG, GameState), `data/defs/` (Resource class scripts),
     `data/catalogs/` (.tres), `floor/`, `actors/`, `ui/` (+ `ui/theme/`), `minigames/`,
     `assets/{sprites,tiles,audio,fonts}/`, `tests/` (GUT, installed in phase 1).
1. **Sim + data**, split in two:
   - **1a (done 2026-10-23):** every catalog is a Resource class in `data/defs/` with one `.tres`
     per entry in `data/catalogs/`, all gathered in `data/catalogs/game_data.tres` (`GameData`,
     with id lookups). Tunables live in `game_balance.tres`. Runtime state is `GameState` plus
     `MachineInstance` / `StaffInstance` / `StockSlot` / `LoanState` / `DayBuff` in `core/state/`.
     `Rng` (bit-exact mulberry32), `Economy`, `GameMath` (JS-style rounding), and `Sim.run_day()`
     with signals live in `core/`. Autoloads: `Data`, `EventBus`, `Game`. `SaveSystem` writes
     `user://save.tres`. GUT 9.7.1 is in `addons/gut/` (tests excluded from export).
     Run tests: `powershell -File tests/run_tests.ps1`. 50 tests pass, including
     `test_sim_parity.gd`, which checks the Godot sim day by day against the original
     TypeScript sim on 4 setups (fixture made by running the original in Node).
     The original catalogs were converted once by a script; the `.tres` files are now the source.
     Dropped: `DECOR_SPOTS` / `FACILITY_SPOTS` (pixel positions for the old 3×3 layout; phase 2
     places decor on the grid).
   - **1b (done 2026-10-23):** the day loop and player actions from `main.ts`.
     `DayCycle` (`core/day_cycle.gd`) is `runDayNow()` and everything it called, in the same
     order: weekday rhythm, promos, weather, rival, the sim, goals, achievements, tickets,
     ATM, franchises, jackpot/buzz, aging, auto-stockers, staff morale, satisfaction,
     scenario win, then the campaign / tournament / weather / daily / rival / contract ticks,
     plus pre-day decision events. `Actions` (`core/actions.gd`) has every player action
     (buy/move/sell/repair/refurbish/tune-up/reinforce/price/DIP/stock/restock, expand,
     upgrades, facilities, decor, staff hire/fire/train, loans, campaigns, discount,
     tournaments, rival price war, contracts, research, franchises, perks, difficulty).
     Both extend `GameSystem` and report via signals; `Game` relays everything to `EventBus`
     and owns `next_day()` / `choose_decision()`, new game / daily / restart / prestige, and
     save + `MetaProgress` (prestige, perks, achievements, leaderboard, daily bests →
     `user://meta.tres`). The original's `Math.random()` calls use a separate `world_rng`,
     so the sim's seeded stream is unchanged.
     `test_day_parity.gd` replays 5 scripted games (228 days, 50+ decisions, most actions)
     against the original `main.ts` functions run in Node with a seeded `Math.random`, and
     matches every number and every log line. 65 tests, ~21k checks.
     Not ported here (belongs to later phases): placement validity and themed zones
     (phase 2, with the grid), the tutorial, share card, jukebox and sound effects.
   - Dev note: the editor shows a modal "Files have been modified outside Godot" after
     scripts change on disk (my edits, headless test runs), and while it's open the Godot MCP
     can't talk to a running game. Enable Editor Settings → Text Editor → Behavior → Files →
     "Auto Reload Scripts on External Change" to avoid it.
2. **Floor scene** (first pass done 2026-10-23; `main.tscn` is the main scene):
   - `core/floor_grid.gd`: the original layout/placement/zones rules in tile units (footprint,
     base and stand tiles, `can_place`, auto-layout, themed-zone bonus), with the original tests
     ported. `Actions` recomputes zones on buy/move/sell; `Game` lays out scenario machines.
   - `floor/floor.tscn` (`ArcadeFloor`): carpet `TileMapLayer`, `Room` (walls drawn in the
     theme colour as a placeholder until wall art), y-sorted `Cabinet` scenes using
     `MachineDef.sprite_*` per facing (machines without art borrow the space_inv sprites tinted
     by genre), `Crowd` (customers queue/play/leave, VIP tips, star buzz, repair techs called by
     the sim, roaming staff), `WalkGrid` (AStarGrid2D + string-pulled any-angle legs),
     coin pops, `FloorCamera` (drag pan, wheel and pinch zoom, fit; minimum zoom = fit).
   - Placement mode: drag the ghost (green/red with footprint and stand tile), `PlaceBar`
     (Rotate ←/→, Place, Cancel; R/Enter/Escape on keyboard). Tap a machine to select it
     (`EventBus.machine_selected`). Touch is handled directly; emulated mouse events are ignored.
   - `sandbox/debug_hud.tscn` is a TEMPORARY HUD (next day, buy, move, sell, decisions) until
     phase 3's real UI replaces it.
   - Not done yet: customer emotes and the visitor popup (need UI/icon art), floor staff and
     tech art (tinted customer sprite for now), theme sign. (Decor and facility props on the
     floor and back wall came later: `PropLayout` + `floor/prop_layer.gd`.)
   - The MCP plugin adds its three autoloads to `project.godot` when the editor starts and
     removes them on exit or plugin reload; if a game run from the editor stops answering the
     MCP, reload the plugin.
3. **UI** (first pass done 2026-10-23):
   - Base viewport is now **360×360 with aspect expand**: desktop 1280×720 shows 640×360
     logical px, a portrait phone about 360×780, so one text size reads on both.
   - `ui/theme/arcade_theme.tres` (project theme): slate panels, amber primary buttons, type
     variations (HeaderLabel, StatValue, PrimaryButton, DangerButton, TabButton, CardPanel,
     SheetPanel, ToastPanel, BarPanel). Pixel font `assets/fonts/arcade_empire_pixel.ttf`
     (PixelLab, ASCII only, falls back to the default font) for headings/numbers; the default
     font for body text.
   - `ui/game_ui.tscn` (`GameUI`): top bar stats, action bar (Floor/Shop/Staff/Books + Next
     Day), `BottomSheet` hosting the panels, toasts, event log, repairs button, `Modal`
     (decisions, confirmations, victory / scenario win / daily complete). `UiKit` builds cards
     and rows. Panels in `ui/panels/`: shop (machines, upgrades), staff, floor (machines,
     expand room), books (yesterday, running costs, totals, loans), machine (status, price
     with demand hint, upgrades, stock, DIP switches, move/repair/refurbish/sell).
   - Second pass (done 2026-10-23): the MENU sheet and every screen it opens (how to play,
     scenarios, daily challenge, marketing, contracts, research, franchises, decor, progress,
     achievements, leaderboard, credits); Books now matches the original (goals, snapshot,
     loans, reputation tier, metrics, machine charts with period/metric toggles and rank
     arrows); the visitor popup (tap a customer); how-to-play on a first run; a compact
     action bar below 480 px wide.
   - Emoji on the web: `assets/fonts/noto_color_emoji_subset.ttf` is Noto Color Emoji (OFL,
     licence beside it) cut down to the ~160 characters the game uses (371 KB), set as the
     fallback for the default and pixel fonts. After adding new emoji, re-cut it with
     `tools/subset_emoji_font.py` (instructions at the top of the script). Verified in a real web export in the
     browser, desktop and 375×812 phone.
   - Still to do (later phases): customer emotes, sound, the jukebox in Decor.
   - `tests/run_tests.ps1` restores `project.godot` after its headless import, because the
     headless editor's MCP plugin strips its autoloads on exit.
4. **Minigames**: port in batches of ~5. Six used keyboard and need touch controls: barrelhop,
   breakout, dance, maze, pinball, racing (swipe/drag, on-screen buttons, lane taps).
   - Framework (done 2026-10-23): `minigames/minigame.tscn` + `MiniGame` base (title, HUD,
     quit/done, results screen; fixed 360×460 board scaled to fit; logic in `_tick()` at 60
     ticks/s like the original's per-frame steps; pointer input in board coordinates, same for
     touch and mouse; drawing helpers incl. emoji glyphs). Each game is its own inherited
     scene in `minigames/<game>/`, linked from `MachineDef.minigame`; the machine panel shows
     🎮 PLAY. `Actions.award_minigame` pays min(180, round(score × 0.4)) + score/20 buzz.
     `tests/test_minigames.gd` boots every linked game and plays 20 s of random taps.
   - Batch 1 (done): breakout (drag, hover or ← →), whack, pong, invaders, claw.
   - Batch 2 (done): aim (skee), airhockey, hoops (hold to charge, release to shoot — the base
     now has a pointer-release hook), lightgun (shooter), crane.
   - Batches 3–5 (done): coinpush (endless; quitting banks the score), slots, snap, starsquad,
     racing (hold a half to steer) · vrpod, motionsim, barrelhop, dance, rhythm · carsmash,
     maze (swipe), quiz, social, pinball. All 25 cabinets now have their game; amenities
     (vending, food counter, prize booth) have none, as in the original.
   - Changes from the original: the quiz's answer buttons are drawn on the board instead of
     sitting under it, with larger text for phones; the board clips its contents like the
     original canvas did; the riff master's note beeps wait for the audio phase.
   - `MiniGame` gained `_draw_results()` (drawing over the results screen, e.g. the photo
     strip) and a tint for `glyph()`.
5. **Audio, polish, web export, hosting.**
   - Sound (done): the original synthesized everything live with Web Audio (`sfx.ts`).
     `tools/render_sfx.py` renders the same oscillators, envelopes and filtered noise to
     `assets/audio/*.wav` (imported QOA-compressed; loops set to forward in the `.import`
     files): coin, buy, day, break, click, error, goal, ambient bleeps, Riff Master's beeps,
     the arcade hum, the crowd murmur and the four jukebox tracks.
   - `Sfx` autoload (`core/sfx.gd`) plays them on the SFX / Ambience / Music buses
     (`default_bus_layout.tres`; master at the original's 0.6). Ambience and music start on
     the first tap, with the original's "sound on" ding. The murmur follows the crowd size.
   - Cues: `GameSystem` emits `purchased` / `refused` / `celebrated` where the original
     played buy / error / goal; the rest come from existing EventBus signals and the UI
     (clicks on confirms, the tutorial, the placing bar, visitor taps, toggles).
   - 🔊 / 🔇 button at the right of the top bar; jukebox in Decor. Both are remembered in
     `MetaProgress` (`sound_muted`, `jukebox_track`).
   - Customer emotes (done): `EmoteBubble` (child of each Customer, drawn above every walker)
     shows the original's thought bubbles: on arriving to play (VIP / star / prize-corner /
     general sets), when stuck far back in a queue, and crowd-wide reactions to jackpots,
     contracts, tournaments, the empire win and breakdowns (`Crowd.react`). With no bubble
     it shows the persona badge (🎩 VIP, pulsing ⭐ star). The visitor popup lists the thought.
   - Share card (done): `ShareCard` renders the run summary (name in the theme's sign colour,
     scenario, day, prestige, six stats, machine strip) in an off-screen SubViewport;
     `JavaScriptBridge.download_buffer` saves it on the web, `user://share/` elsewhere.
     Buttons on the victory and scenario-win dialogs and the leaderboard, as in the original.
   - Confetti (done): `Confetti` overlay in the UI layer (under the panels) bursts for goals,
     achievements, jackpots, franchises (70) and prestige (150) via `celebrated(confetti)`,
     the empire win, scenario wins, daily completes, contracts and tournaments, with the
     original's counts.
   - Loading screen (done): `tools/make_splash.py` draws `assets/ui/splash.png` (title over a
     row of cabinets), used as the boot splash and by the web loader with its progress bar.
   - Fresh builds (done): `tools/cache_bust.py` runs after the CI export and renames the
     engine files to `game-<commit>.*` (index.html points at them), so a deploy is never hidden
     by Pages' 10-minute browser cache.
   - Sfx finds Game at runtime: the machine catalogs load minigame scenes that call Sfx, so
     a static `Game` reference in it would make a Data → Sfx → Game → Data load cycle.

## Art workflow

1. User supplies an overall art-style reference image.
2. Lock style (palette, outline, shading, 3/4 top-down angle) into a new `ART.md` here.
3. Proof batch first — 1 cabinet, 1 customer with 4-direction walk, 1 floor tile — user approves.
4. Full set: 25 cabinets, 5 customer types, 2 tech types, floor/wall tileset, decor, facilities,
   UI frames, icons, possibly a pixel font (`create_font`). Budget ~400–800 generations.

## Web / touch rules

- Tap targets ≥ 44px at phone size; panels as bottom sheets; never rely on hover or right-click alone.
- Audio starts only after first click/tap.
- Autosave on day end and on `NOTIFICATION_APPLICATION_FOCUS_OUT` / page hide.
- Keep download size (wasm + pck) small; cap simultaneous customers on screen.
