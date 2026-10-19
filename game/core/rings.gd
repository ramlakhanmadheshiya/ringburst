class_name RingTypes
extends RefCounted
## Ring types (gameplay, unlocked with coins in the Forge) and permanent Forge
## upgrades. Both feed RunStats at the start of a run.

## Ring types change how the ring plays. "start" is an upgrade it begins with.
const RINGS: Dictionary = {
	"classic": {"name": "Classic", "cost": 0, "blurb": "Balanced. Nothing to get used to.", "start": ""},
	"twin": {"name": "Twin", "cost": 400, "blurb": "Starts with Echo. Waves hit 10% softer.", "start": "echo"},
	"glacier": {"name": "Glacier", "cost": 600, "blurb": "Starts with Frost Ring. Grows 8% slower.", "start": "frost"},
	"lens": {"name": "Lens", "cost": 800, "blurb": "Much wider PERFECT window. 8% less reach.", "start": ""},
	"nova": {"name": "Nova", "cost": 1000, "blurb": "Grows 25% faster. 15% less reach.", "start": ""},
	"cinder": {"name": "Cinder", "cost": 1200, "blurb": "Starts with Ember. Pushes shapes back less.", "start": "ember"},
	"titan": {"name": "Titan", "cost": 1600, "blurb": "Waves hit 35% harder. Grows 20% slower.", "start": ""},
}

## Permanent upgrades bought with coins. cost[i] is the price of level i + 1.
const FORGE: Dictionary = {
	"shield": {"name": "Extra Shield", "icon": "shield", "max": 2, "cost": [600, 1800], "desc": "+1 shield at the start of every run"},
	"power": {"name": "Core Power", "icon": "hammer", "max": 5, "cost": [120, 240, 420, 680, 1000], "desc": "+8% wave damage per level"},
	"charge": {"name": "Quick Hands", "icon": "gauge", "max": 5, "cost": [120, 240, 420, 680, 1000], "desc": "The ring grows 5% faster per level"},
	"reach": {"name": "Reach", "icon": "orbit", "max": 5, "cost": [120, 240, 420, 680, 1000], "desc": "+4% ring size per level"},
	"eye": {"name": "Keen Eye", "icon": "scan", "max": 5, "cost": [150, 300, 500, 800, 1200], "desc": "A wider PERFECT window per level"},
	"magnet": {"name": "Pull", "icon": "magnet", "max": 3, "cost": [150, 350, 700], "desc": "Gems near the core fly in on their own"},
	"scholar": {"name": "Study", "icon": "sparkles", "max": 5, "cost": [100, 200, 350, 550, 800], "desc": "+8% XP per level"},
	"fortune": {"name": "Fortune", "icon": "gem", "max": 5, "cost": [150, 300, 500, 800, 1200], "desc": "+10% coins per level"},
	"reroll": {"name": "Reroll", "icon": "refresh-cw", "max": 3, "cost": [300, 800, 1500], "desc": "Reroll an upgrade choice once more per run"},
}

## Starting perks: one owned upgrade at the start of a run (unlocked once).
const PERK_COST: int = 250


static func ring_ids() -> Array:
	return RINGS.keys()


static func forge_ids() -> Array:
	return FORGE.keys()


static func ring_name(id: String) -> String:
	return str(RINGS.get(id, RINGS["classic"])["name"])


static func forge_cost(id: String, level: int) -> int:
	var costs: Array = FORGE[id]["cost"]
	return int(costs[level]) if level < costs.size() else -1
