class_name Achievements
extends RefCounted
## Award definitions. Each unlocks once when `stat` reaches `goal` (see
## Profile.check_achievements). Every world also has its own "world complete"
## award, built from Worlds.

const BASE: Array[Dictionary] = [
	{"id": "first_burst", "title": "First Burst", "desc": "Clear your first level", "stat": "levels", "goal": 1, "icon": "zap"},
	{"id": "levels_40", "title": "Getting Warm", "desc": "Clear 40 levels", "stat": "levels", "goal": 40, "icon": "zap"},
	{"id": "levels_160", "title": "Halfway Out", "desc": "Clear 160 levels", "stat": "levels", "goal": 160, "icon": "zap"},
	{"id": "levels_320", "title": "Event Horizon", "desc": "Clear all 320 levels", "stat": "levels", "goal": 320, "icon": "trophy"},
	{"id": "stars_30", "title": "Starlight", "desc": "Earn 30 stars", "stat": "stars", "goal": 30, "icon": "star"},
	{"id": "stars_300", "title": "Constellation", "desc": "Earn 300 stars", "stat": "stars", "goal": 300, "icon": "star"},
	{"id": "stars_960", "title": "Every Star", "desc": "Earn all 960 stars", "stat": "stars", "goal": 960, "icon": "star-filled"},
	{"id": "flawless_1", "title": "Untouched", "desc": "Clear a level with all three shields", "stat": "flawless", "goal": 1, "icon": "shield"},
	{"id": "flawless_50", "title": "Glass Cannon", "desc": "Clear 50 levels with all three shields", "stat": "flawless", "goal": 50, "icon": "shield"},
	{"id": "perfect_1", "title": "Right on the Edge", "desc": "Land your first PERFECT", "stat": "perfects", "goal": 1, "icon": "target"},
	{"id": "perfect_250", "title": "Sharpshooter", "desc": "Land 250 PERFECTs", "stat": "perfects", "goal": 250, "icon": "target"},
	{"id": "perfect_2000", "title": "Edge Lord", "desc": "Land 2,000 PERFECTs", "stat": "perfects", "goal": 2000, "icon": "target"},
	{"id": "combo_10", "title": "In Rhythm", "desc": "Reach a 10 combo", "stat": "best_combo", "goal": 10, "icon": "flame"},
	{"id": "combo_30", "title": "On Fire", "desc": "Reach a 30 combo", "stat": "best_combo", "goal": 30, "icon": "flame"},
	{"id": "combo_75", "title": "Unbroken", "desc": "Reach a 75 combo", "stat": "best_combo", "goal": 75, "icon": "flame"},
	{"id": "kills_1000", "title": "Shape Breaker", "desc": "Burst 1,000 shapes", "stat": "kills", "goal": 1000, "icon": "sparkles"},
	{"id": "kills_10000", "title": "Geometry Storm", "desc": "Burst 10,000 shapes", "stat": "kills", "goal": 10000, "icon": "sparkles"},
	{"id": "kills_50000", "title": "Supernova", "desc": "Burst 50,000 shapes", "stat": "kills", "goal": 50000, "icon": "sun"},
	{"id": "boss_1", "title": "Giant Slayer", "desc": "Beat a world boss", "stat": "bosses", "goal": 1, "icon": "skull"},
	{"id": "boss_8", "title": "Boss Rush", "desc": "Beat all 8 world bosses", "stat": "bosses", "goal": 8, "icon": "skull"},
]


## Base awards plus one per world ("Neon Shore complete").
static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = BASE.duplicate()
	for w: int in Worlds.count():
		var wd: Dictionary = Worlds.world(w)
		out.append({
			"id": "world_" + str(wd["id"]), "title": "%s complete" % wd["name"],
			"desc": "Beat the boss of world %d" % (w + 1),
			"stat": "w_" + str(wd["id"]), "goal": 1, "icon": "trophy",
		})
	return out


static func by_id(id: String) -> Dictionary:
	for a: Dictionary in all():
		if a["id"] == id:
			return a
	return {}
