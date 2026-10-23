class_name Rng
extends RefCounted
## Seedable mulberry32 PRNG, bit-for-bit identical to the original game's
## `sim/rng.ts`. The sim draws from this instead of Godot's RNG so a fixed seed
## reproduces the original's day results exactly (the golden tests rely on it).

const MASK_32 := 0xFFFFFFFF

var _state: int = 1


func _init(seed_value: int = 1) -> void:
	set_seed(seed_value)


func set_seed(seed_value: int) -> void:
	_state = seed_value & MASK_32


## Returns a float in [0, 1).
func next_float() -> float:
	_state = (_state + 0x6d2b79f5) & MASK_32
	var t := _state
	t = _imul(t ^ (t >> 15), t | 1)
	t = (t ^ (t + _imul(t ^ (t >> 7), t | 61))) & MASK_32
	return float((t ^ (t >> 14)) & MASK_32) / 4294967296.0


## JS Math.imul on unsigned 32-bit operands: the low 32 bits of the product.
## The 64-bit product may wrap, but wrapping keeps the low 32 bits intact.
static func _imul(a: int, b: int) -> int:
	return (a * b) & MASK_32
