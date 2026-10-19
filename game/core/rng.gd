class_name Rng
extends RefCounted
## A tiny deterministic random number generator (xorshift32) that gives the
## same sequence on every platform: only 32-bit shifts and xors, no floating
## point state and no engine RNG. The daily run, the spawn director and the
## upgrade offers all draw from their own Rng so that one stream never
## disturbs another.

const MASK: int = 0xFFFFFFFF

var state: int = 1


func _init(seed_value: int = 1) -> void:
	state = hash32(seed_value)
	if state == 0:
		state = 0x9E3779B9


## Mixes an integer into a well-spread 32-bit value (no overflow: every
## product stays below 2^59).
static func hash32(x: int) -> int:
	x = x & MASK
	x = (((x >> 16) ^ x) * 0x45d9f3b) & MASK
	x = (((x >> 16) ^ x) * 0x45d9f3b) & MASK
	x = (x >> 16) ^ x
	return x & MASK


## Combines several values into one seed (e.g. stage index and stream id).
static func mix(a: int, b: int) -> int:
	return hash32(hash32(a) ^ ((b * 0x9E37) & MASK))


## A seed from text (e.g. "daily-2026-10-19"); stable across platforms.
static func seed_from_text(text: String) -> int:
	var h: int = 2166136261
	for b: int in text.to_utf8_buffer():
		h = ((h ^ b) * 16777619) & MASK
	return hash32(h)


func next_u32() -> int:
	var x: int = state
	x ^= (x << 13) & MASK
	x ^= x >> 17
	x ^= (x << 5) & MASK
	state = x & MASK
	return state


## Uniform float in [0, 1).
func next_float() -> float:
	return float(next_u32()) / 4294967296.0


func range_f(lo: float, hi: float) -> float:
	return lo + (hi - lo) * next_float()


## Uniform int in [lo, hi] inclusive.
func range_i(lo: int, hi: int) -> int:
	if hi <= lo:
		return lo
	return lo + int(next_u32() % (hi - lo + 1))


func chance(p: float) -> bool:
	return next_float() < p


## Picks an index from a list of non-negative weights.
func weighted(weights: Array) -> int:
	var total: float = 0.0
	for w: Variant in weights:
		total += maxf(0.0, float(w))
	if total <= 0.0:
		return 0
	var roll: float = next_float() * total
	for i: int in weights.size():
		roll -= maxf(0.0, float(weights[i]))
		if roll < 0.0:
			return i
	return weights.size() - 1
