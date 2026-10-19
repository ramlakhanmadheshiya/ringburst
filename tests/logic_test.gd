extends SceneTree
## Rules of the deterministic core, checked headless:
## the RNG, ring growth and release, wave hits and reach, PERFECT detection,
## damage, the core and shields, shields on Wardens, splitting, upgrade effects
## and offers, XP and level-ups, combos and whiffs, bosses and winning, stars,
## replay determinism, the spawn director and the Daily Run.
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
	_upgrades()
	_offers()
	_xp()
	_combo()
	_boss()
	_stars()
	_replay()
	_director()
	_daily()
	quit(t.report())


## An empty arena (spawns switched off) to test rules in isolation.
func quiet(stats: RunStats = null) -> RunSim:
	var spec: Dictionary = Worlds.stage_spec(0, 0)
	spec["mode"] = "tutorial"
	return RunSim.new(spec, stats if stats != null else RunStats.make())


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
	t.ok(sim.at_max_t > 5.0, "time at full size is counted")
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
	var pierce: RunStats = RunStats.make()
	pierce.add("pierce")
	var sim2: RunSim = quiet(pierce)
	var w2: RunSim.Enemy = place(sim2, EnemyTypes.SHIELDED, Vector2(100, 0))
	fire_at(sim2, 300.0)
	t.ok(w2.hp < hp0, "Pierce Armour gets plain waves through shields")


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


func _upgrades() -> void:
	var base: RunStats = RunStats.make()
	var s: RunStats = RunStats.make()
	s.add("heavy_wave")
	t.ok(absf(s.damage - base.damage * 1.3) < 0.001, "Heavy Wave adds 30% damage")
	s.add("quick_charge")
	t.ok(s.grow > base.grow, "Quick Charge grows the ring faster")
	s.add("long_reach")
	t.ok(s.max_r > base.max_r, "Long Reach makes the ring bigger")
	s.add("wide_band")
	t.ok(s.perfect_band() > base.perfect_band(), "Sharp Eye widens the perfect window")
	var forge: RunStats = RunStats.make({"power": 5, "shield": 2, "reach": 5})
	t.eq(forge.max_lives, 5, "Forge shields add to the start")
	t.ok(forge.damage > base.damage and forge.max_r > base.max_r, "Forge power and reach apply")
	var twin: RunStats = RunStats.make({}, "twin")
	t.eq(twin.level("echo"), 1, "the Twin ring starts with Echo")
	var perk: RunStats = RunStats.make({}, "classic", "frost")
	t.eq(perk.level("frost"), 1, "a starting perk is owned from the start")
	# Echo: more waves per release.
	var es: RunStats = RunStats.make()
	es.add("echo")
	var sim: RunSim = quiet(es)
	sim.input_down()
	steps(sim, 20)
	sim.input_up()
	sim.step()
	t.eq(sim.waves.size(), 2, "Echo adds a second wave")
	# Frost slows.
	var fs: RunStats = RunStats.make()
	fs.add("frost")
	var fsim: RunSim = quiet(fs)
	var fe: RunSim.Enemy = fsim.spawn_enemy(EnemyTypes.HEAVY, Vector2(250, 0), 3.0, 1.0)
	fe.wobble = 0.0
	fire_at(fsim, 300.0)
	t.ok(fe.slow_t > 0.0, "Frost Ring slows what it hits")
	# Thorns.
	var ts: RunStats = RunStats.make()
	ts.add("thorns")
	var tsim: RunSim = quiet(ts)
	var te: RunSim.Enemy = place(tsim, EnemyTypes.HEAVY, Vector2(80, 0))
	var thp: float = te.hp
	steps(tsim, 60)
	t.ok(te.hp < thp, "Thorns hurt shapes near the core")
	# Shield regen.
	var rs: RunStats = RunStats.make()
	rs.add("regen")
	var rsim: RunSim = quiet(rs)
	rsim.lives = 2
	steps(rsim, int(18.5 * 60.0))
	t.eq(rsim.lives, 3, "Shield Regen brings a shield back")
	# Second wind.
	var sw: RunStats = RunStats.make()
	sw.add("second_wind")
	var swsim: RunSim = quiet(sw)
	swsim.lives = 1
	swsim.spawn_enemy(EnemyTypes.DRIFTER, Vector2(RunSim.CORE_R + 5.0, 0), 1.0, 1.0)
	swsim.step()
	t.ok(swsim.state == RunSim.State.RUNNING and swsim.lives == 1, "Second Wind survives a fatal hit")
	# Ricochet and split send follow-up waves.
	var rc: RunStats = RunStats.make()
	rc.add("ricochet")
	rc.add("split")
	var rcsim: RunSim = quiet(rc)
	rcsim.input_down()
	steps(rcsim, 20)
	rcsim.input_up()
	var kinds: Dictionary = {}
	for i: int in 12:
		rcsim.step()
		for w: RunSim.Wave in rcsim.waves:
			kinds[w.kind] = true
	t.ok(kinds.has(RunSim.WaveKind.RETURN) and kinds.has(RunSim.WaveKind.ARCS), "Ricochet and Split follow the wave")
	# Satellites cut what they touch.
	var os: RunStats = RunStats.make()
	os.add("orbit")
	var osim: RunSim = quiet(os)
	var oe: RunSim.Enemy = place(osim, EnemyTypes.HEAVY, Vector2(RunSim.SHARD_RADIUS, 0))
	var ohp: float = oe.hp
	steps(osim, 180)
	t.ok(oe.hp < ohp, "Satellites cut shapes on their orbit")
	# Overcharge.
	var oc: RunStats = RunStats.make()
	oc.add("overcharge")
	var ocsim: RunSim = quiet(oc)
	ocsim.input_down()
	steps(ocsim, 300)
	t.ok(ocsim.overcharge_bonus() > 0.49, "Overcharge builds up at full size")


