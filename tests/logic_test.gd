extends SceneTree
## Rules of the deterministic core, checked headless:
## the RNG, ring growth and release, wave hits and reach, PERFECT detection,
## damage, the core and shields, shields on Wardens, splitting, combos and
## whiffs, every kind of level task, Giants and bosses, stars, the 320 levels
## and their curve, replay determinism and the spawn director.
##
##   godot --headless --path . -s res://tests/logic_test.gd

var t: Check = Check.new("LOGIC")


func _init() -> void:
	_rng()
	_ring()
	_reach()
	_perfect()
	_core()
	_shields()
	_splitter()
	_combo()
	_goals()
	_boss()
	_stars()
	_levels()
	_replay()
	_director()
	quit(t.report())


## An empty arena (spawns switched off) to test rules in isolation.
func quiet() -> RunSim:
	var spec: Dictionary = Worlds.level_spec(0, 0)
	spec["mode"] = "tutorial"
	return RunSim.new(spec)


## A level with spawns switched off and the given task.
func task(goal: Dictionary) -> RunSim:
	var spec: Dictionary = Worlds.level_spec(1, 5)
	spec["mode"] = "tutorial"
	var sim: RunSim = RunSim.new(spec)
	sim.spec = spec.duplicate()
	sim.spec["mode"] = "level"
	sim.goal = goal
	return sim


func place(sim: RunSim, type: int, pos: Vector2) -> RunSim.Enemy:
	var e: RunSim.Enemy = sim.spawn_enemy(type, pos, 1.0, 1.0)
	e.hold_r = pos.length() + 1.0
	e.wobble = 0.0
	return e


func steps(sim: RunSim, n: int) -> void:
	for i: int in n:
		sim.step()


## Holds until the ring reaches `r`, then lets go and lets the wave finish.
func fire_at(sim: RunSim, r: float) -> void:
	sim.input_down()
	var guard: int = 0
	while (not sim.charging or sim.ring_r < r) and guard < 600:
		sim.step()
		guard += 1
	sim.input_up()
	steps(sim, 40)


func _rng() -> void:
	var a: Rng = Rng.new(42)
	var b: Rng = Rng.new(42)
	var same: bool = true
	for i: int in 1000:
		if a.next_u32() != b.next_u32():
			same = false
	t.ok(same, "same seed, same sequence")
	t.ok(Rng.new(1).next_u32() != Rng.new(2).next_u32(), "different seeds differ")
	var r: Rng = Rng.new(7)
	var lo: float = 1.0
	var hi: float = 0.0
	var ints_ok: bool = true
	for i: int in 5000:
		var f: float = r.next_float()
		lo = minf(lo, f)
		hi = maxf(hi, f)
		var k: int = r.range_i(3, 9)
		if k < 3 or k > 9:
			ints_ok = false
	t.ok(lo >= 0.0 and hi < 1.0 and lo < 0.01 and hi > 0.99, "floats cover [0, 1)")
	t.ok(ints_ok, "range_i stays in bounds")
	t.eq(Rng.seed_from_text("abc"), Rng.seed_from_text("abc"), "text seeds are stable")
	t.eq(Rng.new(123).next_u32(), 3176825908, "the generator is pinned (cross-platform sequence)")


func _ring() -> void:
	var sim: RunSim = quiet()
	sim.input_down()
	sim.step()
	t.ok(sim.charging and is_equal_approx(sim.ring_r, RunSim.RING_MIN), "holding starts a ring at the core")
	steps(sim, 30)
	t.ok(absf(sim.ring_r - (RunSim.RING_MIN + sim.stats.grow * RunSim.TICK * 30.0)) < 0.01, "the ring grows at the grow speed")
	steps(sim, 600)
	t.ok(is_equal_approx(sim.ring_r, sim.stats.max_r), "the ring stops at its full size")
	sim.input_up()
	sim.step()
	t.ok(not sim.charging, "letting go fires the ring")
	t.eq(sim.waves.size(), 1, "one wave per release")
	t.eq(sim.releases, 1, "the release is counted")
	sim.input_down()
	sim.step()
	t.ok(not sim.charging, "a short cooldown follows a release")
	steps(sim, 10)
	t.ok(sim.charging, "after the cooldown a held finger charges again")
	# A tap shorter than a step still fires a tiny ring.
	var s2: RunSim = quiet()
	s2.input_down()
	s2.input_up()
	steps(s2, 3)
	t.eq(s2.releases, 1, "a quick tap still fires")


