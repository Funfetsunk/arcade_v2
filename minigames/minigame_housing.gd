class_name MinigameHousing
extends Resource
## The machine a minigame is played in: an upright cabinet, a table, a glass prize
## case. The art is drawn at board scale around the 360x460 board, with the game's
## name lit in its marquee or sign (or above, when it has none).

@export var texture: Texture2D
## Where the board sits in the art, in art pixels (its size is the board's).
@export var screen := Rect2i(0, 0, 360, 460)
## The marquee panel the game's name is centred in.
@export var title_rect := Rect2i()
@export var title_color := Color("ffd166")
## A scoreboard on the machine that shows the live score (empty: none).
@export var score_rect := Rect2i()
@export var score_color := Color("ffd166")
## Shown down both sides when there is room (mirrored on the right).
@export var side_art: Texture2D
## The art is the playing surface (a table, a lane): the board draws on top of
## it with no background. Otherwise the art frames the board from above.
@export var board_on_top := false
