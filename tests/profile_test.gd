extends Node
## Saves and progress, with a throwaway save file: levels opening one by one,
## stars (best kept), best scores, worlds opening after their boss, awards
## (once), simulated purchases and trials, Supporter perks, reset keeping
## purchases, save/load, corrupt-save recovery and moving an old (version 1)
## save over.
##
##   godot --headless --path . res://tests/profile_test.tscn

const SAVE: String = "user://profile_test_save.json"

var t: Check = Check.new("PROFILE")


func _ready() -> void:
	_wipe()
	Save.path = SAVE
	Save.load_data()
	Store.simulate = true
	_levels()
	_worlds()
	_achievements()
	_purchases()
	_persistence()
	_reset()
	_old_save()
	_wipe()
	get_tree().quit(t.report())


func _wipe() -> void:
	for s: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + s))


## A finished level, won or lost, without playing it.
func _run(id: String, won: bool, lives: int = 3, score: int = 4000) -> RunSim:
	var wk: Array[int] = Worlds.parse_level_id(id)
	var sim: RunSim = RunSim.new(Worlds.level_spec(wk[0], wk[1]))
	sim.state = RunSim.State.WON if won else RunSim.State.LOST
	sim.lives = lives if won else 0
	sim.score = score
	sim.kills = 30
	sim.perfects = 10
	sim.best_combo = 4
	return sim


func _levels() -> void:
	t.ok(Profile.level_unlocked(0, 0), "the first level is open")
	t.ok(not Profile.level_unlocked(0, 1), "the second opens after the first")
	t.eq(Profile.next_level(), [0, 0] as Array[int], "Play starts at level 1")
	var lost: Dictionary = Profile.finish_level("shore-1", _run("shore-1", false))
	t.ok(not bool(lost["won"]) and not Profile.is_cleared("shore-1"), "a lost level isn't cleared")
	t.eq(Profile.stat("runs"), 1, "it is still counted")
	var r: Dictionary = Profile.finish_level("shore-1", _run("shore-1", true, 1))
	t.ok(Profile.is_cleared("shore-1"), "a win clears the level")
	t.eq(Profile.level_stars("shore-1"), 1, "one shield left: one star")
	t.ok(bool(r["first"]), "the first clear is flagged")
	t.eq(str(r["unlocked"]), "shore-2", "and opens the next level")
	t.ok(Profile.level_unlocked(0, 1), "the next level is open")
	t.eq(Profile.next_level(), [0, 1] as Array[int], "Play moves on")
	var r2: Dictionary = Profile.finish_level("shore-1", _run("shore-1", true, 3, 9000))
	t.eq(Profile.level_stars("shore-1"), 3, "a better clear raises the stars")
	t.eq(int(r2["new_stars"]), 2, "two new stars")
	t.ok(bool(r2["new_best"]), "a new best score is flagged")
	t.eq(Profile.level_best("shore-1"), 9000, "the best score is kept")
	var r3: Dictionary = Profile.finish_level("shore-1", _run("shore-1", true, 1, 100))
	t.eq(Profile.level_stars("shore-1"), 3, "a worse clear keeps the best stars")
	t.eq(int(r3["new_stars"]), 0, "and adds none")
	t.eq(Profile.level_best("shore-1"), 9000, "and keeps the best score")
	t.eq(Profile.total_stars(), 3, "stars add up")
	t.eq(Profile.stat("stars"), 3, "the stars stat matches")
	t.eq(Profile.stat("flawless"), 1, "a three-star clear is counted once")


func _worlds() -> void:
	for k: int in range(1, Worlds.LEVELS_PER_WORLD):
		Profile.finish_level(Worlds.level_id(0, k), _run(Worlds.level_id(0, k), true, 2))
	t.eq(Profile.world_clears(0), 40, "every level of Neon Shore cleared")
	t.eq(Profile.world_stars(0), 3 + 39 * 2, "its stars add up")
	t.ok(Profile.world_unlocked(1), "beating the boss opens the next world")
	t.eq(Profile.stat("bosses"), 1, "the boss is counted")
	t.eq(Profile.next_level(), [1, 0] as Array[int], "Play continues at the next world")
	var again: Dictionary = Profile.finish_level("shore-40", _run("shore-40", true, 3))
	t.ok(not bool(again["world_done"]), "a world is completed once")
	t.eq(Profile.stat("bosses"), 1, "and its boss counted once")
	t.ok(not Profile.world_unlocked(2), "the world after stays closed")
	t.ok(not Profile.all_cleared(), "not everything is cleared")


