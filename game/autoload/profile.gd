extends Node
## The player's progress and wallet: stage stars and unlocks, the Forge, ring
## types and perks, purchases, the Daily streak, Endless bests and
## achievements. Every reward is keyed by what earned it, so it is paid once.

signal coins_changed(total: int)
signal achievement_unlocked(achievement: Dictionary)
signal settings_changed
signal purchases_changed
signal supporter_changed(on: bool)
signal loadout_changed

## Endless opens after this stage is cleared; the Daily after the first stage.
const ENDLESS_UNLOCK: String = "shore-3"
const DAILY_UNLOCK: String = "shore-1"

var _d: Dictionary:
	get:
		return Save.data


static func today_key() -> String:
	return Time.get_date_string_from_system()


# --- Coins -------------------------------------------------------------------

func coins() -> int:
	return int(_d["coins"])


func add_coins(n: int) -> void:
	if n <= 0:
		return
	_d["coins"] = coins() + n
	Save.mark_dirty()
	coins_changed.emit(coins())


## Coins bought in the shop (kept if progress is reset).
func add_bought_coins(n: int) -> void:
	if n <= 0:
		return
	_d["coins_bought"] = int(_d["coins_bought"]) + n
	add_coins(n)


## Takes coins if the player has enough. Returns false (and changes nothing) otherwise.
func spend(n: int) -> bool:
	if n < 0 or coins() < n:
		return false
	_d["coins"] = coins() - n
	Save.mark_dirty()
	coins_changed.emit(coins())
	return true


func _today_counter(key: String) -> Dictionary:
	var c: Dictionary = _d[key]
	if str(c.get("day", "")) != today_key():
		c["day"] = today_key()
		for k: Variant in c.keys():
			if k != "day":
				c[k] = 0
	return c


func video_coins_left() -> int:
	return maxi(0, Economy.VIDEO_COINS_PER_DAY - int(_today_counter("video").get("coins", 0)))


## Pays the reward for a watched "free coins" video (limited per day).
func claim_video_coins() -> bool:
	if video_coins_left() <= 0:
		return false
	var c: Dictionary = _today_counter("video")
	c["coins"] = int(c.get("coins", 0)) + 1
	add_coins(Economy.VIDEO_COINS)
	return true


# --- Stages, stars and worlds -------------------------------------------------

func stage_mask(id: String) -> int:
	return int((_d["cleared"] as Dictionary).get(id, {}).get("stars", 0))


func stage_stars(id: String) -> int:
	return Economy.star_count(stage_mask(id))


func stage_best(id: String) -> int:
	return int((_d["cleared"] as Dictionary).get(id, {}).get("best", 0))


func is_cleared(id: String) -> bool:
	return stage_mask(id) & 1 != 0


func world_clears(w: int) -> int:
	var n: int = 0
	for k: int in Worlds.STAGES_PER_WORLD:
		if is_cleared(Worlds.stage_id(w, k)):
			n += 1
	return n


func world_stars(w: int) -> int:
	var n: int = 0
	for k: int in Worlds.STAGES_PER_WORLD:
		n += stage_stars(Worlds.stage_id(w, k))
	return n


func total_stars() -> int:
	var n: int = 0
	for v: Variant in (_d["cleared"] as Dictionary).values():
		n += Economy.star_count(int((v as Dictionary).get("stars", 0)))
	return n


func total_clears() -> int:
	var n: int = 0
	for w: int in Worlds.count():
		n += world_clears(w)
	return n


## Stages open one at a time: clear one to open the next (across worlds).
func stage_unlocked(w: int, k: int) -> bool:
	if w < 0 or w >= Worlds.count() or k < 0 or k >= Worlds.STAGES_PER_WORLD:
		return false
	if w == 0 and k == 0:
		return true
	if k > 0:
		return is_cleared(Worlds.stage_id(w, k - 1))
	return is_cleared(Worlds.stage_id(w - 1, Worlds.STAGES_PER_WORLD - 1))


func world_unlocked(w: int) -> bool:
	return stage_unlocked(w, 0)


func unlocked_world_count() -> int:
	var n: int = 0
	for w: int in Worlds.count():
		if world_unlocked(w):
			n += 1
	return n


## Where "Play" goes: the first open stage not yet cleared (or the last one).
func next_stage() -> Array[int]:
	for w: int in Worlds.count():
		for k: int in Worlds.STAGES_PER_WORLD:
			if stage_unlocked(w, k) and not is_cleared(Worlds.stage_id(w, k)):
				return [w, k]
	return [Worlds.count() - 1, Worlds.STAGES_PER_WORLD - 1]


func all_cleared() -> bool:
	return total_clears() >= Worlds.total_stages()


func endless_unlocked() -> bool:
	return is_cleared(ENDLESS_UNLOCK)


func daily_unlocked() -> bool:
	return is_cleared(DAILY_UNLOCK)