func _offers() -> void:
	var rng: Rng = Rng.new(5)
	var owned: Dictionary = {}
	var distinct: bool = true
	var no_syn: bool = true
	for i: int in 200:
		var o: Array = Upgrades.offer(rng, owned, 3)
		var seen: Dictionary = {}
		for id: Variant in o:
			if seen.has(id):
				distinct = false
			seen[id] = true
			if Upgrades.def(str(id)).has("requires"):
				no_syn = false
	t.ok(distinct, "offers never repeat an upgrade")
	t.ok(no_syn, "synergies need their parts first")
	t.eq(Upgrades.ids().size(), 30, "30 upgrades in the pool")
	t.eq(Upgrades.synergy_ids().size(), 4, "4 synergies")
	owned = {"frost": 1, "static": 1}
	t.ok(Upgrades.can_offer("shatter", owned), "Shatter is offered once Frost and Static are owned")
	owned["heavy_wave"] = Upgrades.max_level("heavy_wave")
	t.ok(not Upgrades.can_offer("heavy_wave", owned), "a maxed upgrade is not offered again")
	var found_syn: bool = false
	for i: int in 50:
		if Upgrades.offer(rng, owned, 3).has("shatter"):
			found_syn = true
	t.ok(found_syn, "an unlocked synergy turns up")
	for id: String in Upgrades.ids():
		t.ok(not Upgrades.describe(id, 1).is_empty(), "%s has a description" % id)
		t.ok(ResourceLoader.exists("res://assets/icons/%s.svg" % str(Upgrades.def(id)["icon"])), "%s has an icon" % id)


func _xp() -> void:
	var sim: RunSim = quiet()
	for i: int in 8:
		var e: RunSim.Enemy = place(sim, EnemyTypes.DASHER, Vector2.from_angle(TAU * i / 8.0) * 150.0)
		e.timer = 999.0
	fire_at(sim, 200.0)
	steps(sim, 30)
	t.ok(sim.xp > 0.0 or sim.level > 0, "gems pulled in by the wave give XP")
	sim.xp = sim.xp_needed() - 0.5
	var g: RunSim.Gem = RunSim.Gem.new()
	g.pos = Vector2(60, 0)
	g.value = 1
	sim.gems.append(g)
	steps(sim, 20)
	t.eq(sim.state, RunSim.State.CHOOSING, "a full XP bar pauses for an upgrade choice")
	t.eq(sim.offers.size(), 3, "three upgrades are offered")
	var pick: String = sim.offers[0]
	sim.choose(0)
	t.eq(sim.stats.level(pick), 1, "choosing takes the upgrade")
	t.eq(sim.state, RunSim.State.RUNNING, "the run resumes")
	sim.pending_levels = 1
	sim.state = RunSim.State.CHOOSING
	sim.rerolls_left = 1
	var before: Array = sim.offers.duplicate()
	t.ok(sim.reroll(), "a reroll swaps the offers")
	t.ok(not sim.reroll(), "rerolls run out")
	t.ok(before != sim.offers or before.is_empty(), "rerolled offers differ")


