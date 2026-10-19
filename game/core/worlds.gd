class_name Worlds
extends RefCounted
## The campaign: 8 worlds of 6 stages. Each world has its own palette and
## music and adds one new shape (taught in its first stage). Stages 1-5 end
## with a Guardian, stage 6 with the world's boss. Also builds the specs for
## Endless and the Daily Run. Pure data and maths: no engine state.

const STAGES_PER_WORLD: int = 6
## Stage length before the boss arrives, by stage number in the world.
const DURATIONS: Array[float] = [70.0, 78.0, 84.0, 90.0, 95.0, 100.0]

## Neon-on-dark palettes. "enemies" are the four shape colours of the world.
const WORLDS: Array[Dictionary] = [
	{"id": "shore", "name": "Neon Shore", "tagline": "Drifters wash in from every edge",
		"top": "#0E1A3A", "bottom": "#060A1C", "accent": "#3DF5FF", "core": "#E9FDFF",
		"enemies": ["#FF4FA3", "#FFD23F", "#7CFF6B", "#B98CFF"], "gem": "#7CFFCB"},
	{"id": "pulse", "name": "Pulse City", "tagline": "Dashers wait, flash, then lunge",
		"top": "#2A0E3D", "bottom": "#0F0618", "accent": "#FF4FD8", "core": "#FFE9FB",
		"enemies": ["#FFE14F", "#4FF0FF", "#FF7A4F", "#9DFF4F"], "gem": "#FFE98A"},
	{"id": "bloom", "name": "Iron Bloom", "tagline": "Wardens carry shields: break them with a perfect",
		"top": "#0B2A26", "bottom": "#03110F", "accent": "#5CFFB0", "core": "#EFFFF7",
		"enemies": ["#FFC94F", "#FF5C7A", "#4FC3FF", "#E2FF5C"], "gem": "#FFE27A"},
	{"id": "fracture", "name": "Fracture", "tagline": "Splitters burst into quick little minis",
		"top": "#2E0E26", "bottom": "#120410", "accent": "#FF9F43", "core": "#FFF3E6",
		"enemies": ["#C77DFF", "#4FFFD2", "#FF4F6E", "#FFE84F"], "gem": "#FFD08A"},
	{"id": "orbit", "name": "Orbit Deep", "tagline": "Orbiters spiral round the core",
		"top": "#101A4A", "bottom": "#050822", "accent": "#7DA2FF", "core": "#EEF2FF",
		"enemies": ["#B6FF4F", "#FF6BD5", "#4FFFF0", "#FFB04F"], "gem": "#C9FF8A"},
	{"id": "hive", "name": "The Hive", "tagline": "Hatchers park far away and breed",
		"top": "#2E1A06", "bottom": "#120A02", "accent": "#FFC23D", "core": "#FFF8E6",
		"enemies": ["#FF5C3D", "#4FD8FF", "#FF4FA8", "#9BFF4F"], "gem": "#FFE58A"},
	{"id": "rift", "name": "Phantom Rift", "tagline": "Phantoms fade in and out of reach",
		"top": "#1C0F36", "bottom": "#08041A", "accent": "#C9A2FF", "core": "#F6EEFF",
		"enemies": ["#5CFFC2", "#FF5CA8", "#FFE15C", "#5CB8FF"], "gem": "#B8FFE0"},
	{"id": "horizon", "name": "Event Horizon", "tagline": "Brutes: armoured, heavy, relentless",
		"top": "#1A0A0E", "bottom": "#050203", "accent": "#FF4F5E", "core": "#FFF0F0",
		"enemies": ["#FFD84F", "#4FE8FF", "#FF8A4F", "#E04FFF"], "gem": "#FFE08A"},
]

## Daily Run modifiers: one per day, picked from the date.
const MODIFIERS: Dictionary = {
	"swarm": {"name": "Swarm", "desc": "Half again as many shapes, but they're frailer"},
	"glass": {"name": "Glass Core", "desc": "One shield only. Score counts double"},
	"frost": {"name": "Cold Snap", "desc": "Everyone starts with Frost Ring"},
	"giants": {"name": "Giants", "desc": "Shapes are bigger, slower and tougher"},
	"blitz": {"name": "Blitz", "desc": "Your ring grows faster, and so do they"},
	"echoes": {"name": "Echoes", "desc": "Everyone starts with Echo"},
	"precision": {"name": "Precision", "desc": "A tighter PERFECT window, but perfects hit triple"},
}


static func count() -> int:
	return WORLDS.size()


static func total_stages() -> int:
	return WORLDS.size() * STAGES_PER_WORLD


static func world(w: int) -> Dictionary:
	return WORLDS[clampi(w, 0, WORLDS.size() - 1)]


