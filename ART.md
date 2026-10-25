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

### Customers in the game

Review sheet: `python tools/people_sheet.py . docs/customer_sheet.png <names...>`. Import a finished
PixelLab character (rotations + walk) with `python tools/import_character.py <name>:<character_id>`.
The crowd picks a look by audience (`Crowd.LOOKS`): kids, teens or adults.

| Look | Audience | PixelLab character |
|---|---|---|
| `customer_a` | teen, adult | `9940f4d9-d7bb-4c70-ba6f-35906c6b8489` |
| `customer_teen_jacket` | teen | `7594dda6-80eb-49cf-98bf-b714ff4bce26` (baked foot shadow removed) |
| `customer_teen_hoodie` | teen | `477cf3c6-a53c-4fc0-bc2b-76c0dd95ef76` |
| `customer_teen_punk` | teen | `bf3ead66-703c-4e16-a7e6-e1ece1e122e3` |
| `customer_kid_cap` | kids | `78a65e54-87ac-4cff-9afc-6799528c61e2` |
| `customer_kid_bunches` | kids | `f7ed6370-a814-4bce-b0cd-8d133e7520f8` |
| `customer_adult_cardigan` | adult | `83561712-518c-4fa0-8cd4-0c00c9b32b16` |
| `customer_adult_blazer` | adult | `0ba7890d-aee3-4fd3-83fc-bb9970e7f0f5` |

The seven newer ones came from PixelLab's v3 character mode (32px canvas, 8 directions,
2 generations) and are a few pixels shorter than customer A; walks use the
`walking-6-frames` template (1 generation per direction).

### Staff in the game

Review sheet: `docs/staff_sheet.png`. Repair techs called by the sim wear the junior or senior
tech; roaming staff (techs, security, manager) wear `staff_<role id>`. The cashier and counter
attendant have art ready but don't walk the floor (as in the original); they'll stand at
their counters once facilities are drawn.

| Look | PixelLab character |
|---|---|
| `staff_tech_junior` | `767a2801-fd99-4863-824e-9c46dd6aa5c3` (coloured outline recoloured to the dark outline; tool tips kept grey) |
| `staff_tech_senior` | `0d9b4b12-4e22-4e25-8bf9-95ca9673c8e5` |
| `staff_manager` | `50583e52-23c2-4bb6-a5ac-0c8bc5b92a67` |
| `staff_security` | `67e5eef9-679f-448f-9245-d0fc73b9b7c1` |
| `staff_cashier` | `d32db941-8781-41be-ab79-e6b01443bb9c` |
| `staff_attendant` | `a5a21c4b-0913-490a-bfa4-e89972e43aeb` (redone with a low paper cap; a chef's hat overflowed the 32 px canvas) |

### Making characters

`create_character`, standard mode, `size 32`, 4 directions, view `low top-down`, outline
`single color outline`, shading `basic shading`. Walk: `animate_character` with template
`walking-6-frames` (1 generation per direction). Each character gets a `SpriteFrames` resource
with `idle_<dir>` and `walk_<dir>` animations at 10 fps.

## Walls

Seamless 32 px textures from `create_tiles_pro` (square, top-down, carpet as the style tile),
in `assets/tiles/walls/`. The user picked design F: the 48 px back wall is purple brick (12 px),
a pink neon rail (`neon_rail.png`, rows 11-19 of `neon_stripe.png`), brick (7 px), wood wainscot
(`wainscot_band.png`, rows 16-31 of `wainscot.png`) and 4 px of wood trim. Side and front walls
show navy brick at 60% brightness. `floor/wall_face.gd` draws it; `floor/wall_tint.gdshader`
tones it toward each theme's `wall` hue by its `wall_tint_strength` (Classic Neon: 0, as drawn).
The other textures (navy brick, two wallpapers) are spares. Review with
`python tools/wall_sheet.py . docs/wall_sheet.png` (design F in every theme).

### Neon name sign

Not a sprite: `floor/neon_sign.gd` draws the arcade's name in the pixel font on a dark board
with a 1 px neon frame, in the theme's `sign_color`, with a soft glow and a flicker. The first
Neon Sign bought lights it, centred on the back wall over the neon rail; more Neon Signs hang as
the PLAY sprite. `docs/sign_sheet.png` shows it in every theme (in-game captures).

## Decor and facilities

One-direction objects (`create_1_direction_object`, 16-candidate review pack, a crop of an
approved cabinet as the style image). The canvas sets the size: 68 px gave cabinet-sized props,
so the smaller ones were made on a 44 px canvas. Review with
`python tools/decor_sheet.py . docs/decor_sheet.png`.

| Item | File | Tiles | PixelLab object |
|---|---|---|---|
| Potted plant (a in game; b-d kept for variety) | `decor/plant/{a,b,c,d}.png` | 1 | `a63740b2`, `db557796`, `68ae46ef`, `16c49b5d` |
| Arcade rug (flat) | `decor/rug/a.png` | 2 | `2d4408bc` |
| Bench (backrest moved 1 px right by hand) | `decor/bench/a.png` | 2 | `49586a95` |
| Wall poster (wall) | `decor/poster/a.png` | 1 | `83b2ddb2` |
| Neon sign (wall) | `decor/neon/a.png` | 2 | `68459a4f` |
| Trophy case | `decor/trophy/a.png` | 2 | `232fe8c4` |
| ATM | `decor/atm/a.png` | 1 | `d9ba0a08` |
| Seating area | `decor/seating/a.png` | 2 | `4960d8fe` |
| Restrooms | `decor/toilet/a.png` | 1 | `048e0f27` |
| Water fountain | `decor/water/a.png` | 1 | `6c724a20` |

Each prop's sprite, width, `on_wall` and `flat` live on its `.tres` (`FloorPropDef`). Nothing
about placement is saved: `PropLayout` lays props out along the walls each time the machines
change, and they step aside for machines and the people playing them.

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
- UI frames, icons and a pixel font are still to be generated.

## UI

Rounded slate-blue panels with a 1px light border, cream text, amber highlight for the selected
tab (as in ref A). A pixel font, possibly generated with PixelLab `create_font`.
