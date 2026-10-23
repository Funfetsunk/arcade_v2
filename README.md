# Arcade Empire (Godot)

A Godot 4.7 web port of [Arcade Empire](https://github.com/agapoar/arcade): build and run your
own arcade, one day at a time. Plays in the browser on desktop and phones.

**Play the test build:** published to GitHub Pages from `main` by
`.github/workflows/pages.yml` (see the repository's Pages URL).

This is a work in progress: the economy, floor and interface are ported; minigames, sound and
most machine art are still to come. See `PORT.md` for the plan and progress, and `ART.md` for
the art direction.

## Developing

- Godot **4.7.2**, GL Compatibility renderer. Open the folder in the editor and press Play.
- Tests: [GUT](https://github.com/bitwes/Gut) in `addons/gut/`. Run them all with
  `powershell -File tests/run_tests.ps1` (Windows) or
  `godot --headless --path . -s addons/gut/gut_cmdln.gd`.
- The Godot MCP Pro addon used during development is a paid, proprietary addon and is not in
  this repository; the project runs and exports without it.

## Credits and licences

Original game by Graham Harbour, Tom Evans and the team (see Credits in the game).
Emoji: [Noto Color Emoji](https://github.com/googlefonts/noto-emoji), SIL Open Font License
(`assets/fonts/NotoColorEmoji-LICENSE.txt`). GUT: MIT (`addons/gut/LICENSE.md`).