func _reach() -> void:
	var sim: RunSim = quiet()
	var near: RunSim.Enemy = place(sim, EnemyTypes.DRIFTER, Vector2(150, 0))
	var far: RunSim.Enemy = place(sim, EnemyTypes.DRIFTER, Vector2(0, 300))
	fire_at(sim, 200.0)
	t.ok(not near.alive, "the wave bursts a shape inside the ring")
	t.ok(far.alive, "a shape beyond the ring is untouched")
	t.eq(sim.kills, 1, "one kill")
	t.ok(sim.score > 0, "kills score")
	var sim2: RunSim = quiet()
	var big: RunSim.Enemy = place(sim2, EnemyTypes.HEAVY, Vector2(120, 0))
	var hp0: float = big.hp
	fire_at(sim2, 300.0)
	t.ok(big.alive and big.hp < hp0, "a Brute survives one plain wave")
	t.ok(absf((hp0 - big.hp) - sim2.stats.damage * (1.0 - EnemyTypes.HEAVY_ARMOUR)) < 0.001, "armour cuts plain-wave damage")
	t.ok(big.pos.length() > 120.0, "waves push shapes back")


func _perfect() -> void:
	var sim: RunSim = quiet()
	var e: RunSim.Enemy = place(sim, EnemyTypes.SHIELDED, Vector2(200, 0))
	e.shield = false
	e.hp = 10.0
	e.max_hp = 10.0
	t.ok(sim.on_edge(e, 200.0), "a ring through the shape's middle is on the edge")
	t.ok(sim.on_edge(e, 200.0 - e.radius - sim.stats.perfect_band() + 0.5), "just short of its near side still counts")
	t.ok(not sim.on_edge(e, 120.0), "a ring well short is not a perfect")
	t.ok(not sim.on_edge(e, 260.0), "a ring well past is not a perfect")
	fire_at(sim, 200.0 - e.radius)
	t.eq(sim.perfects, 1, "releasing on the edge is a PERFECT")
	t.eq(sim.combo, 1, "a perfect raises the combo")
	t.ok(absf((10.0 - e.hp) - 2.0 * sim.stats.damage) < 0.001, "a perfect hits twice as hard")
	var plain: RunSim = quiet()
	var e2: RunSim.Enemy = place(plain, EnemyTypes.SHIELDED, Vector2(80, 0))
	e2.shield = false
	e2.hp = 10.0
	fire_at(plain, 250.0)
	t.eq(plain.perfects, 0, "a ring far past the shape is not a perfect")
	t.ok(absf((10.0 - e2.hp) - plain.stats.damage) < 0.001, "a plain wave does plain damage")
	# Chain sparks jump from a perfect.
	var chain: RunSim = quiet()
	var a: RunSim.Enemy = place(chain, EnemyTypes.SHIELDED, Vector2(200, 0))
	a.shield = false
	a.hp = 10.0
	var b: RunSim.Enemy = place(chain, EnemyTypes.SHIELDED, Vector2(330, 20))
	b.shield = false
	b.hp = 10.0
	fire_at(chain, 200.0 - a.radius)
	t.ok(b.hp < 10.0, "a perfect sparks to a nearby shape beyond the ring")
	# Phased shapes can't be caught.
	var ph: RunSim = quiet()
	var g: RunSim.Enemy = place(ph, EnemyTypes.PHASER, Vector2(200, 0))
	g.phased = true
	t.ok(not ph.on_edge(g, 200.0), "a faded Phantom is never on the edge")


