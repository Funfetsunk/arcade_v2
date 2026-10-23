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
1. **Sim + data**: Resources for catalogs, `GameState`, RNG, `Sim.run_day()`, signals, save/load,
   GUT tests passing against original golden values.
2. **Floor scene**: tilemap room, cabinets, customers/techs with pathing, placement mode
   (drag ghost, tap/click to place, on-screen rotate/place/cancel), camera pan/zoom (drag + pinch +
   mouse wheel), zoom-to-fit.
3. **UI**: Theme, header/HUD, bottom-sheet panels, modals, toasts, log, charts.
4. **Minigames**: port in batches of ~5. Six used keyboard and need touch controls: barrelhop,
   breakout, dance, maze, pinball, racing (swipe/drag, on-screen buttons, lane taps).
5. **Audio, polish, web export, hosting.**

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
