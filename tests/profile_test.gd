extends Node
## Saves, rewards and the wallet, with a throwaway save file:
## coins, stage rewards and stars (paid once), unlocks, the Forge, ring types
## and perks feeding a run, the Daily Run and its streak, Endless bests,
## achievements (once), video limits, simulated purchases and trials,
## Supporter perks, reset keeping purchases, save/load and corrupt-save
## recovery.
##
##   godot --headless --path . res://tests/profile_test.tscn

const SAVE: String = "user://profile_test_save.json"

var t: Check = Check.new("PROFILE")


func _ready() -> void:
	_wipe()
	Save.path = SAVE
	Save.load_data()
	Store.simulate = true
	_coins()
	_stages()
	_forge()
	_daily()
	_endless()
	_achievements()
	_purchases()
	_persistence()
	_reset()
	_wipe()
	get_tree().quit(t.report())


func _wipe() -> void:
	for s: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + s))


## A finished run for a stage, won or lost, without playing it.
func _run(id: String, won: bool, damage: int = 0, combo: int = 0, score: int = 4000) -> RunSim:
	var wk: Array[int] = Worlds.parse_stage_id(id)
	var sim: RunSim = RunSim.new(Worlds.stage_spec(wk[0], wk[1]), RunStats.make())
	sim.state = RunSim.State.WON if won else RunSim.State.LOST
	sim.damage_taken = damage
	sim.best_combo = combo
	sim.score = score
	sim.kills = 120
	sim.perfects = 40
	return sim


func _coins() -> void:
	t.eq(Profile.coins(), Economy.START_COINS, "a new player starts with coins")
	Profile.add_coins(50)
	t.eq(Profile.coins(), Economy.START_COINS + 50, "coins add up")
	t.ok(not Profile.spend(100000), "can't spend more than you have")
	t.ok(Profile.spend(50), "spending works")
	t.eq(Profile.coins(), Economy.START_COINS, "spending takes coins")
	Save.data["video"]["day"] = ""
	var n: int = 0
	while Profile.claim_video_coins():
		n += 1
	t.eq(n, Economy.VIDEO_COINS_PER_DAY, "free-coin videos are limited per day")
	t.eq(Profile.coins(), Economy.START_COINS + n * Economy.VIDEO_COINS, "each video pays")


func _stages() -> void:
	t.ok(Profile.stage_unlocked(0, 0), "the first stage is open")
	t.ok(not Profile.stage_unlocked(0, 1), "the second opens after the first")
	t.ok(not Profile.endless_unlocked() and not Profile.daily_unlocked(), "Endless and the Daily open later")
	var c0: int = Profile.coins()
	var lost: Dictionary = Profile.finish_stage("shore-1", _run("shore-1", false))
	t.ok(not Profile.is_cleared("shore-1"), "a lost run doesn't clear the stage")
	# (achievements earned on the way pay on top)
	t.ok(int(lost["coins"]) > 0 and Profile.coins() >= c0 + int(lost["coins"]), "a lost run still pays coins")
	c0 = Profile.coins()
	var r: Dictionary = Profile.finish_stage("shore-1", _run("shore-1", true, 1, 2))
	t.ok(Profile.is_cleared("shore-1"), "a win clears the stage")
	t.eq(Profile.stage_stars("shore-1"), 1, "one star for a clear with a hit and a low combo")
	t.ok(bool(r["first"]), "the first clear is flagged")
	t.eq(int(r["coins"]), int(r["run_coins"]) + Economy.STAR_REWARD, "a new star pays")
	t.ok(Profile.coins() >= c0 + int(r["coins"]), "the reward is added")
	t.ok(Profile.stage_unlocked(0, 1), "the next stage opens")
	t.ok(Profile.daily_unlocked(), "the Daily opens after the first clear")
	var r2: Dictionary = Profile.finish_stage("shore-1", _run("shore-1", true, 1, 2))
	t.eq(int(r2["new_stars"]), 0, "no new stars, no star coins")
	var r3: Dictionary = Profile.finish_stage("shore-1", _run("shore-1", true, 0, 99, 9000))
	t.eq(Profile.stage_stars("shore-1"), 3, "stars from different runs combine")
	t.eq(int(r3["new_stars"]), 2, "two new stars at once")
	t.eq(Profile.stage_best("shore-1"), 9000, "the best score is kept")
	t.ok(bool(r3["new_best"]), "a new best is flagged")
	# The whole world, then the boss bonus once.
	for k: int in range(1, 6):
		Profile.finish_stage(Worlds.stage_id(0, k), _run(Worlds.stage_id(0, k), true))
	t.ok(Profile.endless_unlocked(), "Endless opens after Neon Shore 3")
	t.ok(Profile.world_unlocked(1), "beating the boss opens the next world")
	t.eq(Profile.stat("bosses"), 1, "the boss is counted")
	var again: Dictionary = Profile.finish_stage("shore-6", _run("shore-6", true))
	t.ok(not bool(again["world_done"]), "the world bonus is paid once")
	t.eq(Profile.next_stage(), [1, 0] as Array[int], "Play continues at the next world")
	t.eq(Profile.world_clears(0), 6, "six clears in the world")