func _core() -> void:
	var sim: RunSim = quiet()
	var e: RunSim.Enemy = sim.spawn_enemy(EnemyTypes.DRIFTER, Vector2(120, 0), 1.0, 1.0)
	e.wobble = 0.0
	sim.combo = 5
	var guard: int = 0
	while sim.lives == 3 and guard < 600:
		sim.step()
		guard += 1
	t.eq(sim.lives, 2, "a shape touching the core breaks a shield")
	t.eq(sim.damage_taken, 1, "damage is counted")
	t.eq(sim.combo, 0, "damage breaks the combo")
	t.ok(not e.alive, "the shape is destroyed on contact")
	t.ok(sim.invuln_t > 0.0, "a moment of safety follows a hit")
	var e2: RunSim.Enemy = sim.spawn_enemy(EnemyTypes.DRIFTER, Vector2(RunSim.CORE_R + 10.0, 0), 1.0, 1.0)
	sim.step()
	t.eq(sim.lives, 2, "no second hit during the safe moment")
	t.ok(not e2.alive, "shapes still pop on the core during it")
	sim.lives = 1
	sim.invuln_t = 0.0
	sim.spawn_enemy(EnemyTypes.DRIFTER, Vector2(RunSim.CORE_R + 5.0, 0), 1.0, 1.0)
	sim.step()
	t.eq(sim.state, RunSim.State.LOST, "losing the last shield ends the run")
	sim.revive()
	t.eq(sim.state, RunSim.State.RUNNING, "a revive resumes the run")
	t.eq(sim.lives, 2, "a revive brings two shields")


func _shields() -> void:
	var sim: RunSim = quiet()
	var w: RunSim.Enemy = place(sim, EnemyTypes.SHIELDED, Vector2(100, 0))
	var hp0: float = w.hp
	fire_at(sim, 300.0)
	t.ok(w.shield and is_equal_approx(w.hp, hp0), "a Warden's shield blocks a plain wave")
	fire_at(sim, w.pos.length() - w.radius)
	t.ok(not w.shield, "a perfect breaks the shield")


func _splitter() -> void:
	var sim: RunSim = quiet()
	var s: RunSim.Enemy = place(sim, EnemyTypes.SPLITTER, Vector2(150, 0))
	s.hp = 0.5
	sim.input_down()
	while not sim.charging or sim.ring_r < 120.0:
		sim.step()
	sim.input_up()
	steps(sim, 10)
	var minis: int = 0
	for e: RunSim.Enemy in sim.enemies:
		if e.alive and e.type == EnemyTypes.MINI:
			minis += 1
	t.ok(not s.alive, "the splitter bursts")
	t.eq(minis, 3, "a splitter leaves three minis")


func _combo() -> void:
	var sim: RunSim = quiet()
	sim.combo = 4
	fire_at(sim, 100.0)
	t.eq(sim.combo, 0, "a release that hits nothing breaks the combo")
	t.eq(sim.whiffs, 1, "whiffs are counted")
	t.ok(absf(sim.multiplier() - 1.0) < 0.001, "no combo, no multiplier")
	sim.combo = 50
	t.ok(absf(sim.multiplier() - 4.0) < 0.001, "the multiplier caps at x4")


