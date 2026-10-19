extends SceneTree
## Balance lab: plays every stage with the bots and prints a table.
##
##   godot --headless --path . -s res://tools/balance.gd             # every stage
##   godot --headless --path . -s res://tools/balance.gd -- 3        # one world (1-8)


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var only: int = int(args[0]) - 1 if args.size() > 0 else -1
	var t0: int = Time.get_ticks_msec()
	print("stage        diff  | perfect bot: won  time  dmg lvl combo perf/rel score coins | sloppy: won time dmg")
	for w: int in Worlds.count():
		if only >= 0 and w != only:
			continue
		for k: int in Worlds.STAGES_PER_WORLD:
			var spec: Dictionary = Worlds.stage_spec(w, k)
			var p: Dictionary = Bot.play(spec, RunStats.make(), "perfect")
			var s: Dictionary = Bot.play(spec, RunStats.make(), "sloppy")
			var m: Dictionary = Bot.play(spec, RunStats.make(Bot.typical_forge(w)), "sloppy")
			print("%-12s %4.2f  |  %5s %5.1f %3d %3d %4d  %3d/%-3d %6d %4d | %5s %5.1f %3d | meta sloppy %5s %3d" % [
				spec["id"], spec["difficulty"], p["won"], p["time"], p["damage"], p["level"], p["best_combo"],
				p["perfects"], p["releases"], p["score"], p["coins"], s["won"], s["time"], s["damage"], m["won"], m["damage"]])
	print("took %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit()
