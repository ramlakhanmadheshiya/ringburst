extends SceneTree
## Balance lab: plays every level with the bots and prints a table.
##
##   godot --headless --path . -s res://tools/balance.gd             # every level
##   godot --headless --path . -s res://tools/balance.gd -- 3        # one world (1-8)


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var only: int = int(args[0]) - 1 if args.size() > 0 else -1
	var t0: int = Time.get_ticks_msec()
	var lost: Array[String] = []
	print("level       diff  task                      | perfect bot: won time dmg stars | sloppy: won time dmg stars")
	for w: int in Worlds.count():
		if only >= 0 and w != only:
			continue
		var wins: int = 0
		for k: int in Worlds.LEVELS_PER_WORLD:
			var spec: Dictionary = Worlds.level_spec(w, k)
			var p: Dictionary = Bot.play(spec, "perfect")
			var s: Dictionary = Bot.play(spec, "sloppy")
			if not p["won"]:
				lost.append(spec["id"])
			if s["won"]:
				wins += 1
			var boss_name: String = str((spec["boss"] as Dictionary).get("name", ""))
			print("%-11s %4.2f  %-25s |  %5s %5.1f %2d %d | %5s %5.1f %2d %d" % [
				spec["id"], spec["difficulty"], Worlds.goal_text(spec["goal"], boss_name),
				p["won"], p["time"], p["damage"], p["stars"], s["won"], s["time"], s["damage"], s["stars"]])
		print("-- world %d: sloppy bot wins %d/%d" % [w + 1, wins, Worlds.LEVELS_PER_WORLD])
	print("perfect bot lost: %s" % [lost])
	print("took %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit()