func _forge() -> void:
	Profile.add_coins(20000)
	var c0: int = Profile.coins()
	var cost: int = Profile.forge_next_cost("power")
	t.ok(Profile.buy_forge("power"), "buying a Forge upgrade")
	t.eq(Profile.coins(), c0 - cost, "it costs coins")
	t.eq(Profile.forge_level("power"), 1, "its level goes up")
	for i: int in 10:
		Profile.buy_forge("power")
	t.eq(Profile.forge_level("power"), 5, "levels stop at the max")
	t.ok(not Profile.buy_forge("power"), "a maxed upgrade can't be bought")
	Profile.buy_forge("shield")
	var stats: RunStats = Profile.run_stats()
	t.eq(stats.max_lives, 4, "the Forge shield is in the next run")
	t.ok(stats.damage > 1.3, "Forge power is in the next run")
	t.ok(not Profile.owns_ring("twin"), "ring types are bought")
	t.ok(Profile.buy_ring("twin"), "buying a ring type")
	t.eq(Profile.ring(), "twin", "a new ring is equipped")
	t.eq(Profile.run_stats().level("echo"), 1, "the Twin ring's Echo is in the run")
	Profile.set_ring("classic")
	t.ok(Profile.buy_perk("frost"), "buying a perk")
	t.eq(Profile.run_stats().level("frost"), 1, "the perk starts the run")
	Profile.set_perk("")
	t.eq(Profile.run_stats().level("frost"), 0, "no perk, no upgrade")
	t.ok(not Profile.buy_perk("frost"), "a perk is bought once")


func _daily() -> void:
	var today: String = Profile.today_key()
	var spec: Dictionary = Worlds.daily_spec(today)
	var sim: RunSim = RunSim.new(spec, RunStats.make())
	sim.state = RunSim.State.LOST
	sim.score = 2500
	var c0: int = Profile.coins()
	var r: Dictionary = Profile.finish_daily(today, sim)
	t.ok(bool(r["first"]), "the first daily of the day pays")
	t.eq(int(r["streak"]), 1, "a streak starts")
	t.eq(int(r["coins"]), Economy.daily_reward(1) + sim.coins_earned(), "daily reward plus run coins")
	t.ok(Profile.coins() >= c0 + int(r["coins"]), "the daily reward is added")
	sim.score = 5000
	var r2: Dictionary = Profile.finish_daily(today, sim)
	t.ok(not bool(r2["first"]), "a replay doesn't pay the daily reward again")
	t.eq(Profile.daily_best(today), 5000, "a replay can beat the best")
	# Yesterday + today = a 2-day streak.
	Save.data["daily"] = {"done": {}, "best": {}, "streak": 4, "best_streak": 4, "last_date": Worlds.date_key_from_day(Worlds.day_number(today) - 1)}
	var r3: Dictionary = Profile.finish_daily(today, sim)
	t.eq(int(r3["streak"]), 5, "consecutive days extend the streak")
	Save.data["daily"] = {"done": {}, "best": {}, "streak": 4, "best_streak": 4, "last_date": Worlds.date_key_from_day(Worlds.day_number(today) - 3)}
	t.eq(Profile.current_streak(), 0, "a missed day ends the streak")
	t.eq(Economy.daily_reward(30), Economy.DAILY_REWARD + Economy.STREAK_BONUS_PER_DAY * Economy.STREAK_BONUS_CAP_DAYS, "the streak bonus is capped")