func _goals() -> void:
	# Burst shapes.
	var k: RunSim = task({"type": "kills", "n": 2})
	place(k, EnemyTypes.DRIFTER, Vector2(120, 0))
	fire_at(k, 200.0)
	t.ok(k.state == RunSim.State.RUNNING and k.goal_count() == 1, "one of two shapes: still going")
	t.ok(absf(k.goal_progress() - 0.5) < 0.001, "progress is half way")
	place(k, EnemyTypes.DRIFTER, Vector2(0, 120))
	fire_at(k, 200.0)
	t.eq(k.state, RunSim.State.WON, "bursting the shapes clears the level")
	t.eq(k.goal_progress(), 1.0, "a cleared task is complete")
	# PERFECTs.
	var p: RunSim = task({"type": "perfects", "n": 1})
	place(p, EnemyTypes.DRIFTER, Vector2(200, 0))
	fire_at(p, 120.0)
	t.eq(p.state, RunSim.State.RUNNING, "a plain burst isn't a PERFECT")
	var e: RunSim.Enemy = place(p, EnemyTypes.DRIFTER, Vector2(200, 0))
	fire_at(p, 200.0 - e.radius)
	t.eq(p.state, RunSim.State.WON, "landing the PERFECTs clears the level")
	# Survive.
	var s: RunSim = task({"type": "survive", "n": 2})
	steps(s, 60)
	t.eq(s.state, RunSim.State.RUNNING, "one second of two")
	steps(s, 61)
	t.eq(s.state, RunSim.State.WON, "lasting the time clears the level")
	# Combo.
	var c: RunSim = task({"type": "combo", "n": 2})
	for i: int in 2:
		var ce: RunSim.Enemy = place(c, EnemyTypes.DRIFTER, Vector2(0, 220))
		fire_at(c, 220.0 - ce.radius)
	t.eq(c.state, RunSim.State.WON, "two PERFECTs in a row reach a combo of 2")
	# Hunt: only the named shape counts.
	var h: RunSim = task({"type": "hunt", "n": 1, "shape": EnemyTypes.DASHER})
	place(h, EnemyTypes.DRIFTER, Vector2(120, 0))
	fire_at(h, 200.0)
	t.eq(h.goal_count(), 0, "other shapes don't count for a hunt")
	t.eq(h.state, RunSim.State.RUNNING, "the hunt goes on")
	place(h, EnemyTypes.DASHER, Vector2(120, 0))
	fire_at(h, 200.0)
	t.eq(h.state, RunSim.State.WON, "bursting the hunted shape clears the level")
	# Losing beats the task: no shields, no win.
	var l: RunSim = task({"type": "survive", "n": 1})
	l.lives = 1
	l.spawn_enemy(EnemyTypes.DRIFTER, Vector2(RunSim.CORE_R + 5.0, 0), 1.0, 1.0)
	l.step()
	t.eq(l.state, RunSim.State.LOST, "losing every shield loses the level")
	# The tutorial never ends on its own.
	var tut: RunSim = quiet()
	steps(tut, 300)
	t.eq(tut.state, RunSim.State.RUNNING, "the tutorial has no task to finish")


func _boss() -> void:
	var spec: Dictionary = Worlds.level_spec(0, 9)
	t.eq(str(spec["goal"]["type"]), "guardian", "level 10 is a Giant")
	spec["boss_at"] = 3.0
	var sim: RunSim = RunSim.new(spec)
	steps(sim, 2 * 60)
	t.ok(not sim.boss_spawned, "the Giant waits for its moment")
	t.eq(sim.goal_progress(), 0.0, "no progress before it comes")
	steps(sim, 2 * 60)
	t.ok(sim.boss_spawned and sim.boss_alive(), "the Giant arrives")
	for e: RunSim.Enemy in sim.enemies:
		if e.is_boss:
			e.hp = e.max_hp * 0.5
	t.ok(absf(sim.goal_progress() - 0.5) < 0.05, "a boss task counts its health down")
	for e: RunSim.Enemy in sim.enemies:
		if e.is_boss:
			e.hp = 0.01
			e.pos = Vector2(0, -150)
	fire_at(sim, 200.0)
	t.eq(sim.state, RunSim.State.WON, "beating the Giant clears the level")
	t.ok(sim.score >= RunSim.BOSS_SCORE, "the Giant is worth a lot")
	var hspec: Dictionary = Worlds.level_spec(3, 39)
	t.eq(str(hspec["goal"]["type"]), "boss", "level 40 is the boss")
	t.eq(str(hspec["boss"]["name"]), "Hydra", "Fracture's boss is the Hydra")
	hspec["boss_at"] = 2.0
	var hs: RunSim = RunSim.new(hspec)
	steps(hs, 3 * 60)
	for e: RunSim.Enemy in hs.enemies:
		if e.is_boss:
			e.hp = 0.01
			e.pos = Vector2(0, -150)
	fire_at(hs, 200.0)
	var halves: int = 0
	for e: RunSim.Enemy in hs.enemies:
		if e.alive and e.is_boss:
			halves += 1
	t.eq(halves, 2, "the Hydra splits in two")
	t.ok(hs.state != RunSim.State.WON, "the level goes on until both halves are gone")
	for w: int in Worlds.count():
		t.ok(not str(EnemyTypes.BOSSES[w]["name"]).is_empty(), "world %d has a boss" % (w + 1))


