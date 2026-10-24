# Arcade Empire — Art Bible (Godot port)

**Status: style locked 2026-10-23** after the proof batch. Preview it in
`sandbox/art_proof.tscn`.

References live in `docs/reference/` (Godot ignores `docs/` via `docs/.gdignore`):

- `ref_a_cozy.png`: cosy management-sim look. Warm wood trim, purple grid carpet, chibi
  characters, slate-blue rounded UI panels.
- `ref_b_neon.png`: darker, richer neon arcade. Detailed cabinets with lit screens and side art,
  galaxy-pattern carpet, brick walls, big neon signage, varied machine shapes.

Upscaled previews of the approved proof sprites are in `docs/art_candidates/`.

## The mix

Take from **B**: the machines. Detailed cabinets with lit CRT screens, marquees, side art and
distinct silhouettes per machine type, plus neon wall signs.

Take from **A**: readability and warmth. A calm purple carpet, warm wood counters and trim,
rounded slate-blue UI panels, cosy decor (plants, sofas, posters).

Overall: a dark navy/purple room lit by neon, with warm wood accents. The floor stays quiet so it
doesn't pull the eye away from machines and people.

## Approved proof set (the style anchors)

| Asset | File(s) | PixelLab source |
|---|---|---|
| Carpet floor | `assets/tiles/carpet.png`, TileSet `assets/tiles/floor.tres` | tiles-pro `94904300-1ab8-4962-b1d7-29ae349fcac3`, tile 8 |
| Upright cabinet `space_inv`, 4 facings | `assets/sprites/cabinets/space_inv/{south,east,north,west}.png` | 8-direction object `775bb75e-1c4a-4f97-8bbf-c83309c0b50e` |
| Customer A, idle + 6-frame walk, 4 directions | `assets/sprites/actors/customer_a/`, SpriteFrames `customer_a_frames.tres` | character `9940f4d9-d7bb-4c70-ba6f-35906c6b8489` |

Accepted differences from the first draft: the customer has normal (not chibi) proportions and a
dark outline. Keep that for all characters so they match.

## Camera and grid

- Top-down with a slight 3/4 front tilt (PixelLab view `low top-down`). Orthographic, not isometric.
- **32px tiles in the art.** The original game runs on a 16px grid; gameplay logic stays in tile
  units, so the art is drawn at 2× the original detail without changing the geometry.
- Starting room is 16×10 interior tiles plus a 1-tile wall band (576×384 px at 32px).

## Sprite sizes

| Subject | Canvas | Notes |
|---|---|---|
| Upright cabinet | 68×68 per facing | Cabinet itself is ~28×52 (front) / ~30×52 (side). Anchor: bottom-centre, `offset = (0, -28)`. |
| Wide machines (pinball, air hockey, racers) | 68×68 or larger, per facing | Decide per machine when generated. |
| Customer / staff | 48×48 per frame | Character ~32px tall. Anchor: feet, `offset = (0, -20)`. |
| Floor tile | 32×32 | Seamless. |

## Every machine has 4 facings

Machines rotate on the floor, so like characters they need south/east/north/west sprites.
South is the front (screen facing the viewer); east/west are fully side-on; north is the back.

Pipeline per machine (~11 generations):

1. Generate the **front view** (`create_image_pixflux`, 32×64, transparent, palette swatch below
   as `color_image_base64`). Make 2 seeds, pick the best.
2. Pad it onto a 64×64 transparent canvas, centred, touching the top edge.
3. `create_8_direction_object` with that image as `reference_image_base64` and view
   `low top-down` (10 generations). Keep south/east/north/west; the diagonals are spare.

### Review sheet

`python tools/cabinet_sheet.py . docs/cabinet_sheet.png` draws every machine in all four
facings on the carpet. Art saved under `assets/sprites/cabinets/<id>/` but not yet referenced by
the machine's `.tres` shows as NEW - REVIEW; wire it in only after the user approves the sheet.

### Cabinets in the game

