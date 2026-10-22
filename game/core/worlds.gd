class_name Worlds
extends RefCounted
## The campaign: 8 worlds of 40 levels. Each world has its own palette and
## music and adds one new shape (met in its first level). Every level has one
## task, shown before it starts: burst a number of shapes, land PERFECTs,
## survive, build a combo, hunt the world's new shape, or beat a Giant
## (levels 10, 20 and 30) or the world's boss (level 40). Pure data and maths:
## no engine state.

const LEVELS_PER_WORLD: int = 40
## Levels that end with a Giant of the world's new shape (0-based); the last
## level of every world is its boss.
const GUARDIAN_LEVELS: Array[int] = [9, 19, 29]

## The order tasks come round in each block of ten levels (positions 1 to 8;
## 0 is a block's opener and 9 its Giant or boss).
const PATTERN: Array[String] = ["", "kills", "perfects", "survive", "hunt", "combo", "kills", "perfects", "survive"]

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


static func count() -> int:
	return WORLDS.size()


static func total_levels() -> int:
	return WORLDS.size() * LEVELS_PER_WORLD


static func world(w: int) -> Dictionary:
	return WORLDS[clampi(w, 0, WORLDS.size() - 1)]


static func level_id(w: int, k: int) -> String:
	return "%s-%d" % [world(w)["id"], k + 1]


## [world, level] for an id like "shore-3", or [-1, -1].
static func parse_level_id(id: String) -> Array[int]:
	var dash: int = id.rfind("-")
	if dash < 0:
		return [-1, -1]
	var wid: String = id.substr(0, dash)
	var k: int = id.substr(dash + 1).to_int() - 1
	for w: int in WORLDS.size():
		if WORLDS[w]["id"] == wid and k >= 0 and k < LEVELS_PER_WORLD:
			return [w, k]
	return [-1, -1]


## Levels in play order, counting from 0 (world 2 level 1 is 40).
static func play_index(w: int, k: int) -> int:
	return w * LEVELS_PER_WORLD + k


static func is_boss(k: int) -> bool:
	return k == LEVELS_PER_WORLD - 1


static func is_guardian(k: int) -> bool:
	return GUARDIAN_LEVELS.has(k)


## How hard a level is: each world adds 0.8, the 40 levels climb 1.1 more,
## and the level after each Giant eases off a little.
static func difficulty(w: int, k: int) -> float:
	var d: float = 0.8 * float(w) + 1.1 * float(k) / float(LEVELS_PER_WORLD - 1)
	if k > 0 and k % 10 == 0:
		d -= 0.25
	return maxf(0.0, d)


## The level's task type.
static func goal_type(w: int, k: int) -> String:
	if is_boss(k):
		return "boss"
	if is_guardian(k):
		return "guardian"
	if k == 0:
		return "kills" if w == 0 else "hunt"
	var g: String = PATTERN[k % 10] if k % 10 > 0 else "kills"
	# Neon Shore has only Drifters: hunting them is just bursting shapes.
	if g == "hunt" and w == 0:
		return "kills"
	return g


## The task: {"type", "n"} plus "shape" for a hunt.
static func goal(w: int, k: int) -> Dictionary:
	var p: float = float(k) / float(LEVELS_PER_WORLD - 1)
	var g: String = goal_type(w, k)
	var n: int = 1
	match g:
		"kills":
			n = 8 + int(16.0 * p) + 2 * w
		"perfects":
			n = 3 + int(6.0 * p) + w / 2
		"survive":
			n = 20 + int(25.0 * p) + 2 * w
		"combo":
			n = 3 + int(5.0 * p) + w / 3
		"hunt":
			n = 4 + int(6.0 * p) + w / 3
	var out: Dictionary = {"type": g, "n": n}
	if g == "hunt":
		out["shape"] = w
	return out


## One line describing a task, e.g. "Burst 12 shapes".
static func goal_text(gl: Dictionary, boss_name: String = "") -> String:
	var n: int = int(gl.get("n", 1))
	match str(gl.get("type", "")):
		"kills":
			return "Burst %d shapes" % n
		"perfects":
			return "Land %d PERFECTs" % n
		"survive":
			return "Survive %d seconds" % n
		"combo":
			return "Reach a combo of %d" % n
		"hunt":
			var nm: String = str(EnemyTypes.info(int(gl.get("shape", 0)))["name"])
			return "Burst %d %ss" % [n, nm]
		"guardian", "boss":
			return "Beat %s" % boss_name
	return ""


## The task's icon (a line icon from assets/icons).
static func goal_icon(gl: Dictionary) -> String:
	match str(gl.get("type", "")):
		"perfects":
			return "target"
		"survive":
			return "timer"
		"combo":
			return "flame"
		"hunt":
			return "crosshair"
		"guardian", "boss":
			return "skull"
	return "zap"


## Shape weights for a level: everything met so far, the new shape (or the
## hunted one) favoured, and a few Minis once Neon Shore is under way.
static func type_weights(w: int, k: int, hunt: int = -1) -> Array:
	var out: Array = []
	for t: int in EnemyTypes.TYPES.size():
		var v: float = 0.0
		if t == EnemyTypes.MINI:
			v = 0.0 if w == 0 and k < 15 else 0.5
		elif t > w:
			v = 0.0
		elif t == w:
			v = 3.0 if w > 0 else 4.0
		elif t == EnemyTypes.DRIFTER:
			v = 1.6
		else:
			v = 1.0
		if t == hunt:
			v *= 2.0
		out.append(v)
	return out


## Seconds over which a level's spawning climbs from calm to busy: roughly
## how long the task takes.
static func _length(gl: Dictionary) -> float:
	var n: float = float(gl.get("n", 1))
	match str(gl.get("type", "")):
		"survive":
			return n
		"kills", "hunt":
			return 10.0 + n * 1.3
		"perfects", "combo":
			return 15.0 + n * 4.0
	return 45.0


## Everything the simulation needs to play a level.
static func level_spec(w: int, k: int) -> Dictionary:
	var d: float = difficulty(w, k)
	var gl: Dictionary = goal(w, k)
	var boss: Dictionary = {}
	var boss_at: float = -1.0
	if gl["type"] == "boss":
		boss = EnemyTypes.boss(w, d)
		boss_at = 12.0
	elif gl["type"] == "guardian":
		boss = EnemyTypes.guardian(w, d)
		boss_at = 10.0
	return {
		"mode": "level", "id": level_id(w, k), "world": w, "level": k,
		"seed": Rng.mix(1009 + w, 31 + k), "difficulty": d, "length": _length(gl),
		"weights": type_weights(w, k, int(gl.get("shape", -1))), "featured": w if k == 0 and w > 0 else -1,
		"goal": gl, "boss": boss, "boss_at": boss_at,
	}