static func stage_id(w: int, k: int) -> String:
	return "%s-%d" % [world(w)["id"], k + 1]


## [world, stage] for an id like "shore-3", or [-1, -1].
static func parse_stage_id(id: String) -> Array[int]:
	var dash: int = id.rfind("-")
	if dash < 0:
		return [-1, -1]
	var wid: String = id.substr(0, dash)
	var k: int = id.substr(dash + 1).to_int() - 1
	for w: int in WORLDS.size():
		if WORLDS[w]["id"] == wid and k >= 0 and k < STAGES_PER_WORLD:
			return [w, k]
	return [-1, -1]


## How hard a campaign stage is: worlds step by 1.0, stages by 0.18.
static func difficulty(w: int, k: int) -> float:
	return float(w) + 0.18 * float(k)


## Combo needed for the third star.
static func combo_target(w: int, k: int) -> int:
	return mini(30, 6 + 2 * w + k)


## Shape weights for a world: everything met so far, the new shape favoured.
static func type_weights(w: int) -> Array:
	var out: Array = []
	for t: int in EnemyTypes.MINI:
		if t > w:
			out.append(0.0)
		elif t == w:
			out.append(3.0 if w > 0 else 4.0)
		elif t == EnemyTypes.DRIFTER:
			out.append(1.6)
		else:
			out.append(1.0)
	return out


## Everything the simulation needs to run a campaign stage.
static func stage_spec(w: int, k: int) -> Dictionary:
	var d: float = difficulty(w, k)
	return {
		"mode": "stage", "id": stage_id(w, k), "world": w, "stage": k,
		"seed": Rng.mix(1009 + w, 31 + k), "difficulty": d, "duration": DURATIONS[k],
		"weights": type_weights(w), "featured": w if k == 0 else -1,
		"boss": EnemyTypes.boss(w, d) if k == STAGES_PER_WORLD - 1 else EnemyTypes.guardian(w, d),
		"combo_target": combo_target(w, k), "modifier": "",
	}


## Endless: every shape from the start, a boss every two minutes, and the
## difficulty climbing for as long as you last.
static func endless_spec(seed_value: int) -> Dictionary:
	var weights: Array = []
	for t: int in EnemyTypes.MINI:
		weights.append(1.6 if t == EnemyTypes.DRIFTER else 1.0)
	return {
		"mode": "endless", "id": "endless", "world": 0, "stage": 0, "seed": seed_value,
		"difficulty": 0.6, "duration": 120.0, "weights": weights, "featured": -1,
		"boss": {}, "combo_target": 0, "modifier": "",
	}


## Days since 2026-01-01 for a "YYYY-MM-DD" key (stable, no time zones).
static func day_number(date_key: String) -> int:
	var p: PackedStringArray = date_key.split("-")
	if p.size() != 3:
		return 0
	var unix: int = Time.get_unix_time_from_datetime_dict({"year": p[0].to_int(), "month": p[1].to_int(), "day": p[2].to_int(), "hour": 12})
	var base: int = Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 1, "day": 1, "hour": 12})
	return int(round(float(unix - base) / 86400.0))


static func date_key_from_day(day: int) -> String:
	var base: int = Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 1, "day": 1, "hour": 12})
	return Time.get_date_string_from_unix_time(base + day * 86400)


## The Daily Run for a date: the same for everyone, built from the date alone.
## The look, the boss and the modifier rotate; difficulty follows the week
## (Monday gentlest, Sunday hardest).
static func daily_spec(date_key: String) -> Dictionary:
	var seed_value: int = Rng.seed_from_text("ringburst-daily-" + date_key)
	var rng: Rng = Rng.new(seed_value)
	var day: int = day_number(date_key)
	var w: int = posmod(day, WORLDS.size())
	var mods: Array = MODIFIERS.keys()
	var mod: String = str(mods[posmod(day * 3 + rng.range_i(0, 2), mods.size())])
	var unix: int = Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 1, "day": 1, "hour": 12}) + day * 86400
	var weekday: int = posmod(int(Time.get_datetime_dict_from_unix_time(unix)["weekday"]) - 1, 7)
	var d: float = 2.2 + 0.25 * float(weekday)
	var weights: Array = []
	for t: int in EnemyTypes.MINI:
		weights.append(1.5 if t == EnemyTypes.DRIFTER else rng.range_f(0.4, 1.4))
	return {
		"mode": "daily", "id": "daily-" + date_key, "world": w, "stage": 0, "seed": seed_value,
		"difficulty": d, "duration": 110.0, "weights": weights, "featured": -1,
		"boss": EnemyTypes.boss(w, d), "combo_target": 15, "modifier": mod, "date": date_key,
	}