func _stars() -> void:
	var sim: RunSim = quiet()
	t.eq(sim.stars(), 0, "no stars before winning")
	sim.state = RunSim.State.WON
	t.eq(sim.stars(), 3, "every shield left: three stars")
	sim.lives = 2
	t.eq(sim.stars(), 2, "two shields: two stars")
	sim.lives = 1
	t.eq(sim.stars(), 1, "one shield: one star")
	sim.lives = 2
	sim.revives = 1
	t.eq(sim.stars(), 1, "a revived level is worth one star")


func _levels() -> void:
	t.eq(Worlds.total_levels(), 320, "8 worlds of 40 levels")
	var ids: Dictionary = {}
	var texts_ok: bool = true
	var round_trip: bool = true
	var types: Dictionary = {}
	for w: int in Worlds.count():
		for k: int in Worlds.LEVELS_PER_WORLD:
			var spec: Dictionary = Worlds.level_spec(w, k)
			ids[spec["id"]] = true
			types[spec["goal"]["type"]] = true
			var boss: String = str((spec["boss"] as Dictionary).get("name", ""))
			if Worlds.goal_text(spec["goal"], boss).is_empty() or int(spec["goal"]["n"]) < 1:
				texts_ok = false
			if Worlds.parse_level_id(spec["id"]) != [w, k]:
				round_trip = false
			if (str(spec["goal"]["type"]) in ["guardian", "boss"]) == (spec["boss"] as Dictionary).is_empty():
				texts_ok = false
	t.eq(ids.size(), 320, "every level has its own id")
	t.ok(texts_ok, "every level has a task (and a boss when the task is one)")
	t.ok(round_trip, "level ids round-trip")
	for g: String in ["kills", "perfects", "survive", "combo", "hunt", "guardian", "boss"]:
		t.ok(types.has(g), "some level asks: %s" % g)
	t.eq(Worlds.parse_level_id("nowhere-3"), [-1, -1], "unknown ids are rejected")
	t.eq(Worlds.goal_type(0, 0), "kills", "the very first level is just bursting shapes")
	t.eq(Worlds.goal_type(2, 0), "hunt", "a world opens by hunting its new shape")
	t.eq(int(Worlds.level_spec(2, 0)["featured"]), 2, "and shows it off first")
	t.eq(Worlds.goal_text({"type": "hunt", "n": 4, "shape": EnemyTypes.SHIELDED}), "Burst 4 Wardens", "hunt text names the shape")
	# The curve climbs: each world harder than the last, levels harder within one.
	var climbs: bool = true
	for w: int in Worlds.count():
		if Worlds.difficulty(w, 38) <= Worlds.difficulty(w, 1):
			climbs = false
		if w > 0 and Worlds.difficulty(w, 5) <= Worlds.difficulty(w - 1, 5):
			climbs = false
	t.ok(climbs, "difficulty climbs through each world and from world to world")
	t.ok(Worlds.difficulty(0, 10) < Worlds.difficulty(0, 9), "the level after a Giant eases off")
	var bigger: bool = Worlds.goal(0, 36)["n"] > Worlds.goal(0, 6)["n"] and Worlds.goal(5, 1)["n"] > Worlds.goal(0, 1)["n"]
	t.ok(bigger, "tasks grow through a world and from world to world")
	t.ok(Director.new(Worlds.level_spec(0, 3)).hp_mult() == 1.0, "shapes are one hit in the first world")
	t.ok(Director.new(Worlds.level_spec(5, 3)).hp_mult() > 1.0, "deeper worlds bring tougher shapes")


