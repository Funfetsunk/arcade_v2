extends GutTest
## Rng must match the original mulberry32 exactly. Expected values are the raw
## 32-bit outputs (float × 2^32) produced by the original `sim/rng.ts` in Node;
## comparing integers avoids float-literal rounding in the test itself.

const EXPECTED := {
	1: [2693262067, 11749833, 2265367787, 4213581821, 4159151403],
	12345: [4207900869, 1317490944, 2079646450, 3513001552, 2187978186],
	99: [1118692146, 3456687457, 2323025554, 2964572940, 4890715],
}


func test_matches_original_sequence() -> void:
	for seed_value: int in EXPECTED:
		var rng := Rng.new(seed_value)
		for expected: int in EXPECTED[seed_value]:
			assert_eq(int(rng.next_float() * 4294967296.0), expected, "seed %d" % seed_value)


func test_reseeding_restarts_the_sequence() -> void:
	var rng := Rng.new(7)
	var first := rng.next_float()
	rng.next_float()
	rng.set_seed(7)
	assert_eq(rng.next_float(), first)