func _endless() -> void:
	var sim: RunSim = RunSim.new(Worlds.endless_spec(3), RunStats.make())
	sim.state = RunSim.State.LOST
	sim.score = 7777
	sim.t = 200.0
	var r: Dictionary = Profile.finish_endless(sim)
	t.ok(bool(r["new_best"]), "a first Endless run is a best")
	t.eq(Profile.endless_best(), 7777, "the Endless best is kept")
	sim.score = 100
	Profile.finish_endless(sim)
	t.eq(Profile.endless_best(), 7777, "a worse run keeps the best")
	t.ok(Profile.endless_best_time() >= 200.0, "the longest Endless run is kept")


func _achievements() -> void:
	var got: Array[String] = []
	for id: String in ["first_burst", "perfect_1", "boss_1", "endless_3", "daily_1"]:
		got.append(str(Profile.achievement_done(id)))
	t.eq(got, ["true", "true", "true", "true", "true"] as Array[String], "achievements unlock as you play")
	var c0: int = Profile.coins()
	Profile.check_achievements()
	t.eq(Profile.coins(), c0, "achievements pay only once")
	t.eq(Achievements.all().size(), Achievements.BASE.size() + Worlds.count(), "one award per world on top")
	var ids: Dictionary = {}
	for a: Dictionary in Achievements.all():
		ids[a["id"]] = true
	t.eq(ids.size(), Achievements.all().size(), "achievement ids are unique")


func _purchases() -> void:
	t.ok(not Profile.is_supporter(), "not a Supporter yet")
	var c0: int = Profile.coins()
	Store.buy("coins_500")
	t.eq(Profile.coins(), c0 + 500, "a coin bag adds coins")
	Store.buy("tip_50")
	t.eq(Profile.tips_given(), 1, "a tip is counted")
	Store.buy("supporter_pack")
	t.ok(Profile.is_supporter(), "the Supporter pack is owned")
	t.ok(not AdManager.ads_enabled(), "Supporters see no ads")
	t.ok(AdManager.rewarded_ready(), "Supporters get video rewards without videos")
	t.ok(not Profile.owns("theme_pack"), "themes are a separate pack")
	Profile.start_trial("theme_pack")
	t.ok(Profile.owns("theme_pack") and not Profile.bought("theme_pack"), "a video trial lends the pack")
	t.ok(not Profile.trial_clock("theme_pack").is_empty(), "the trial shows a clock")
	Save.data["trials"]["theme_pack"] = 1
	t.ok(not Profile.owns("theme_pack"), "trials run out")
	var c1: int = Profile.coins()
	Store.buy("complete_pack")
	t.ok(Profile.owns("theme_pack") and Profile.owns("style_pack"), "the Complete pack includes everything")
	t.eq(Profile.coins(), c1 + Store.COMPLETE_COINS, "the Complete pack adds its coins")
	Store.buy("complete_pack")
	t.eq(Profile.coins(), c1 + Store.COMPLETE_COINS, "its coins are granted once")
	t.ok(Store.complete_saving() > 0, "the Complete pack is a saving")
	t.eq(Store.all_ids().size(), 4 + Store.COIN_PACKS.size() + 100, "products: 4 packs, coin bags, 100 tip amounts")
	for id: String in Store.all_ids():
		t.ok(not Store.price(id).is_empty(), "%s has a price" % id)


func _persistence() -> void:
	Save.flush()
	var coins: int = Profile.coins()
	Save.data = {}
	Save.load_data()
	t.eq(Profile.coins(), coins, "coins survive a restart")
	t.ok(Profile.is_cleared("shore-3") and Profile.forge_level("power") == 5, "progress survives a restart")
	# A corrupt save falls back to the backup.
	Save.flush()
	var f: FileAccess = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	Save.load_data()
	t.eq(Save.recovered_from, "backup", "a corrupt save is recovered from the backup")
	t.ok(Profile.is_cleared("shore-1"), "the backup has the progress")


func _reset() -> void:
	var bought: int = int(Save.data["coins_bought"])
	Profile.reset_all()
	t.ok(not Profile.is_cleared("shore-1"), "reset erases progress")
	t.eq(Profile.forge_level("power"), 0, "reset erases the Forge")
	t.ok(Profile.is_supporter() and Profile.bought("complete_pack"), "reset keeps purchases")
	t.eq(Profile.coins(), Economy.START_COINS + bought, "reset keeps bought coins")