# --- Forge, ring types and perks ----------------------------------------------

func forge_level(id: String) -> int:
	return int((_d["forge"] as Dictionary).get(id, 0))


func forge_levels() -> Dictionary:
	return (_d["forge"] as Dictionary).duplicate()


func forge_next_cost(id: String) -> int:
	return RingTypes.forge_cost(id, forge_level(id))


## Buys the next level of a Forge upgrade. False if maxed or too expensive.
func buy_forge(id: String) -> bool:
	if not RingTypes.FORGE.has(id):
		return false
	var cost: int = forge_next_cost(id)
	if cost < 0 or not spend(cost):
		return false
	_d["forge"][id] = forge_level(id) + 1
	_d["stats"]["forge"] = int(_d["stats"]["forge"]) + 1
	Save.mark_dirty()
	loadout_changed.emit()
	check_achievements()
	return true


func owns_ring(id: String) -> bool:
	return id == "classic" or (_d["rings"] as Dictionary).has(id)


func buy_ring(id: String) -> bool:
	if not RingTypes.RINGS.has(id) or owns_ring(id):
		return false
	if not spend(int(RingTypes.RINGS[id]["cost"])):
		return false
	_d["rings"][id] = true
	_d["stats"]["rings"] = (_d["rings"] as Dictionary).size()
	set_ring(id)
	check_achievements()
	return true


func ring() -> String:
	var id: String = str(_d["ring"])
	return id if owns_ring(id) else "classic"


func set_ring(id: String) -> void:
	if owns_ring(id):
		_d["ring"] = id
		Save.mark_dirty()
		loadout_changed.emit()


func owns_perk(id: String) -> bool:
	return (_d["perks"] as Dictionary).has(id)


func buy_perk(id: String) -> bool:
	if not Upgrades.PERKS.has(id) or owns_perk(id):
		return false
	if not spend(RingTypes.PERK_COST):
		return false
	_d["perks"][id] = true
	set_perk(id)
	return true


func perk() -> String:
	var id: String = str(_d["perk"])
	return id if owns_perk(id) else ""


func set_perk(id: String) -> void:
	if id.is_empty() or owns_perk(id):
		_d["perk"] = id
		Save.mark_dirty()
		loadout_changed.emit()


## The stats a run starts with: Forge levels, the equipped ring and perk.
func run_stats() -> RunStats:
	return RunStats.make(forge_levels(), ring(), perk())


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
	_d["trials"][product] = int(Time.get_unix_time_from_system()) + Economy.TRIAL_SECONDS
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


# --- Finishing runs ------------------------------------------------------------

func set_last_stage(id: String) -> void:
	_d["last_stage"] = id
	Save.mark_dirty()


## Stats every run feeds, won or lost.
func _record_run(sim: RunSim) -> void:
	var s: Dictionary = _d["stats"]
	s["runs"] = int(s["runs"]) + 1
	s["kills"] = int(s["kills"]) + sim.kills
	s["perfects"] = int(s["perfects"]) + sim.perfects
	s["best_combo"] = maxi(int(s["best_combo"]), sim.best_combo)
	var syn: Dictionary = _d["synergies"]
	for id: String in Upgrades.synergy_ids():
		if sim.stats.has(id):
			syn[id] = true
	s["synergies"] = syn.size()
	Save.mark_dirty()


## Pays for a campaign run. Coins from the run always; on a win, the stars are
## merged with the best so far and each new star pays STAR_REWARD; the world's
## boss pays WORLD_BONUS the first time.
func finish_stage(id: String, sim: RunSim) -> Dictionary:
	_record_run(sim)
	var wk: Array[int] = Worlds.parse_stage_id(id)
	var run_coins: int = sim.coins_earned()
	var won: bool = sim.state == RunSim.State.WON
	var out: Dictionary = {"coins": run_coins, "run_coins": run_coins, "won": won, "first": false, "stars": 0,
		"mask": 0, "new_stars": 0, "best": stage_best(id), "new_best": false, "world_done": false, "unlocked": ""}
	if won:
		var old_mask: int = stage_mask(id)
		var mask: int = sim.stars_mask()
		var merged: int = old_mask | mask
		var new_stars: int = Economy.star_count(merged) - Economy.star_count(old_mask)
		var first: bool = old_mask & 1 == 0
		var entry: Dictionary = (_d["cleared"] as Dictionary).get(id, {})
		entry["stars"] = merged
		var best: int = maxi(int(entry.get("best", 0)), sim.score)
		out["new_best"] = sim.score > int(entry.get("best", 0))
		entry["best"] = best
		_d["cleared"][id] = entry
		var s: Dictionary = _d["stats"]
		s["stars"] = int(s["stars"]) + new_stars
		if sim.damage_taken == 0:
			s["nodamage"] = int(s["nodamage"]) + 1
		var bonus: int = new_stars * Economy.STAR_REWARD
		if first:
			s["stages"] = int(s["stages"]) + 1
			if wk[1] == Worlds.STAGES_PER_WORLD - 1:
				s["bosses"] = int(s["bosses"]) + 1
				s["w_" + str(Worlds.world(wk[0])["id"])] = 1
				bonus += Economy.WORLD_BONUS
				out["world_done"] = true
			if wk[1] < Worlds.STAGES_PER_WORLD - 1:
				out["unlocked"] = Worlds.stage_id(wk[0], wk[1] + 1)
			elif wk[0] < Worlds.count() - 1:
				out["unlocked"] = Worlds.stage_id(wk[0] + 1, 0)
		out["coins"] = run_coins + bonus
		out.merge({"first": first, "stars": Economy.star_count(mask), "mask": mask, "merged": merged, "new_stars": new_stars, "best": best}, true)
	add_coins(int(out["coins"]))
	Save.mark_dirty()
	check_achievements()
	return out


