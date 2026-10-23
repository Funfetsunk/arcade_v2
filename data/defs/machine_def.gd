class_name MachineDef
extends Resource
## A machine you can buy: an arcade cabinet or a stock-based amenity.

enum Type { ARCADE, VENDING, FOOD, PRIZES }
enum Audience { NONE, KIDS, TEEN, ADULT, ALL }
enum Special { NONE, JACKPOT, BUZZ }

@export var id: StringName
@export var display_name: String
@export var emoji: String
@export var cost: int
## Max daily earnings at default price and full visitor saturation.
@export var base_earn: float
@export var electricity: int
@export var popularity: int
@export var rep_gain: float
@export var rep_req: int
@export_multiline var description: String
@export var default_price: float
@export var type: Type = Type.ARCADE
@export var audience: Audience = Audience.NONE
@export var special: Special = Special.NONE
## Tile footprint before rotation.
@export var footprint := Vector2i(1, 2)
@export var genre: GenreDef
@export var dip_switches: Array[DipSwitchDef] = []
## The playable minigame behind this cabinet (a MiniGame scene); none for amenities.
@export var minigame: PackedScene

@export_group("Sprites")
## One per facing. Machines without art yet fall back to a tinted placeholder.
@export var sprite_south: Texture2D
@export var sprite_east: Texture2D
@export var sprite_north: Texture2D
@export var sprite_west: Texture2D


func sprite_for(facing: int) -> Texture2D:
	match facing:
		0:
			return sprite_north
		1:
			return sprite_east
		3:
			return sprite_west
	return sprite_south
