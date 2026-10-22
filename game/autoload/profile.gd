extends Node
## The player's progress: level stars and unlocks, purchases and trials,
## lifetime stats and awards, settings and one-time flags.

signal achievement_unlocked(achievement: Dictionary)
signal settings_changed
signal purchases_changed
signal supporter_changed(on: bool)

## A cosmetic pack trial from a video lasts this long.
const TRIAL_SECONDS: int = 3600

var _d: Dictionary:
	get:
		return Save.data


static func today_key() -> String:
	return Time.get_date_string_from_system()


# --- Levels, stars and worlds -------------------------------------------------

## Best stars on a level (0 = never cleared).
func level_stars(id: String) -> int:
	return int((_d["cleared"] as Dictionary).get(id, {}).get("stars", 0))


func level_best(id: String) -> int:
	return int((_d["cleared"] as Dictionary).get(id, {}).get("best", 0))


func is_cleared(id: String) -> bool:
	return level_stars(id) > 0


func world_clears(w: int) -> int:
	var n: int = 0
	for k: int in Worlds.LEVELS_PER_WORLD:
		if is_cleared(Worlds.level_id(w, k)):
			n += 1
	return n


func world_stars(w: int) -> int:
	var n: int = 0
	for k: int in Worlds.LEVELS_PER_WORLD:
		n += level_stars(Worlds.level_id(w, k))
	return n


func total_stars() -> int:
	var n: int = 0
	for v: Variant in (_d["cleared"] as Dictionary).values():
		n += int((v as Dictionary).get("stars", 0))
	return n


func total_clears() -> int:
	return (_d["cleared"] as Dictionary).size()


## Levels open one at a time: clear one to open the next (across worlds).
func level_unlocked(w: int, k: int) -> bool:
	if w < 0 or w >= Worlds.count() or k < 0 or k >= Worlds.LEVELS_PER_WORLD:
		return false
	if w == 0 and k == 0:
		return true
	if k > 0:
		return is_cleared(Worlds.level_id(w, k - 1))
	return is_cleared(Worlds.level_id(w - 1, Worlds.LEVELS_PER_WORLD - 1))


func world_unlocked(w: int) -> bool:
	return level_unlocked(w, 0)


func unlocked_world_count() -> int:
	var n: int = 0
	for w: int in Worlds.count():
		if world_unlocked(w):
			n += 1
	return n


## Where "Play" goes: the first open level not yet cleared (or the last one).
func next_level() -> Array[int]:
	for w: int in Worlds.count():
		for k: int in Worlds.LEVELS_PER_WORLD:
			if level_unlocked(w, k) and not is_cleared(Worlds.level_id(w, k)):
				return [w, k]
	return [Worlds.count() - 1, Worlds.LEVELS_PER_WORLD - 1]


func all_cleared() -> bool:
	return total_clears() >= Worlds.total_levels()


# --- Purchases and trials ----------------------------------------------------

## True if bought (directly or through the Complete pack) or, for cosmetic
## packs, on a video trial that hasn't run out.
func owns(product: String) -> bool:
	return bought(product) or trial_left(product) > 0


func bought(product: String) -> bool:
	var owned: Dictionary = _d["owned"]
	return bool(owned.get(product, false)) or bool(owned.get("complete_pack", false))


func set_owned(product: String, on: bool) -> void:
	var was_supporter: bool = is_supporter()
	_d["owned"][product] = on
	Save.mark_dirty()
	purchases_changed.emit()
	if is_supporter() != was_supporter:
		supporter_changed.emit(is_supporter())


func is_supporter() -> bool:
	return bought("supporter_pack")


func trial_left(product: String) -> int:
	var until: int = int((_d["trials"] as Dictionary).get(product, 0))
	return maxi(0, until - int(Time.get_unix_time_from_system()))


func start_trial(product: String) -> void:
	_d["trials"][product] = int(Time.get_unix_time_from_system()) + TRIAL_SECONDS
	Save.mark_dirty()
	purchases_changed.emit()