Side views must be fully side-on with the control box sticking out at the front. To
regenerate a cabinet to match, pass an approved cabinet's object as `style_object_id`
to `create_8_direction_object` along with the front-view reference (pick one whose side
art won't leak in).

| Machine | PixelLab 8-direction object |
|---|---|
| `space_inv` | `24f742e2-f9f7-4ec2-ae91-c01b92cc1e22` (style: rhythm object) |
| `pac` | `22232afc-401e-4f50-adea-e1d44fadf680` (style: space_fleet object) |
| `breakout` | `29fabf9d-33dd-4181-bf77-6216db04488a` (style: space_fleet object) |
| `pong` | `91834203-9287-4632-a6e6-4bad91209f0c` |
| `fighter` | `d0b926b5-3e97-4ded-a3a8-b55b380c3bcd` |
| `gorilla` | `4a79a195-7c6a-4997-b4cd-de9f722aaf1f` |
| `space_fleet` | `0d424f89-aa89-42a9-aa52-5da462e9f1ff` |
| `shooter` | `3ba1a701-e1f5-4acb-a3fa-7f291267ea79` |
| `trivia` | `27c2d890-7bd4-4150-9e19-d78a4cbb7361` |
| `rhythm` | `ba395826-eda7-4be3-b23b-580d28119eff` |
| `vending` | `21830ed6-a099-43ce-9b66-e77668faf1ff` |
| `air_hockey` | `612fbab7-3a0d-4a47-b71f-b8064043dd3d` |
| `basketball` | `b851f445-086f-48ac-bcd3-7d0464cc3409` |
| `claw` | `bb9335a5-8ba7-4e00-bc04-84ca5a2b90b7` |
| `coin_push` | `8443eafb-f5ba-42e3-a1c0-fe5a5162bd58` |
| `crane` | `9029bf8b-e95a-4867-84a7-92a86349bf75` |
| `ddr` | `42680036-6187-4fc6-9f7c-b2b5896a0cec` |
| `food_counter` | `9d15cadd-c407-48b9-868a-56408b80b762` |
| `jackpot_machine` | `9b91d0ad-8cd9-48da-8862-c1ac69d2a5dc` |
| `motion_sim` | `8f86406d-77f3-43d1-8bae-26f569e18d4e` |
| `photo_booth` | `66bbe1d7-98c3-4f6f-9282-6a920aeae776` |
| `pinball` | `00ae3c39-d1a6-4338-a55a-afb0e7e2a600` |
| `prize_counter` | `5a4026d8-b554-433a-a94f-b95ef6901bb2` |
| `racing` | `87b63d95-e08d-410f-a1cf-038d626488ad` |
| `skee` | `01ae8262-b8a6-4bb8-a0d6-d5c6c1b43eaf` |
| `social_hub` | `46f13c11-367b-4390-8414-a7badf527c54` |
| `vr` | `56b7f39d-70a7-42fb-8d29-c35e18148298` |
| `whack` | `857a7794-96ba-49a0-8b2d-fedc217c34ee` |

## Characters

`create_character`, standard mode, `size 32`, 4 directions, view `low top-down`, outline
`single color outline`, shading `basic shading`. Walk: `animate_character` with template
`walking-6-frames` (1 generation per direction). Each character gets a `SpriteFrames` resource
with `idle_<dir>` and `walk_<dir>` animations at 10 fps.

## Palette

Sampled from the references; generate roughly in this family. Neon accents are approximate.

```
Floor / shadow   #090d1c #0f1321 #20243b #2c4258 #332950 #393a68
Wall / brick     #452e47 #51353a #613a44 #6d475e #8a5a5f
Wood trim        #5c3d1e #aa6622 #c8956b
UI slate         #2b364d #344459 #555775 #86857f
Cream highlight  #d6c9a9 #bda592
Neon accents     #ff4f7b (pink) #4fd8ff (cyan) #ffb703 (amber) #7cff6b (green) #c77dff (purple)
Skin tones       #f5cba7 #c8956b #8d5a3b #5c3d1e
```

## Prompt prefix for every PixelLab generation

> `cozy neon arcade pixel art, top-down view with slight front tilt, dark navy and purple
> palette with glowing neon accents and warm wood, crisp pixels, no anti-aliasing,
> soft top-left light, dark outline on objects, [SUBJECT]`

## Known follow-ups

- One carpet tile repeats visibly over a big floor. Before the floor scene ships, generate 2–3
  variants of carpet 8 (tiles-pro with `carpet.png` as `style_images`) and scatter them.
- Walls, decor, facilities, UI frames, icons and a pixel font are still to be generated.

## UI

Rounded slate-blue panels with a 1px light border, cream text, amber highlight for the selected
tab (as in ref A). A pixel font, possibly generated with PixelLab `create_font`.