func _combo() -> void:
	var sim: RunSim = quiet()
	sim.combo = 4
	fire_at(sim, 100.0)
	t.eq(sim.combo, 0, "a release that hits nothing breaks the combo")
	t.eq(sim.whiffs, 1, "whiffs are counted")
	var keep: RunStats = RunStats.make()
	keep.add("combo_keeper")
	var sim2: RunSim = quiet(keep)
	sim2.combo = 4
	fire_at(sim2, 100.0)
	t.eq(sim2.combo, 4, "Steady Hands keeps the combo through a whiff")
	t.ok(absf(sim.multiplier() - 1.0) < 0.001, "no combo, no multiplier")
	sim.combo = 50
	t.ok(absf(sim.multiplier() - 4.0) < 0.001, "the multiplier caps at x4")


func _boss() -> void:
	var spec: Dictionary = Worlds.stage_spec(0, 1)
	spec["duration"] = 3.0
	var sim: RunSim = RunSim.new(spec, RunStats.make())
	steps(sim, 4 * 60)
	t.ok(sim.boss_spawned and sim.boss_alive(), "the boss arrives when the stage timer runs out")
	for e: RunSim.Enemy in sim.enemies:
		if e.is_boss:
			e.hp = 0.01
			e.pos = Vector2(0, -150)
	fire_at(sim, 200.0)
	t.eq(sim.state, RunSim.State.WON, "beating the boss clears the stage")
	t.ok(sim.score >= RunSim.BOSS_SCORE, "the boss is worth a lot")
	var hspec: Dictionary = Worlds.stage_spec(3, 5)
	hspec["duration"] = 2.0
	var hs: RunSim = RunSim.new(hspec, RunStats.make())
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
	t.ok(hs.state != RunSim.State.WON, "the stage goes on until both halves are gone")
	t.eq(Worlds.total_stages(), 48, "48 stages")
	for w: int in Worlds.count():
		t.ok(not str(EnemyTypes.BOSSES[w]["name"]).is_empty(), "world %d has a boss" % (w + 1))


func _stars() -> void:
	var sim: RunSim = quiet()
	t.eq(sim.stars_mask(), 0, "no stars before winning")
	sim.state = RunSim.State.WON
	sim.best_combo = 99
	t.eq(sim.stars_mask(), 7, "clear + no damage + combo = all three stars")
	sim.damage_taken = 1
	sim.best_combo = 0
	t.eq(sim.stars_mask(), 1, "clearing alone is one star")
	t.eq(Economy.star_count(5), 2, "star_count counts bits")


func _replay() -> void:
	var spec: Dictionary = Worlds.stage_spec(2, 3)
	var a: Dictionary = Bot.play(spec, RunStats.make(), "perfect")
	var b: Dictionary = Bot.play(Worlds.stage_spec(2, 3), RunStats.make(), "perfect")
	t.eq(a, b, "the same run replays identically")
	# Spawns don't depend on what the player does.
	var s1: Array = _spawn_log(spec, "perfect")
	var s2: Array = _spawn_log(spec, "idle")
	t.ok(s1.size() > 20, "spawns happen")
	var n: int = mini(s1.size(), s2.size())
	t.eq(s1.slice(0, n), s2.slice(0, n), "the director brings the same shapes whatever the player does")


