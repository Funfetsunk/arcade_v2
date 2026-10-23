class_name GameMath
extends RefCounted
## Rounding and formatting that behave exactly like the original JavaScript, so
## ported formulas give identical numbers.


## JS Math.round: halves round towards +infinity (-2.5 -> -2), unlike round().
static func js_round(x: float) -> int:
	return floori(x + 0.5)


## Money as the original showed it: "$1,234" / "-$56".
static func money(amount: float) -> String:
	var whole := absi(js_round(amount))
	var digits := str(whole)
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return ("-$" if amount < 0.0 else "$") + digits + grouped


## FNV-1a 32-bit string hash, matching the original daily-challenge seed.
static func hash_string(s: String) -> int:
	const MASK_32 := 0xFFFFFFFF
	var h := 2166136261
	for i in s.length():
		h = (h ^ s.unicode_at(i)) & MASK_32
		h = (h * 16777619) & MASK_32
	return h
