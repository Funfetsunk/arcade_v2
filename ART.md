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
