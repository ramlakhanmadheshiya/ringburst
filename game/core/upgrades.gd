class_name Upgrades
extends RefCounted
## The upgrade pool offered during a run (pick 1 of 3 on every level-up).
## 26 upgrades plus 4 synergies that only appear once both of their parts are
## owned. Effects are applied by RunStats.add(); descriptions here are what the
## upgrade cards show.

## id -> definition. "max" is the highest level; "weight" how often it is
## offered; "requires" (synergies) lists the upgrades that must be owned first.
const ALL: Dictionary = {
	"echo": {"name": "Echo", "icon": "repeat", "max": 2, "weight": 1.0, "tag": "wave",
		"desc": ["A second, softer wave follows each release", "A third wave follows"]},
	"split": {"name": "Split", "icon": "share-2", "max": 3, "weight": 0.9, "tag": "wave",
		"desc": ["At full reach the wave flies on as 3 arcs", "Arcs fly 20% further", "Arcs hit as hard as the wave"]},
	"frost": {"name": "Frost Ring", "icon": "snowflake", "max": 3, "weight": 1.0, "tag": "status",
		"desc": ["Waves slow shapes for 2 s", "Slow lasts 2.5 s and is stronger", "Slow lasts 3 s"]},
	"magnet": {"name": "Magnet", "icon": "magnet", "max": 3, "weight": 0.9, "tag": "utility",
		"desc": ["Gems near the core fly to you", "Bigger magnet", "Huge magnet"]},
	"thorns": {"name": "Thorns", "icon": "sparkles", "max": 3, "weight": 0.9, "tag": "defence",
		"desc": ["A spiked aura hurts shapes near the core", "Aura hits harder", "Aura hits faster and wider"]},
	"overcharge": {"name": "Overcharge", "icon": "zap", "max": 3, "weight": 1.0, "tag": "damage",
		"desc": ["Hold at full size to build up to +50% damage", "Up to +100%", "Up to +150%"]},
	"regen": {"name": "Shield Regen", "icon": "shield-check", "max": 3, "weight": 0.9, "tag": "defence",
		"desc": ["Regain a shield after 18 s without a hit", "After 14 s", "After 10 s"]},
	"chain": {"name": "Chain Lightning", "icon": "zap", "max": 3, "weight": 1.0, "tag": "perfect",
		"desc": ["Perfect sparks jump to 2 more shapes", "...to 4 more", "...to 6 more, harder"]},
	"pierce": {"name": "Pierce Armour", "icon": "crosshair", "max": 2, "weight": 0.8, "tag": "damage",
		"desc": ["Plain waves hurt shields and Brutes at half power", "Full power through armour"]},
	"wide_band": {"name": "Sharp Eye", "icon": "scan", "max": 3, "weight": 1.0, "tag": "perfect",
		"desc": ["Wider PERFECT window", "Even wider", "Widest"]},
	"afterglow": {"name": "Afterglow", "icon": "sun", "max": 2, "weight": 0.9, "tag": "wave",
		"desc": ["The wave lingers at full reach for 0.5 s", "Lingers for 1 s"]},
	"quick_charge": {"name": "Quick Charge", "icon": "gauge", "max": 3, "weight": 1.1, "tag": "ring",
		"desc": ["The ring grows 15% faster", "30% faster", "45% faster"]},
	"long_reach": {"name": "Long Reach", "icon": "orbit", "max": 3, "weight": 1.1, "tag": "ring",
		"desc": ["The ring can grow 12% bigger", "24% bigger", "36% bigger"]},
	"heavy_wave": {"name": "Heavy Wave", "icon": "hammer", "max": 4, "weight": 1.2, "tag": "damage",
		"desc": ["+30% wave damage", "+60% wave damage", "+90% wave damage", "+120% wave damage"]},
	"knockback": {"name": "Shove", "icon": "arrow-right", "max": 2, "weight": 0.8, "tag": "defence",
		"desc": ["Waves push shapes much further back", "Even further"]},
	"lifeline": {"name": "Lifeline", "icon": "heart-pulse", "max": 2, "weight": 0.7, "tag": "perfect",
		"desc": ["Every 12 perfects restores a shield", "Every 8 perfects"]},
	"pulse": {"name": "Heartbeat", "icon": "heart", "max": 3, "weight": 0.8, "tag": "defence",
		"desc": ["A small free wave every 6 s", "Every 4.5 s", "Every 3 s"]},
	"greed": {"name": "Greed", "icon": "gem", "max": 3, "weight": 0.7, "tag": "utility",
		"desc": ["+25% coins this run", "+50% coins", "+75% coins"]},
	"scholar": {"name": "Scholar", "icon": "sparkles", "max": 3, "weight": 0.8, "tag": "utility",
		"desc": ["+20% XP from gems", "+40% XP", "+60% XP"]},
	"second_wind": {"name": "Second Wind", "icon": "shield", "max": 1, "weight": 0.6, "tag": "defence",
		"desc": ["Once per run, survive a fatal hit with a blast"]},
	"combo_keeper": {"name": "Steady Hands", "icon": "hand", "max": 1, "weight": 0.7, "tag": "perfect",
		"desc": ["A release that hits nothing no longer breaks your combo"]},
	"static": {"name": "Static", "icon": "zap", "max": 2, "weight": 0.9, "tag": "status",
		"desc": ["Perfect waves stun shapes for 0.6 s", "Stun for 1 s"]},
	"ember": {"name": "Ember", "icon": "flame", "max": 3, "weight": 0.9, "tag": "status",
		"desc": ["Waves set shapes burning", "Burn hurts more", "Burn hurts a lot"]},
	"ricochet": {"name": "Ricochet", "icon": "rotate-ccw", "max": 2, "weight": 0.8, "tag": "wave",
		"desc": ["At full reach the wave bounces back inward", "The return hits as hard as the wave"]},
	"fast_wave": {"name": "Fast Wave", "icon": "wand-sparkles", "max": 2, "weight": 0.8, "tag": "wave",
		"desc": ["Waves travel 30% faster", "60% faster"]},
	"orbit": {"name": "Satellites", "icon": "circle-dot", "max": 3, "weight": 0.9, "tag": "defence",
		"desc": ["A shard circles the core, cutting shapes", "Two shards", "Three shards"]},
	# Synergies: offered only when both parts are owned.
	"shatter": {"name": "Shatter", "icon": "snowflake", "max": 1, "weight": 3.0, "tag": "synergy", "requires": ["frost", "static"],
		"desc": ["Slowed or stunned shapes take +60% damage"]},
	"resonance": {"name": "Resonance", "icon": "repeat", "max": 1, "weight": 3.0, "tag": "synergy", "requires": ["echo", "chain"],
		"desc": ["Echo waves of a PERFECT are perfect too"]},
	"supernova": {"name": "Supernova", "icon": "sun", "max": 1, "weight": 3.0, "tag": "synergy", "requires": ["overcharge", "long_reach"],
		"desc": ["A fully overcharged release reaches 35% further"]},
	"inferno": {"name": "Inferno", "icon": "flame", "max": 1, "weight": 3.0, "tag": "synergy", "requires": ["ember", "afterglow"],
		"desc": ["The afterglow ring burns everything it touches, hard"]},
}