func _replay() -> void:
	var spec: Dictionary = Worlds.level_spec(2, 13)
	var a: Dictionary = Bot.play(spec, "perfect")
	var b: Dictionary = Bot.play(Worlds.level_spec(2, 13), "perfect")
	t.eq(a, b, "the same level replays identically")
	# Spawns don't depend on what the player does.
	var s1: Array = _spawn_log(spec, "perfect")
	var s2: Array = _spawn_log(spec, "idle")
	t.ok(s1.size() > 20, "spawns happen")
	var n: int = mini(s1.size(), s2.size())
	t.eq(s1.slice(0, n), s2.slice(0, n), "the director brings the same shapes whatever the player does")


func _spawn_log(spec: Dictionary, kind: String) -> Array:
	var sim: RunSim = RunSim.new(spec)
	var bot: Bot = Bot.new("perfect", 1)
	var out: Array = []
	while sim.t < 40.0 and not sim.is_over():
		if kind != "idle":
			bot.act(sim)
		sim.step()
		for ev: Dictionary in sim.events:
			if ev["t"] == "spawn" and int(ev["type"]) != EnemyTypes.MINI:
				out.append("%d@%.1f,%.1f" % [int(ev["type"]), (ev["pos"] as Vector2).x, (ev["pos"] as Vector2).y])
	return out


func _director() -> void:
	var spec: Dictionary = Worlds.level_spec(4, 29)
	var a: Director = Director.new(spec)
	var b: Director = Director.new(Worlds.level_spec(4, 29))
	var la: Array = []
	var lb: Array = []
	for i: int in 60 * 60:
		for r: Dictionary in a.step(RunSim.TICK):
			la.append(str(r.get("type", "boss")) + str(r["pos"]))
		for r: Dictionary in b.step(RunSim.TICK):
			lb.append(str(r.get("type", "boss")) + str(r["pos"]))
	t.eq(la, lb, "the director is deterministic")
	t.ok(a.boss_spawned, "the director sends the Giant")
	t.ok(la.size() > 20 and la.size() < 800, "a sensible number of spawns (%d)" % la.size())
	var none: Director = Director.new(Worlds.level_spec(4, 28))
	for i: int in 60 * 60:
		none.step(RunSim.TICK)
	t.ok(not none.boss_spawned, "no boss on an ordinary level")
	var outside: bool = true
	for k: int in 200:
		var p: Vector2 = Director.edge_point(float(k) / 200.0)
		if absf(p.x) < Director.EDGE_HALF.x - 0.01 and absf(p.y) < Director.EDGE_HALF.y - 0.01:
			outside = false
	t.ok(outside, "shapes enter from just outside the arena")
	# Smooth rate: calm start, busy end.
	var d: Director = Director.new(Worlds.level_spec(2, 13))
	d.t = 3.0
	var early: float = d.base_rate()
	d.t = d.length()
	var late: float = d.base_rate()
	t.ok(late > early * 1.5, "the spawn rate climbs through a level")
	t.ok(Director.new(Worlds.level_spec(6, 13)).base_rate() > Director.new(Worlds.level_spec(1, 13)).base_rate(), "deeper worlds are busier")