## "42:13" left on a trial (or "" when none).
func trial_clock(product: String) -> String:
	var left: int = trial_left(product)
	if left <= 0:
		return ""
	return "%d:%02d" % [left / 60, left % 60]


func tips_given() -> int:
	return int(_d["tips"])


func add_tip() -> void:
	_d["tips"] = tips_given() + 1
	Save.mark_dirty()


# --- Finishing levels -----------------------------------------------------------

func set_last_level(id: String) -> void:
	_d["last_level"] = id
	Save.mark_dirty()


## Records a finished level, won or lost. On a win the stars and best score
## are kept if they beat the old ones. Returns what happened, for the result
## card: won, first (first clear), stars, new_stars, best, new_best,
## world_done and unlocked (the id of the level this clear opened, or "").
func finish_level(id: String, sim: RunSim) -> Dictionary:
	var s: Dictionary = _d["stats"]
	s["runs"] = int(s["runs"]) + 1
	s["kills"] = int(s["kills"]) + sim.kills
	s["perfects"] = int(s["perfects"]) + sim.perfects
	s["best_combo"] = maxi(int(s["best_combo"]), sim.best_combo)
	var wk: Array[int] = Worlds.parse_level_id(id)
	var won: bool = sim.state == RunSim.State.WON
	var out: Dictionary = {"won": won, "first": false, "stars": 0, "new_stars": 0, "best": level_best(id),
		"new_best": false, "world_done": false, "unlocked": ""}
	if won:
		var old: int = level_stars(id)
		var stars: int = sim.stars()
		var first: bool = old == 0
		var entry: Dictionary = (_d["cleared"] as Dictionary).get(id, {})
		entry["stars"] = maxi(old, stars)
		out["new_best"] = not first and sim.score > int(entry.get("best", 0))
		entry["best"] = maxi(int(entry.get("best", 0)), sim.score)
		_d["cleared"][id] = entry
		var new_stars: int = maxi(0, stars - old)
		s["stars"] = int(s["stars"]) + new_stars
		if stars == 3 and old < 3:
			s["flawless"] = int(s["flawless"]) + 1
		if first:
			s["levels"] = int(s["levels"]) + 1
			if Worlds.is_boss(wk[1]):
				s["bosses"] = int(s["bosses"]) + 1
				s["w_" + str(Worlds.world(wk[0])["id"])] = 1
				out["world_done"] = true
			if wk[1] < Worlds.LEVELS_PER_WORLD - 1:
				out["unlocked"] = Worlds.level_id(wk[0], wk[1] + 1)
			elif wk[0] < Worlds.count() - 1:
				out["unlocked"] = Worlds.level_id(wk[0] + 1, 0)
		out.merge({"first": first, "stars": stars, "new_stars": new_stars, "best": int(entry["best"])}, true)
	Save.mark_dirty()
	check_achievements()
	return out


# --- Achievements ------------------------------------------------------------

func stat(key: String) -> int:
	return int(_d["stats"].get(key, 0))


func achievement_done(id: String) -> bool:
	return (_d["achievements"] as Dictionary).has(id)


## Unlocks every award whose goal is met (each once).
func check_achievements() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a: Dictionary in Achievements.all():
		if achievement_done(a["id"]) or stat(a["stat"]) < int(a["goal"]):
			continue
		_d["achievements"][a["id"]] = today_key()
		out.append(a)
		achievement_unlocked.emit(a)
	if not out.is_empty():
		Save.mark_dirty()
	return out


# --- Settings and one-time flags ---------------------------------------------

func setting(key: String, fallback: Variant = null) -> Variant:
	return _d["settings"].get(key, fallback)


func set_setting(key: String, value: Variant) -> void:
	_d["settings"][key] = value
	Save.mark_dirty()
	settings_changed.emit()


func seen(key: String) -> bool:
	return (_d["seen"] as Dictionary).has(key)


func mark_seen(key: String) -> void:
	_d["seen"][key] = true
	Save.mark_dirty()


func reset_all() -> void:
	Save.reset()
	settings_changed.emit()