func _spawn_log(spec: Dictionary, kind: String) -> Array:
	var sim: RunSim = RunSim.new(spec, RunStats.make())
	var bot: Bot = Bot.new("perfect", 1)
	var out: Array = []
	while sim.t < 40.0 and not sim.is_over():
		if kind != "idle":
			bot.act(sim)
		elif sim.state == RunSim.State.CHOOSING:
			sim.choose(0)
		sim.step()
		for ev: Dictionary in sim.events:
			if ev["t"] == "spawn" and int(ev["type"]) != EnemyTypes.MINI:
				out.append("%d@%.1f,%.1f" % [int(ev["type"]), (ev["pos"] as Vector2).x, (ev["pos"] as Vector2).y])
	return out


func _director() -> void:
	var spec: Dictionary = Worlds.stage_spec(4, 2)
	var a: Director = Director.new(spec)
	var b: Director = Director.new(Worlds.stage_spec(4, 2))
	var la: Array = []
	var lb: Array = []
	for i: int in 120 * 60:
		for r: Dictionary in a.step(RunSim.TICK):
			la.append(str(r.get("type", "boss")) + str(r["pos"]))
		for r: Dictionary in b.step(RunSim.TICK):
			lb.append(str(r.get("type", "boss")) + str(r["pos"]))
	t.eq(la, lb, "the director is deterministic")
	t.ok(a.boss_spawned, "the director sends the boss")
	t.ok(la.size() > 60 and la.size() < 600, "a sensible number of spawns (%d)" % la.size())
	var outside: bool = true
	for k: int in 200:
		var p: Vector2 = Director.edge_point(float(k) / 200.0)
		if absf(p.x) < Director.EDGE_HALF.x - 0.01 and absf(p.y) < Director.EDGE_HALF.y - 0.01:
			outside = false
	t.ok(outside, "shapes enter from just outside the arena")
	# Smooth rate: calm start, busy end.
	var d: Director = Director.new(spec)
	d.t = 10.0
	var early: float = d.rate()
	d.t = 70.0
	var late: float = d.rate()
	t.ok(late > early * 1.5, "the spawn rate climbs through a stage")
	var e: Director = Director.new(Worlds.endless_spec(9))
	e.t = 300.0
	t.ok(e.difficulty() > Director.new(Worlds.endless_spec(9)).difficulty() + 5.0, "Endless keeps getting harder")


func _daily() -> void:
	var a: Dictionary = Worlds.daily_spec("2026-10-19")
	var b: Dictionary = Worlds.daily_spec("2026-10-19")
	t.eq(a, b, "the daily is built from the date alone")
	t.ok(a["seed"] != Worlds.daily_spec("2026-10-20")["seed"], "each date has its own run")
	# Pinned so an accidental change to the generator is caught.
	t.eq(int(a["seed"]), 99418496, "the 2026-10-19 daily is pinned (seed)")
	t.eq(str(a["modifier"]), "precision", "the 2026-10-19 daily is pinned (modifier)")
	var mods: Dictionary = {}
	var ok: bool = true
	var monday: float = 0.0
	var sunday: float = 0.0
	for day: int in 365:
		var key: String = Worlds.date_key_from_day(day + 280)
		var s: Dictionary = Worlds.daily_spec(key)
		mods[s["modifier"]] = true
		if not Worlds.MODIFIERS.has(s["modifier"]) or int(s["world"]) < 0 or int(s["world"]) >= Worlds.count():
			ok = false
		var wd: int = int(Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_datetime_dict({"year": key.substr(0, 4).to_int(), "month": key.substr(5, 2).to_int(), "day": key.substr(8, 2).to_int(), "hour": 12}))["weekday"])
		if wd == 1:
			monday = float(s["difficulty"])
		elif wd == 0:
			sunday = float(s["difficulty"])
	t.ok(ok, "a year of dailies is valid")
	t.eq(mods.size(), Worlds.MODIFIERS.size(), "every modifier comes round")
	t.ok(sunday > monday, "Sunday's daily is harder than Monday's")
	var r1: Dictionary = Bot.play(a, RunStats.make(), "perfect")
	var r2: Dictionary = Bot.play(Worlds.daily_spec("2026-10-19"), RunStats.make(), "perfect")
	t.eq(r1["score"], r2["score"], "the same daily plays out the same for everyone")
	t.ok(bool(r1["won"]), "a strong player can win the daily")
	t.eq(Worlds.day_number(Worlds.date_key_from_day(400)), 400, "day numbers round-trip")