func endless_best() -> int:
	return int(_d["endless"]["best"])


func endless_best_time() -> float:
	return float(_d["endless"]["best_time"])


func finish_endless(sim: RunSim) -> Dictionary:
	_record_run(sim)
	var e: Dictionary = _d["endless"]
	e["runs"] = int(e["runs"]) + 1
	var new_best: bool = sim.score > int(e["best"])
	e["best"] = maxi(int(e["best"]), sim.score)
	e["best_time"] = maxf(float(e["best_time"]), sim.t)
	_d["stats"]["endless_time"] = maxi(int(_d["stats"]["endless_time"]), int(sim.t))
	var coins: int = sim.coins_earned()
	add_coins(coins)
	Save.mark_dirty()
	check_achievements()
	return {"coins": coins, "run_coins": coins, "new_best": new_best, "best": int(e["best"]), "won": false}


func daily_done(date_key: String) -> bool:
	return (_d["daily"]["done"] as Dictionary).has(date_key)


func daily_best(date_key: String) -> int:
	return int((_d["daily"]["best"] as Dictionary).get(date_key, 0))


## The streak as it stands today: it survives until a whole day is missed.
func current_streak() -> int:
	var daily: Dictionary = _d["daily"]
	var last: String = str(daily["last_date"])
	if last.is_empty():
		return 0
	var gap: int = Worlds.day_number(today_key()) - Worlds.day_number(last)
	return int(daily["streak"]) if gap <= 1 else 0


## Pays for a Daily Run once per date (finishing counts, win or lose) and
## extends the streak when days are consecutive. Replays only improve the best.
func finish_daily(date_key: String, sim: RunSim) -> Dictionary:
	_record_run(sim)
	var daily: Dictionary = _d["daily"]
	var best: Dictionary = daily["best"]
	var new_best: bool = sim.score > int(best.get(date_key, 0))
	best[date_key] = maxi(int(best.get(date_key, 0)), sim.score)
	var run_coins: int = sim.coins_earned()
	if daily_done(date_key):
		add_coins(run_coins)
		Save.mark_dirty()
		return {"coins": run_coins, "run_coins": run_coins, "first": false, "streak": current_streak(), "new_best": new_best, "best": int(best[date_key]), "won": sim.state == RunSim.State.WON}
	daily["done"][date_key] = true
	var last: String = str(daily["last_date"])
	var streak: int = 1
	if not last.is_empty():
		var gap: int = Worlds.day_number(date_key) - Worlds.day_number(last)
		if gap == 1:
			streak = int(daily["streak"]) + 1
		elif gap <= 0:
			streak = maxi(1, int(daily["streak"]))
	if last.is_empty() or Worlds.day_number(date_key) >= Worlds.day_number(last):
		daily["last_date"] = date_key
		daily["streak"] = streak
	daily["best_streak"] = maxi(int(daily["best_streak"]), streak)
	var s: Dictionary = _d["stats"]
	s["dailies"] = int(s["dailies"]) + 1
	s["best_streak"] = int(daily["best_streak"])
	var reward: int = Economy.daily_reward(streak) + run_coins
	add_coins(reward)
	Save.mark_dirty()
	check_achievements()
	return {"coins": reward, "run_coins": run_coins, "first": true, "streak": streak, "new_best": new_best, "best": int(best[date_key]), "won": sim.state == RunSim.State.WON}


# --- Achievements ------------------------------------------------------------

func stat(key: String) -> int:
	return int(_d["stats"].get(key, 0))


func achievement_done(id: String) -> bool:
	return (_d["achievements"] as Dictionary).has(id)


## Unlocks (and pays, once) every achievement whose goal is met.
func check_achievements() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a: Dictionary in Achievements.all():
		if achievement_done(a["id"]) or stat(a["stat"]) < int(a["goal"]):
			continue
		_d["achievements"][a["id"]] = today_key()
		add_coins(int(a["reward"]))
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
	coins_changed.emit(coins())
	settings_changed.emit()
	loadout_changed.emit()