func _achievements() -> void:
	var got: Array[String] = []
	for id: String in ["first_burst", "levels_40", "perfect_1", "boss_1", "flawless_1", "world_shore"]:
		got.append(str(Profile.achievement_done(id)))
	t.eq(got, ["true", "true", "true", "true", "true", "true"] as Array[String], "awards unlock as you play")
	var before: int = (Save.data["achievements"] as Dictionary).size()
	t.ok(Profile.check_achievements().is_empty(), "awards unlock only once")
	t.eq((Save.data["achievements"] as Dictionary).size(), before, "nothing new on a second check")
	t.eq(Achievements.all().size(), Achievements.BASE.size() + Worlds.count(), "one award per world on top")
	var ids: Dictionary = {}
	for a: Dictionary in Achievements.all():
		ids[a["id"]] = true
	t.eq(ids.size(), Achievements.all().size(), "award ids are unique")


func _purchases() -> void:
	t.ok(not Profile.is_supporter(), "not a Supporter yet")
	Store.buy("tip_50")
	t.eq(Profile.tips_given(), 1, "a tip is counted")
	Store.buy("supporter_pack")
	t.ok(Profile.is_supporter(), "the Supporter pack is owned")
	t.ok(not AdManager.ads_enabled(), "Supporters see no ads")
	t.ok(AdManager.rewarded_ready(), "Supporters revive without a video")
	t.ok(not Profile.owns("theme_pack"), "themes are a separate pack")
	Profile.start_trial("theme_pack")
	t.ok(Profile.owns("theme_pack") and not Profile.bought("theme_pack"), "a video trial lends the pack")
	t.ok(not Profile.trial_clock("theme_pack").is_empty(), "the trial shows a clock")
	Save.data["trials"]["theme_pack"] = 1
	t.ok(not Profile.owns("theme_pack"), "trials run out")
	Store.buy("complete_pack")
	t.ok(Profile.owns("theme_pack") and Profile.owns("style_pack"), "the Complete pack includes everything")
	t.ok(Store.complete_saving() > 0, "the Complete pack is a saving")
	t.eq(Store.all_ids().size(), 4 + 100, "products: 4 packs and 100 tip amounts")
	for id: String in Store.all_ids():
		t.ok(not Store.price(id).is_empty(), "%s has a price" % id)


func _persistence() -> void:
	Save.flush()
	var stars: int = Profile.total_stars()
	Save.data = {}
	Save.load_data()
	t.eq(Profile.total_stars(), stars, "stars survive a restart")
	t.ok(Profile.is_cleared("shore-40") and Profile.is_supporter(), "progress and purchases survive a restart")
	# A corrupt save falls back to the backup.
	Save.flush()
	var f: FileAccess = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	Save.load_data()
	t.eq(Save.recovered_from, "backup", "a corrupt save is recovered from the backup")
	t.ok(Profile.is_cleared("shore-1"), "the backup has the progress")


func _reset() -> void:
	Profile.set_setting("music_volume", 0.25)
	Profile.reset_all()
	t.ok(not Profile.is_cleared("shore-1"), "reset erases progress")
	t.eq(Profile.total_stars(), 0, "and stars")
	t.ok((Save.data["achievements"] as Dictionary).is_empty(), "and awards")
	t.ok(Profile.is_supporter() and Profile.bought("complete_pack"), "reset keeps purchases")
	t.eq(Profile.tips_given(), 1, "and tips")
	t.ok(absf(float(Profile.setting("music_volume")) - 0.25) < 0.001, "and settings")


## A version 1 save (6 stages a world, coins, the Forge) keeps only what
## carries over: settings and purchases.
func _old_save() -> void:
	var old: Dictionary = {
		"version": 1, "coins": 4200, "coins_bought": 500, "forge": {"power": 3},
		"cleared": {"shore-1": {"stars": 7, "best": 5000}}, "owned": {"theme_pack": true},
		"settings": {"music_volume": 0.4}, "tips": 2,
	}
	var f: FileAccess = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	Save.load_data()
	t.eq(int(Save.data["version"]), Save.VERSION, "an old save is moved to the new version")
	t.ok(not Profile.is_cleared("shore-1"), "old stage progress doesn't carry over")
	t.ok(not Save.data.has("coins") and not Save.data.has("forge"), "coins and the Forge are gone")
	t.ok(Profile.bought("theme_pack"), "purchases carry over")
	t.eq(Profile.tips_given(), 2, "tips carry over")
	t.ok(absf(float(Profile.setting("music_volume")) - 0.4) < 0.001, "settings carry over")
