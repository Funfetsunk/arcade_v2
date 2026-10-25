class_name Icons
extends RefCounted
## The UI's pixel icons (assets/ui/icons/, picked on docs/icon_sheet.png) and
## sprite thumbnails for list cards: a machine, staff member or prop shown by its
## own art, trimmed to its pixels.

const DIR := "res://assets/ui/icons/%s.png"

static var _icons: Dictionary[StringName, Texture2D] = {}
static var _trimmed: Dictionary[Texture2D, Texture2D] = {}


static func named(id: StringName) -> Texture2D:
	if not _icons.has(id):
		_icons[id] = load(DIR % id)
	return _icons[id]


## The mood face for a satisfaction score (same bands as UiKit.mood_face).
static func mood(satisfaction: float) -> Texture2D:
	if satisfaction >= 85.0:
		return named(&"mood_great")
	if satisfaction >= 68.0:
		return named(&"mood_good")
	if satisfaction >= 45.0:
		return named(&"mood_ok")
	if satisfaction >= 28.0:
		return named(&"mood_low")
	return named(&"mood_angry")


## A texture cropped to the pixels it uses, so sprites on big canvases don't
## shrink to a speck in a thumbnail.
static func trimmed(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	if not _trimmed.has(texture):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(FloorProp.used_rect(texture))
		_trimmed[texture] = atlas
	return _trimmed[texture]


## A staff role's character, facing the viewer.
static func staff(role: StaffDef) -> Texture2D:
	return trimmed(load("res://assets/sprites/actors/staff_%s/idle_south.png" % role.id))


## A machine's front view.
static func machine(def: MachineDef) -> Texture2D:
	return trimmed(def.sprite_for(MachineInstance.Facing.S))