## Upgrades a starting perk may be (unlocked in the Forge).
const PERKS: Array[String] = ["heavy_wave", "quick_charge", "long_reach", "wide_band", "echo", "frost", "magnet", "regen", "orbit", "chain"]


static func ids() -> Array:
	return ALL.keys()


static func regular_ids() -> Array:
	var out: Array = []
	for id: String in ALL:
		if not ALL[id].has("requires"):
			out.append(id)
	return out


static func synergy_ids() -> Array:
	var out: Array = []
	for id: String in ALL:
		if ALL[id].has("requires"):
			out.append(id)
	return out


static func def(id: String) -> Dictionary:
	return ALL.get(id, {})


static func max_level(id: String) -> int:
	return int(def(id).get("max", 1))


static func display_name(id: String) -> String:
	return str(def(id).get("name", id))


## What the card says for taking `id` at `level` (1-based).
static func describe(id: String, level: int) -> String:
	var d: Array = def(id).get("desc", [])
	if d.is_empty():
		return ""
	return str(d[clampi(level - 1, 0, d.size() - 1)])


static func roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V"][clampi(n, 0, 5)]


## True when `id` could be offered given the levels owned so far.
static func can_offer(id: String, owned: Dictionary) -> bool:
	var d: Dictionary = def(id)
	if d.is_empty() or int(owned.get(id, 0)) >= int(d["max"]):
		return false
	for req: String in d.get("requires", []):
		if int(owned.get(req, 0)) <= 0:
			return false
	return true


## Draws `count` different upgrades to offer, weighted, from `rng`.
## Synergies whose parts are owned are strongly favoured.
static func offer(rng: Rng, owned: Dictionary, count: int = 3) -> Array:
	var pool: Array = []
	var weights: Array = []
	for id: String in ALL:
		if can_offer(id, owned):
			pool.append(id)
			weights.append(float(ALL[id]["weight"]))
	var out: Array = []
	while out.size() < count and not pool.is_empty():
		var i: int = rng.weighted(weights)
		out.append(pool[i])
		pool.remove_at(i)
		weights.remove_at(i)
	return out
