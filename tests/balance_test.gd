extends SceneTree
## Stage difficulty, verified by bots playing every stage (headless, ~15 s):
## - a precise bot with no Forge upgrades beats all 48 stages;
## - a sloppy bot (late, imprecise, never aims for perfects) with the Forge
##   levels a player could plausibly own by each world also beats all 48;
## - the same sloppy bot with no Forge upgrades cruises through world 1 but
##   is overwhelmed in the last two worlds: the curve really climbs;
## - the spawn director's threat climbs stage by stage through the campaign;
## - Endless keeps going and keeps getting harder.
##
##   godot --headless --path . -s res://tests/balance_test.gd

var t: Check = Check.new("BALANCE")


func _init() -> void:
	var t0: int = Time.get_ticks_msec()
	var sloppy_damage: Array[float] = []
	var sloppy_losses_late: int = 0
	var prev_threat: float = -1.0
	var threat_rising: bool = true
	var prev_world_threat: float = -1.0
	var worlds_rising: bool = true
	for w: int in Worlds.count():
		var dmg: float = 0.0
		var world_threat: float = 0.0
		for k: int in Worlds.STAGES_PER_WORLD:
			var spec: Dictionary = Worlds.stage_spec(w, k)
			var id: String = spec["id"]
			var p: Dictionary = Bot.play(spec, RunStats.make(), "perfect")
			t.ok(bool(p["won"]), "%s: the precise bot wins (lost at %.0f s)" % [id, float(p["time"])])
			t.ok(int(p["level"]) >= 2, "%s: a run gets upgrades (%d)" % [id, int(p["level"])])
			var m: Dictionary = Bot.play(spec, RunStats.make(Bot.typical_forge(w)), "sloppy")
			t.ok(bool(m["won"]), "%s: a sloppy player with some Forge levels wins" % id)
			var s: Dictionary = Bot.play(spec, RunStats.make(), "sloppy")
			dmg += float(s["damage"])
			if w == 0:
				t.ok(bool(s["won"]) and int(s["damage"]) == 0, "%s: world 1 is gentle for a sloppy beginner" % id)
			if w >= Worlds.count() - 2 and not bool(s["won"]):
				sloppy_losses_late += 1
			var curve: float = _curve(spec)
			if curve <= prev_threat:
				threat_rising = false
				t.ok(false, "%s: intensity %.2f should exceed the stage before (%.2f)" % [id, curve, prev_threat])
			prev_threat = curve
			world_threat += _threat(spec)
		if world_threat <= prev_world_threat:
			worlds_rising = false
		prev_world_threat = world_threat
		sloppy_damage.append(dmg / float(Worlds.STAGES_PER_WORLD))
	t.ok(threat_rising, "the director's curve climbs through every stage of the campaign")
	t.ok(worlds_rising, "each world sends more threat than the one before")
	t.ok(sloppy_losses_late >= 3, "the last two worlds overwhelm a sloppy player without upgrades (%d losses)" % sloppy_losses_late)
	var early: float = (sloppy_damage[0] + sloppy_damage[1]) / 2.0
	var late: float = (sloppy_damage[Worlds.count() - 1] + sloppy_damage[Worlds.count() - 2]) / 2.0
	t.ok(late > early + 1.0, "a sloppy player takes more hits late (%.1f) than early (%.1f)" % [late, early])
	# Endless: lasts a while with a precise player, and the pressure keeps rising.
	var e: Dictionary = Bot.play(Worlds.endless_spec(77), RunStats.make(), "perfect", 300.0)
	t.ok(float(e["time"]) > 150.0, "a precise player lasts over 2.5 minutes in Endless (%.0f s)" % float(e["time"]))
	var d: Director = Director.new(Worlds.endless_spec(77))
	var r0: float = d.rate()
	d.t = 240.0
	t.ok(d.rate() > r0 * 2.0 and d.hp_mult() > 3.0, "Endless ramps up")
	print("balance took %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(t.report())


## The designed intensity of a stage: mean spawn rate x shape health.
func _curve(spec: Dictionary) -> float:
	var d: Director = Director.new(spec)
	var sum: float = 0.0
	var n: int = 0
	var tt: float = 10.0
	while tt < float(spec["duration"]):
		d.t = tt
		sum += d.base_rate() * d.hp_mult()
		n += 1
		tt += 0.5
	return sum / float(n)


## How hard a stage pushes before its boss: threat (cost x health) per
## second, after the opening moments.
func _threat(spec: Dictionary) -> float:
	var d: Director = Director.new(spec)
	var sum: float = 0.0
	while d.t < float(spec["duration"]):
		for r: Dictionary in d.step(RunSim.TICK):
			if r.has("type") and d.t > 10.0:
				sum += float(EnemyTypes.info(int(r["type"]))["cost"]) * float(r["hp"])
	return sum / (float(spec["duration"]) - 10.0)
