extends SceneTree
## Level difficulty, verified by bots playing all 320 levels (headless, ~15 s):
## - a precise bot beats every level, nearly always with three stars;
## - a sloppy bot (human pauses, late and imprecise, never aims for
##   perfects) cruises through world 1, wins nearly every level of worlds
##   1-6, and loses some in the last two worlds: the curve really climbs;
## - levels are short (a task takes well under two minutes);
## - each world sends more threat than the one before.
##
##   godot --headless --path . -s res://tests/balance_test.gd

var t: Check = Check.new("BALANCE")


func _init() -> void:
	var t0: int = Time.get_ticks_msec()
	var sloppy_damage: Array[float] = []
	var sloppy_wins_mid: int = 0
	var mid_levels: int = 0
	var sloppy_losses_late: int = 0
	var precise_stars: int = 0
	var prev_world_threat: float = -1.0
	var worlds_rising: bool = true
	var longest: float = 0.0
	var total_time: float = 0.0
	for w: int in Worlds.count():
		var dmg: float = 0.0
		var world_threat: float = 0.0
		for k: int in Worlds.LEVELS_PER_WORLD:
			var spec: Dictionary = Worlds.level_spec(w, k)
			var id: String = spec["id"]
			var p: Dictionary = Bot.play(spec, "perfect")
			t.ok(bool(p["won"]), "%s: the precise bot wins (lost at %.0f s)" % [id, float(p["time"])])
			precise_stars += int(p["stars"])
			longest = maxf(longest, float(p["time"]))
			total_time += float(p["time"])
			var s: Dictionary = Bot.play(spec, "sloppy")
			dmg += float(s["damage"])
			if w == 0:
				t.ok(bool(s["won"]) and int(s["stars"]) >= 2, "%s: world 1 is gentle for a sloppy beginner" % id)
			elif w < Worlds.count() - 2:
				mid_levels += 1
				if bool(s["won"]):
					sloppy_wins_mid += 1
			elif not bool(s["won"]):
				sloppy_losses_late += 1
			world_threat += _threat(spec)
		if world_threat <= prev_world_threat:
			worlds_rising = false
		prev_world_threat = world_threat
		sloppy_damage.append(dmg / float(Worlds.LEVELS_PER_WORLD))
	var n: float = float(Worlds.total_levels())
	t.ok(precise_stars >= int(n * 3.0 * 0.95), "a precise player earns nearly every star (%d of %d)" % [precise_stars, int(n) * 3])
	t.ok(worlds_rising, "each world sends more threat than the one before")
	t.ok(sloppy_wins_mid >= int(mid_levels * 0.95), "a sloppy player wins nearly every level of worlds 2-6 (%d of %d)" % [sloppy_wins_mid, mid_levels])
	t.ok(sloppy_losses_late >= 3, "the last two worlds beat a sloppy player sometimes (%d losses)" % sloppy_losses_late)
	var early: float = (sloppy_damage[0] + sloppy_damage[1]) / 2.0
	var late: float = (sloppy_damage[Worlds.count() - 1] + sloppy_damage[Worlds.count() - 2]) / 2.0
	t.ok(late > early + 0.5, "a sloppy player takes more hits late (%.2f a level) than early (%.2f)" % [late, early])
	t.ok(longest < 120.0, "every level takes under two minutes (longest %.0f s)" % longest)
	t.ok(total_time / n < 45.0, "levels are short (%.0f s on average)" % (total_time / n))
	print("balance took %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(t.report())


## How hard a level pushes: threat (cost x health) per second over its
## length, after the opening moments.
func _threat(spec: Dictionary) -> float:
	var d: Director = Director.new(spec)
	var sum: float = 0.0
	var length: float = maxf(20.0, float(spec["length"]))
	while d.t < length:
		for r: Dictionary in d.step(RunSim.TICK):
			if r.has("type") and d.t > 5.0:
				sum += float(EnemyTypes.info(int(r["type"]))["cost"]) * float(r["hp"])
	return sum / (length - 5.0)
