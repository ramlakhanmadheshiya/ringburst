class_name Achievements
extends RefCounted
## Achievement definitions. Each unlocks once when `stat` reaches `goal` and
## pays its reward exactly once (see Profile.check_achievements). Every world
## also has its own "world complete" award, built from Worlds.

const BASE: Array[Dictionary] = [
	{"id": "first_burst", "title": "First Burst", "desc": "Clear your first stage", "stat": "stages", "goal": 1, "reward": 20, "icon": "zap"},
	{"id": "stages_12", "title": "Getting Warm", "desc": "Clear 12 stages", "stat": "stages", "goal": 12, "reward": 80, "icon": "zap"},
	{"id": "stages_24", "title": "Halfway Out", "desc": "Clear 24 stages", "stat": "stages", "goal": 24, "reward": 150, "icon": "zap"},
	{"id": "stages_48", "title": "Event Horizon", "desc": "Clear all 48 stages", "stat": "stages", "goal": 48, "reward": 600, "icon": "trophy"},
	{"id": "stars_15", "title": "Starlight", "desc": "Earn 15 stars", "stat": "stars", "goal": 15, "reward": 40, "icon": "star"},
	{"id": "stars_60", "title": "Constellation", "desc": "Earn 60 stars", "stat": "stars", "goal": 60, "reward": 150, "icon": "star"},
	{"id": "stars_144", "title": "Every Star", "desc": "Earn all 144 stars", "stat": "stars", "goal": 144, "reward": 800, "icon": "star-filled"},
	{"id": "perfect_1", "title": "Right on the Edge", "desc": "Land your first PERFECT", "stat": "perfects", "goal": 1, "reward": 10, "icon": "target"},
	{"id": "perfect_250", "title": "Sharpshooter", "desc": "Land 250 perfects", "stat": "perfects", "goal": 250, "reward": 60, "icon": "target"},
	{"id": "perfect_2000", "title": "Edge Lord", "desc": "Land 2,000 perfects", "stat": "perfects", "goal": 2000, "reward": 250, "icon": "target"},
	{"id": "combo_10", "title": "In Rhythm", "desc": "Reach a 10 combo", "stat": "best_combo", "goal": 10, "reward": 20, "icon": "flame"},
	{"id": "combo_30", "title": "On Fire", "desc": "Reach a 30 combo", "stat": "best_combo", "goal": 30, "reward": 60, "icon": "flame"},
	{"id": "combo_75", "title": "Unbroken", "desc": "Reach a 75 combo", "stat": "best_combo", "goal": 75, "reward": 150, "icon": "flame"},
	{"id": "kills_1000", "title": "Shape Breaker", "desc": "Burst 1,000 shapes", "stat": "kills", "goal": 1000, "reward": 50, "icon": "sparkles"},
	{"id": "kills_10000", "title": "Geometry Storm", "desc": "Burst 10,000 shapes", "stat": "kills", "goal": 10000, "reward": 200, "icon": "sparkles"},
	{"id": "kills_50000", "title": "Supernova", "desc": "Burst 50,000 shapes", "stat": "kills", "goal": 50000, "reward": 500, "icon": "sun"},
	{"id": "boss_1", "title": "Giant Slayer", "desc": "Beat a world boss", "stat": "bosses", "goal": 1, "reward": 40, "icon": "skull"},
	{"id": "boss_8", "title": "Boss Rush", "desc": "Beat all 8 world bosses", "stat": "bosses", "goal": 8, "reward": 300, "icon": "skull"},
	{"id": "nodamage_1", "title": "Untouched", "desc": "Clear a stage without taking a hit", "stat": "nodamage", "goal": 1, "reward": 30, "icon": "shield"},
	{"id": "nodamage_15", "title": "Glass Cannon", "desc": "Clear 15 stages without taking a hit", "stat": "nodamage", "goal": 15, "reward": 150, "icon": "shield"},
	{"id": "synergy_1", "title": "Better Together", "desc": "Discover a synergy upgrade", "stat": "synergies", "goal": 1, "reward": 40, "icon": "wand-sparkles"},
	{"id": "synergy_4", "title": "Alchemist", "desc": "Discover all 4 synergies", "stat": "synergies", "goal": 4, "reward": 200, "icon": "wand-sparkles"},
	{"id": "forge_5", "title": "Tinkerer", "desc": "Buy 5 Forge upgrades", "stat": "forge", "goal": 5, "reward": 50, "icon": "hammer"},
	{"id": "forge_25", "title": "Master Smith", "desc": "Buy 25 Forge upgrades", "stat": "forge", "goal": 25, "reward": 250, "icon": "hammer"},
	{"id": "rings_3", "title": "Ring Collector", "desc": "Own 3 ring types", "stat": "rings", "goal": 3, "reward": 60, "icon": "circle-dot"},
	{"id": "rings_7", "title": "Lord of the Rings", "desc": "Own all 7 ring types", "stat": "rings", "goal": 7, "reward": 300, "icon": "circle-dot"},
	{"id": "endless_3", "title": "Staying Power", "desc": "Last 3 minutes in Endless", "stat": "endless_time", "goal": 180, "reward": 60, "icon": "infinity"},
	{"id": "endless_8", "title": "Marathon", "desc": "Last 8 minutes in Endless", "stat": "endless_time", "goal": 480, "reward": 200, "icon": "infinity"},
	{"id": "daily_1", "title": "Daily Burst", "desc": "Finish a Daily Run", "stat": "dailies", "goal": 1, "reward": 20, "icon": "calendar"},
	# Daily streaks count days in a row: missing a day starts the count again.
	{"id": "streak_3", "title": "Three in a Row", "desc": "Play the Daily Run 3 days in a row", "stat": "best_streak", "goal": 3, "reward": 40, "icon": "flame"},
	{"id": "streak_7", "title": "A Week of Bursts", "desc": "Play the Daily Run 7 days in a row", "stat": "best_streak", "goal": 7, "reward": 100, "icon": "flame"},
	{"id": "streak_30", "title": "A Month of Rings", "desc": "Play the Daily Run 30 days in a row", "stat": "best_streak", "goal": 30, "reward": 500, "icon": "flame"},
]

const WORLD_REWARD: int = 60


## Base achievements plus one per world ("Neon Shore complete").
static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = BASE.duplicate()
	for w: int in Worlds.count():
		var wd: Dictionary = Worlds.world(w)
		out.append({
			"id": "world_" + str(wd["id"]), "title": "%s complete" % wd["name"],
			"desc": "Beat the boss of world %d" % (w + 1),
			"stat": "w_" + str(wd["id"]), "goal": 1, "reward": WORLD_REWARD, "icon": "trophy",
		})
	return out


static func by_id(id: String) -> Dictionary:
	for a: Dictionary in all():
		if a["id"] == id:
			return a
	return {}
