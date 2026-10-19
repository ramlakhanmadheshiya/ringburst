class_name RunSim
extends RefCounted
## One run of Ringburst, simulated deterministically at a fixed 60 Hz.
##
## The glowing core sits at (0, 0). HOLD grows a ring outward from the core;
## RELEASE fires it as a shockwave that damages every shape it passes, out to
## the radius the ring had. If a shape sits on the ring's edge at the moment of
## release, it is a PERFECT: the wave hits twice as hard, sparks chain to
## nearby shapes and the combo rises (it multiplies score). A shape that
## touches the core costs a shield; lose them all and the run is over.
##
## Nothing here touches the engine's scene tree, clocks or random numbers:
## the same spec, stats and inputs always give the same run. The arena draws
## from this state and plays the `events` it leaves after each step; the tests
## and the bot drive it directly.

const TICK: float = 1.0 / 60.0
const CORE_R: float = 34.0
const RING_MIN: float = 42.0
const COOLDOWN: float = 0.12
const MAX_ENEMIES: int = 110
const MAX_GEMS: int = 140
const INVULN: float = 1.3
const ARENA_HALF: Vector2 = Vector2(360.0, 560.0)
const ECHO_DELAY: float = 0.22
const ECHO_DAMAGE: float = 0.6
const CHAIN_RANGE: float = 210.0
const PERFECT_BONUS: int = 10
const BOSS_SCORE: int = 1000
const LIFE_BONUS: int = 250
const SHARD_RADIUS: float = 100.0
const SHARD_SIZE: float = 13.0
## A wave reaches a little past the ring it was fired from.
const REACH_SLACK: float = 6.0

enum State { RUNNING, CHOOSING, WON, LOST }
enum WaveKind { MAIN, ECHO, RETURN, PULSE, ARCS }


class Enemy:
	extends RefCounted
	var id: int = 0
	var type: int = 0
	var is_boss: bool = false
	var boss: Dictionary = {}
	var sides: int = 3
	var pos: Vector2 = Vector2.ZERO
	var radius: float = 16.0
	var hp: float = 1.0
	var max_hp: float = 1.0
	var speed: float = 50.0
	var hp_scale: float = 1.0
	var speed_scale: float = 1.0
	var shield: bool = false
	var shield_t: float = 0.0
	var armour: float = 0.0
	var kb_resist: float = 0.0
	var alive: bool = true
	var age: float = 0.0
	var timer: float = 0.0
	var mode: int = 0
	var dir: Vector2 = Vector2.ZERO
	var spin: float = 1.0
	var phased: bool = false
	var slow_t: float = 0.0
	var stun_t: float = 0.0
	var burn_t: float = 0.0
	var burn_dps: float = 0.0
	var hit_flash: float = 0.0
	var emit_t: float = 0.0
	var lunge_t: float = 0.0
	var shard_t: float = 0.0
	var wobble: float = 0.0
	## Tutorial shapes stop at this distance (0 = never stop).
	var hold_r: float = 0.0
	var score: int = 0
	var xp: int = 0
	var color: int = 0


class Wave:
	extends RefCounted
	var id: int = 0
	var kind: int = 0
	var r: float = 0.0
	var start_r: float = 0.0
	var max_r: float = 0.0
	var speed: float = 1500.0
	var damage: float = 1.0
	var crit: bool = false
	var delay: float = 0.0
	var linger: float = 0.0
	var lingering: bool = false
	var burning: bool = false
	var done: bool = false
	var spawned_followups: bool = false
	var hits: int = 0
	var hit: Dictionary = {}
	var arcs: PackedFloat32Array = PackedFloat32Array()
	var arc_w: float = 0.5


class Gem:
	extends RefCounted
	var pos: Vector2 = Vector2.ZERO
	var value: int = 1
	var pulled: bool = false
	var alive: bool = true
	var age: float = 0.0
	var speed: float = 0.0


var spec: Dictionary
var stats: RunStats
var director: Director
var rng: Rng
var offer_rng: Rng
var state: int = State.RUNNING

var t: float = 0.0
var ticks: int = 0
var enemies: Array[Enemy] = []
var waves: Array[Wave] = []
var gems: Array[Gem] = []
var events: Array[Dictionary] = []

var lives: int = 3
var invuln_t: float = 0.0
var charging: bool = false
var ring_r: float = 0.0
var at_max_t: float = 0.0
var cooldown_t: float = 0.0
var combo: int = 0
var best_combo: int = 0
var score: int = 0
var kills: int = 0
var perfects: int = 0
var releases: int = 0
var whiffs: int = 0
var damage_taken: int = 0
var xp: float = 0.0
var level: int = 0
var pending_levels: int = 0
var offers: Array = []
var rerolls_left: int = 0
var revives: int = 0
var bosses_killed: int = 0
var boss_spawned: bool = false
var shard_angle: float = 0.0

var _want_hold: bool = false
var _press_queued: bool = false
var _charge_ticks: int = 0
var _next_id: int = 1
var _queue: Array = []
var _regen_t: float = 0.0
var _pulse_t: float = 0.0
var _thorns_t: float = 0.0
var _lifeline_n: int = 0
var _second_wind_used: bool = false
var _crit_mult: float = 2.0
var _score_mult: float = 1.0
var _band_mult: float = 1.0


func _init(stage_spec: Dictionary, run_stats: RunStats = null) -> void:
	spec = stage_spec
	stats = run_stats if run_stats != null else RunStats.make()
	var seed_value: int = int(spec.get("seed", 1))
	director = Director.new(spec)
	rng = Rng.new(Rng.mix(seed_value, 11))
	offer_rng = Rng.new(Rng.mix(seed_value, 23))
	match str(spec.get("modifier", "")):
		"glass":
			stats.max_lives = 1
			_score_mult = 2.0
		"frost":
			if stats.level("frost") == 0:
				stats.add("frost")
		"echoes":
			if stats.level("echo") == 0:
				stats.add("echo")
		"blitz":
			stats._grow_mult += 0.3
			stats._recalc()
		"precision":
			_band_mult = 0.6
			_crit_mult = 3.0
	lives = stats.max_lives
	rerolls_left = stats.rerolls


# --- Input --------------------------------------------------------------------

## Finger (or key) down: the ring starts growing on the next step.
func input_down() -> void:
	_want_hold = true
	_press_queued = true


## Finger up: the ring fires on the next step.
func input_up() -> void:
	_want_hold = false


func set_holding(on: bool) -> void:
	if on and not _want_hold:
		input_down()
	elif not on:
		input_up()


func is_holding() -> bool:
	return _want_hold


## Drops a ring that is still growing, without firing it (e.g. when a card
## opens over the arena and the finger lifts on the card).
func cancel_charge() -> void:
	charging = false
	ring_r = 0.0
	at_max_t = 0.0
	_want_hold = false
	_press_queued = false


# --- Queries --------------------------------------------------------------------

func is_over() -> bool:
	return state == State.WON or state == State.LOST


func xp_needed() -> float:
	return 6.0 + 5.0 * float(level)


func multiplier() -> float:
	return minf(4.0, 1.0 + 0.1 * float(combo)) * _score_mult


func stage_progress() -> float:
	if str(spec.get("mode", "")) == "endless":
		return fposmod(t, Director.BOSS_EVERY_ENDLESS) / Director.BOSS_EVERY_ENDLESS
	return clampf(t / director.duration(), 0.0, 1.0)


func boss_alive() -> bool:
	for e: Enemy in enemies:
		if e.alive and e.is_boss:
			return true
	return false


func boss_hp_ratio() -> float:
	var hp: float = 0.0
	var mx: float = 0.0
	for e: Enemy in enemies:
		if e.alive and e.is_boss:
			hp += maxf(0.0, e.hp)
			mx += e.max_hp
	return 0.0 if mx <= 0.0 else hp / mx


func alive_count() -> int:
	var n: int = 0
	for e: Enemy in enemies:
		if e.alive:
			n += 1
	return n


## The PERFECT test, shared by release and by the arena's highlight: the
## ring's edge is on the shape, from just short of its near side to a little
## past its middle.
func on_edge(e: Enemy, r: float) -> bool:
	if not e.alive or e.phased:
		return false
	var d: float = e.pos.length()
	var band: float = stats.perfect_band() * _band_mult
	return r >= d - e.radius - band and r <= d + minf(e.radius, 22.0) * 0.5 + band * 0.5


## Shapes a release at radius r would catch PERFECT.
func perfect_targets(r: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e: Enemy in enemies:
		if on_edge(e, r):
			out.append(e)
	return out


func overcharge_bonus() -> float:
	var mx: float = stats.overcharge_max()
	if mx <= 0.0 or at_max_t < 0.25:
		return 0.0
	return mx * clampf((at_max_t - 0.25) / 0.75, 0.0, 1.0)


## Stars earned so far as a bitmask: 1 = cleared, 2 = no damage, 4 = combo target.
func stars_mask() -> int:
	if state != State.WON:
		return 0
	var m: int = 1
	if damage_taken == 0:
		m |= 2
	if best_combo >= int(spec.get("combo_target", 999)):
		m |= 4
	return m


# --- Upgrade choice ---------------------------------------------------------------

## Picks offer `index` and resumes the run.
func choose(index: int) -> void:
	if state != State.CHOOSING or index < 0 or index >= offers.size():
		return
	var id: String = offers[index]
	stats.add(id)
	if id == "regen" or id == "lifeline":
		_regen_t = 0.0
	events.append({"t": "upgrade", "id": id, "level": stats.level(id)})
	offers = []
	pending_levels -= 1
	_next_offer()


## Swaps the current offers for new ones (if a reroll is left).
func reroll() -> bool:
	if state != State.CHOOSING or rerolls_left <= 0:
		return false
	rerolls_left -= 1
	offers = Upgrades.offer(offer_rng, stats.levels, 3)
	return true


func _next_offer() -> void:
	if pending_levels <= 0:
		pending_levels = 0
		state = State.RUNNING
		return
	offers = Upgrades.offer(offer_rng, stats.levels, 3)
	if offers.is_empty():
		# Everything is maxed: take points instead.
		score += 500
		pending_levels = 0
		state = State.RUNNING
		return
	state = State.CHOOSING


## Back from a lost run (a revive): two shields, a blast, a moment of safety.
func revive() -> void:
	if state != State.LOST:
		return
	revives += 1
	lives = mini(2, stats.max_lives)
	invuln_t = 2.5
	state = State.RUNNING
	_blast(320.0, stats.damage * 3.0)
	events.append({"t": "revive"})


# --- Simulation -------------------------------------------------------------------

## Advances the run by one fixed tick.
func step() -> void:
	events.clear()
	if state != State.RUNNING:
		return
	var dt: float = TICK
	t += dt
	ticks += 1
	_input_step(dt)
	_spawn_step(dt)
	_wave_step(dt)
	_enemy_step(dt)
	_gem_step(dt)
	_aura_step(dt)
	_timers(dt)
	_cleanup()
	_check_end()
	if state == State.RUNNING and pending_levels > 0:
		_next_offer()


func _input_step(dt: float) -> void:
	cooldown_t = maxf(0.0, cooldown_t - dt)
	if charging:
		_charge_ticks += 1
		if not _want_hold and _charge_ticks >= 1:
			_release()
			return
		ring_r = minf(stats.max_r, ring_r + stats.grow * dt)
		if ring_r >= stats.max_r:
			at_max_t += dt
	elif (_want_hold or _press_queued) and cooldown_t <= 0.0:
		_press_queued = false
		charging = true
		_charge_ticks = 0
		ring_r = RING_MIN
		at_max_t = 0.0
		events.append({"t": "charge"})


func _release() -> void:
	releases += 1
	var r: float = ring_r
	var targets: Array[Enemy] = perfect_targets(r)
	var crit: bool = not targets.is_empty()
	var bonus: float = overcharge_bonus()
	var dmg: float = stats.damage * (1.0 + bonus)
	var reach: float = r + REACH_SLACK
	for e: Enemy in targets:
		# A perfect always lands on what it caught.
		reach = maxf(reach, e.pos.length() - e.radius + 2.0)
	if stats.has("supernova") and bonus >= stats.overcharge_max() - 0.001 and bonus > 0.0:
		reach *= 1.35
	var w: Wave = _add_wave(WaveKind.MAIN, reach, dmg, crit)
	w.burning = stats.has("inferno")
	for i: int in stats.echo_count():
		var e: Wave = _add_wave(WaveKind.ECHO, reach, dmg * ECHO_DAMAGE, crit and stats.has("resonance"))
		e.delay = ECHO_DELAY * float(i + 1)
	if crit:
		perfects += 1
		combo += 1
		best_combo = maxi(best_combo, combo)
		score += int(PERFECT_BONUS * multiplier())
		var pts: Array = []
		for e: Enemy in targets:
			pts.append(e.pos)
		events.append({"t": "perfect", "r": r, "points": pts, "combo": combo})
		_chain(targets, dmg)
		var every: int = stats.lifeline_every()
		if every > 0:
			_lifeline_n += 1
			if _lifeline_n >= every:
				_lifeline_n = 0
				_gain_life("lifeline")
	events.append({"t": "release", "r": r, "reach": reach, "crit": crit, "bonus": bonus})
	charging = false
	ring_r = 0.0
	at_max_t = 0.0
	cooldown_t = COOLDOWN


## PERFECT sparks: from each caught shape to its nearest neighbours.
func _chain(targets: Array[Enemy], dmg: float) -> void:
	var zapped: Dictionary = {}
	for e: Enemy in targets:
		zapped[e.id] = true
	var sources: int = 0
	for src: Enemy in targets:
		if sources >= 3:
			break
		sources += 1
		for n: int in stats.chain:
			var best: Enemy = null
			var best_d: float = CHAIN_RANGE
			for o: Enemy in enemies:
				if not o.alive or o.phased or zapped.has(o.id):
					continue
				var d: float = o.pos.distance_to(src.pos)
				if d < best_d:
					best_d = d
					best = o
			if best == null:
				break
			zapped[best.id] = true
			events.append({"t": "spark", "from": src.pos, "to": best.pos})
			_damage(best, dmg * stats.chain_damage, false, "chain")
			if stats.stun_time() > 0.0:
				best.stun_t = maxf(best.stun_t, stats.stun_time())


func _add_wave(kind: int, max_r: float, dmg: float, crit: bool) -> Wave:
	var w: Wave = Wave.new()
	w.id = _next_id
	_next_id += 1
	w.kind = kind
	w.r = RING_MIN
	w.start_r = RING_MIN
	w.max_r = max_r
	w.speed = stats.wave_speed
	w.damage = dmg
	w.crit = crit
	waves.append(w)
	return w


func _spawn_step(dt: float) -> void:
	for req: Dictionary in director.step(dt):
		_queue.append(req)
	if director.boss_spawned:
		boss_spawned = true
	var room: int = MAX_ENEMIES - alive_count()
	while not _queue.is_empty() and (room > 0 or (_queue[0] as Dictionary).has("boss")):
		var req: Dictionary = _queue.pop_front()
		if req.has("boss"):
			spawn_boss(req["boss"], req["pos"])
			boss_spawned = true
		else:
			spawn_enemy(int(req["type"]), req["pos"], float(req["hp"]), float(req["speed"]))
		room -= 1


func spawn_enemy(type: int, pos: Vector2, hp_scale: float = 1.0, speed_scale: float = 1.0) -> Enemy:
	var info: Dictionary = EnemyTypes.info(type)
	var e: Enemy = Enemy.new()
	e.id = _next_id
	_next_id += 1
	e.type = type
	e.sides = int(info["sides"])
	e.pos = pos
	e.radius = float(info["radius"])
	if str(spec.get("modifier", "")) == "giants":
		e.radius *= 1.3
	e.hp_scale = hp_scale
	e.speed_scale = speed_scale
	# Minis stay fragile however deep the stage is.
	e.max_hp = float(info["hp"]) * (hp_scale if type != EnemyTypes.MINI else 1.0 + (hp_scale - 1.0) * 0.4)
	e.hp = e.max_hp
	e.speed = float(info["speed"]) * speed_scale
	e.score = int(info["score"])
	e.xp = int(info["xp"])
	e.shield = type == EnemyTypes.SHIELDED
	e.armour = EnemyTypes.HEAVY_ARMOUR if type == EnemyTypes.HEAVY else 0.0
	e.kb_resist = EnemyTypes.HEAVY_KB_RESIST if type == EnemyTypes.HEAVY else 0.0
	e.wobble = rng.next_float() * TAU
	e.spin = 1.0 if rng.next_float() < 0.5 else -1.0
	e.timer = EnemyTypes.DASH_EVERY * rng.range_f(0.5, 1.0) if type == EnemyTypes.DASHER else rng.range_f(0.0, 1.0)
	e.color = rng.range_i(0, 3)
	enemies.append(e)
	events.append({"t": "spawn", "type": type, "pos": pos})
	return e


func spawn_boss(b: Dictionary, pos: Vector2) -> Enemy:
	var e: Enemy = Enemy.new()
	e.id = _next_id
	_next_id += 1
	e.type = -1
	e.is_boss = true
	e.boss = b
	e.sides = int(b.get("sides", 6))
	e.pos = pos
	e.radius = float(b.get("radius", 50.0))
	e.max_hp = float(b.get("hp", 30.0))
	e.hp = e.max_hp
	e.speed = float(b.get("speed", 30.0))
	e.shield = float(b.get("shield", 0.0)) > 0.0
	e.armour = float(b.get("armour", 0.0))
	e.kb_resist = 0.85
	e.score = BOSS_SCORE
	e.xp = 20
	e.emit_t = 3.0
	var lunge: Array = b.get("lunge", [0.0, 0.0])
	e.lunge_t = float(lunge[0])
	e.spin = 1.0
	e.hp_scale = director.hp_mult()
	e.speed_scale = director.speed_mult()
	enemies.append(e)
	events.append({"t": "boss", "name": str(b.get("name", "Boss")), "pos": pos})
	return e


func _wave_step(dt: float) -> void:
	var n: int = waves.size()
	for i: int in n:
		var w: Wave = waves[i]
		if w.done:
			continue
		if w.delay > 0.0:
			w.delay -= dt
			continue
		var reached: bool = false
		if w.kind == WaveKind.RETURN:
			w.r -= w.speed * dt
			if w.r <= CORE_R:
				w.done = true
		elif w.lingering:
			w.linger -= dt
			if w.linger <= 0.0:
				w.done = true
		else:
			w.r = minf(w.max_r, w.r + w.speed * dt)
			reached = w.r >= w.max_r
		_wave_hits(w)
		if w.kind != WaveKind.RETURN:
			_wave_gems(w)
		if reached and not w.lingering:
			_wave_reached(w)
	# Waves added during this loop (follow-ups) start next step.


func _wave_hits(w: Wave) -> void:
	var count: int = enemies.size()
	for i: int in count:
		var e: Enemy = enemies[i]
		if not e.alive or e.phased or w.hit.has(e.id):
			continue
		var d: float = e.pos.length()
		var touch: bool = false
		match w.kind:
			WaveKind.RETURN:
				touch = d + e.radius >= w.r and d - e.radius <= w.max_r
			WaveKind.ARCS:
				if d - e.radius <= w.r and d + e.radius >= w.start_r:
					var a: float = e.pos.angle()
					for c: float in w.arcs:
						if absf(angle_difference(a, c)) <= w.arc_w * 0.5 + e.radius / maxf(d, 1.0):
							touch = true
							break
			_:
				touch = d - e.radius <= w.r
		if not touch:
			continue
		w.hit[e.id] = true
		w.hits += 1
		var crit: bool = w.crit
		_damage(e, w.damage, crit, "wave")
		if not e.alive:
			continue
		var ft: float = stats.frost_time()
		if ft > 0.0:
			e.slow_t = maxf(e.slow_t, ft)
		if crit and stats.stun_time() > 0.0:
			e.stun_t = maxf(e.stun_t, stats.stun_time())
		var bd: float = stats.burn_dps()
		if w.burning and w.lingering:
			bd = maxf(bd, 0.6) * 2.0
		if bd > 0.0:
			e.burn_t = 2.0
			e.burn_dps = maxf(e.burn_dps, bd * stats.damage)
		if w.kind != WaveKind.RETURN:
			var push: float = stats.knockback_force() * (1.0 - e.kb_resist)
			if w.kind == WaveKind.ECHO or w.kind == WaveKind.ARCS:
				push *= 0.5
			if d > 0.001:
				e.pos += e.pos / d * push


func _wave_gems(w: Wave) -> void:
	for g: Gem in gems:
		if g.alive and not g.pulled and g.pos.length() <= w.r:
			g.pulled = true


## The wave has reached its full radius: start any follow-ups once.
func _wave_reached(w: Wave) -> void:
	if w.kind == WaveKind.MAIN and not w.spawned_followups:
		w.spawned_followups = true
		if stats.has("ricochet"):
			var back: Wave = _add_wave(WaveKind.RETURN, w.max_r, w.damage * stats.ricochet_damage(), w.crit)
			back.r = w.max_r
		if stats.has("split"):
			var arcs: Wave = _add_wave(WaveKind.ARCS, w.max_r * (1.0 + stats.split_reach()), w.damage * stats.split_damage(), false)
			arcs.r = w.max_r
			arcs.start_r = w.max_r
			arcs.arcs = _arc_angles(w.max_r)
			arcs.arc_w = 0.55
		var glow: float = stats.afterglow_time()
		if glow > 0.0:
			w.lingering = true
			w.linger = glow
			return
	w.done = true


## Split arcs aim at the three nearest shapes beyond the wave (or spread out).
func _arc_angles(beyond: float) -> PackedFloat32Array:
	var cand: Array = []
	for e: Enemy in enemies:
		if e.alive and not e.phased and e.pos.length() > beyond:
			cand.append([e.pos.length(), e.pos.angle()])
	cand.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out: PackedFloat32Array = PackedFloat32Array()
	for c: Array in cand:
		if out.size() >= 3:
			break
		out.append(float(c[1]))
	var base: float = -PI / 2.0 if out.is_empty() else out[0]
	while out.size() < 3:
		out.append(base + TAU * float(out.size()) / 3.0)
	return out


func _damage(e: Enemy, amount: float, crit: bool, source: String) -> void:
	if not e.alive or e.phased:
		return
	var a: float = amount
	if crit:
		a *= _crit_mult
	if e.shield:
		if crit:
			e.shield = false
			if e.is_boss:
				e.shield_t = float(e.boss.get("shield", 0.0))
			events.append({"t": "shield_break", "pos": e.pos})
		else:
			a *= stats.pierce_factor()
			if a <= 0.0:
				events.append({"t": "blocked", "pos": e.pos})
				return
	if e.armour > 0.0 and not crit:
		a *= 1.0 - e.armour * (1.0 - stats.pierce_factor())
	if stats.has("shatter") and (e.slow_t > 0.0 or e.stun_t > 0.0):
		a *= 1.6
	e.hp -= a
	e.hit_flash = 0.12
	events.append({"t": "hit", "pos": e.pos, "crit": crit, "boss": e.is_boss, "src": source})
	if e.hp <= 0.0:
		_kill(e)


func _kill(e: Enemy) -> void:
	if not e.alive:
		return
	e.alive = false
	kills += 1
	score += int(float(e.score) * multiplier())
	events.append({"t": "kill", "pos": e.pos, "type": e.type, "boss": e.is_boss, "color": e.color, "radius": e.radius, "sides": e.sides})
	if e.is_boss:
		var split_hp: float = float(e.boss.get("split", 0.0))
		if split_hp > 0.0:
			for k: int in 2:
				var half: Dictionary = e.boss.duplicate(true)
				half["split"] = 0.0
				half["hp"] = split_hp
				half["radius"] = float(e.boss.get("radius", 50.0)) * 0.68
				half["name"] = str(e.boss.get("name", "")) + " half"
				var emit: Array = half.get("emit", [EnemyTypes.MINI, 5.0, 1])
				half["emit"] = [emit[0], float(emit[1]) * 1.4, emit[2]]
				var off: Vector2 = Vector2.from_angle(e.pos.angle() + (PI / 2.0 if k == 0 else -PI / 2.0)) * 60.0
				var h: Enemy = spawn_boss(half, e.pos + off)
				h.max_hp = split_hp
				h.hp = split_hp
		else:
			bosses_killed += 1
		_drop(e.pos, e.xp, 5)
		return
	if e.type == EnemyTypes.SPLITTER:
		var base: float = rng.next_float() * TAU
		for k: int in EnemyTypes.SPLIT_CHILDREN:
			var p: Vector2 = e.pos + Vector2.from_angle(base + TAU * float(k) / 3.0) * (e.radius + 6.0)
			spawn_enemy(EnemyTypes.MINI, p, e.hp_scale, e.speed_scale)
	if e.xp > 0:
		_drop(e.pos, e.xp, 1)


func _drop(pos: Vector2, value: int, pieces: int) -> void:
	for i: int in pieces:
		var v: int = maxi(1, value / pieces)
		var p: Vector2 = pos + (Vector2.from_angle(rng.next_float() * TAU) * rng.range_f(0.0, 18.0) if pieces > 1 else Vector2.ZERO)
		if gems.size() >= MAX_GEMS:
			# Too many on the floor: fold into the oldest uncollected gem.
			for g: Gem in gems:
				if g.alive and not g.pulled:
					g.value += v
					break
			continue
		var g2: Gem = Gem.new()
		g2.pos = p
		g2.value = v
		gems.append(g2)


func _enemy_step(dt: float) -> void:
	var count: int = enemies.size()
	for i: int in count:
		var e: Enemy = enemies[i]
		if not e.alive:
			continue
		e.age += dt
		e.hit_flash = maxf(0.0, e.hit_flash - dt)
		if e.burn_t > 0.0:
			e.burn_t -= dt
			e.hp -= e.burn_dps * dt
			if e.hp <= 0.0:
				_kill(e)
				continue
		if e.slow_t > 0.0:
			e.slow_t -= dt
		var sm: float = stats.frost_factor() if e.slow_t > 0.0 else 1.0
		if e.stun_t > 0.0:
			e.stun_t -= dt
			sm = 0.0
		if e.is_boss:
			_boss_step(e, dt, sm)
		else:
			_shape_step(e, dt, sm)
		if not e.alive:
			continue
		var d: float = e.pos.length()
		if d <= CORE_R + e.radius:
			_core_contact(e)


func _toward(e: Enemy, dt: float, speed: float) -> void:
	var d: float = e.pos.length()
	if e.hold_r > 0.0 and d <= e.hold_r:
		return
	if d > 0.001:
		e.pos -= e.pos / d * minf(d, speed * dt)


func _shape_step(e: Enemy, dt: float, sm: float) -> void:
	var d: float = e.pos.length()
	match e.type:
		EnemyTypes.DASHER:
			e.timer -= dt
			match e.mode:
				0:
					_toward(e, dt, e.speed * sm)
					if e.timer <= 0.0 and d < 520.0:
						e.mode = 1
						e.timer = EnemyTypes.DASH_WARN
						events.append({"t": "dash_warn", "pos": e.pos})
				1:
					if e.timer <= 0.0:
						e.mode = 2
						e.timer = EnemyTypes.DASH_TIME
						e.dir = -e.pos.normalized()
				2:
					e.pos += e.dir * EnemyTypes.DASH_SPEED * e.speed_scale * dt * sm
					if e.timer <= 0.0:
						e.mode = 0
						e.timer = EnemyTypes.DASH_EVERY
		EnemyTypes.ORBITER:
			if d > 0.001:
				var a: float = e.pos.angle() + EnemyTypes.ORBIT_SPIN * e.spin * dt * sm * clampf(220.0 / d, 0.5, 1.6)
				var nd: float = maxf(0.0, d - e.speed * 0.6 * dt * sm)
				e.pos = Vector2.from_angle(a) * nd
		EnemyTypes.SPAWNER:
			if d > EnemyTypes.SPAWNER_HOLD:
				_toward(e, dt, e.speed * sm)
			else:
				e.timer -= dt * (1.0 if sm > 0.0 else 0.0)
				if e.timer <= 0.0:
					e.timer = EnemyTypes.SPAWNER_EVERY
					if alive_count() < MAX_ENEMIES:
						spawn_enemy(EnemyTypes.MINI, e.pos * ((d - e.radius - 8.0) / maxf(d, 1.0)), e.hp_scale, e.speed_scale)
		EnemyTypes.PHASER:
			e.timer -= dt
			if e.timer <= 0.0:
				e.phased = not e.phased and d > EnemyTypes.PHASE_SOLID_R
				e.timer = EnemyTypes.PHASE_OFF if e.phased else EnemyTypes.PHASE_ON
			if d <= EnemyTypes.PHASE_SOLID_R:
				e.phased = false
			_toward(e, dt, e.speed * sm * (1.35 if e.phased else 1.0))
		EnemyTypes.DRIFTER, EnemyTypes.MINI:
			_toward(e, dt, e.speed * sm)
			if d > 60.0 and sm > 0.0:
				var perp: Vector2 = Vector2(-e.pos.y, e.pos.x) / d
				e.pos += perp * sin(e.age * 2.6 + e.wobble) * e.speed * 0.22 * dt * sm
		_:
			_toward(e, dt, e.speed * sm)


func _boss_step(e: Enemy, dt: float, sm: float) -> void:
	var b: Dictionary = e.boss
	var d: float = e.pos.length()
	var hold: float = float(b.get("hold", 260.0))
	var lunge: Array = b.get("lunge", [0.0, 0.0])
	# Shield comes back after a while.
	if float(b.get("shield", 0.0)) > 0.0 and not e.shield:
		e.shield_t -= dt
		if e.shield_t <= 0.0:
			e.shield = true
			events.append({"t": "shield_up", "pos": e.pos})
	# Phasing (never while close or lunging).
	if bool(b.get("phase", false)):
		e.timer -= dt
		if e.timer <= 0.0:
			e.phased = not e.phased and e.mode == 0
			e.timer = 1.1 if e.phased else 2.6
		if e.mode != 0:
			e.phased = false
	match e.mode:
		0:
			if d > hold:
				_toward(e, dt, e.speed * e.speed_scale * sm * (2.2 if d > 520.0 else 1.0))
			else:
				var orbit: float = float(b.get("orbit", 0.0))
				if orbit != 0.0 and d > 0.001:
					e.pos = Vector2.from_angle(e.pos.angle() + orbit * e.spin * dt * sm) * d
				if float(lunge[0]) > 0.0:
					e.lunge_t -= dt * (1.0 if sm > 0.0 else 0.0)
					if e.lunge_t <= 0.0:
						e.mode = 1
						e.timer = 0.9
						events.append({"t": "dash_warn", "pos": e.pos, "boss": true})
		1:
			e.timer -= dt
			if e.timer <= 0.0:
				e.mode = 2
		2:
			var stop: float = CORE_R + e.radius + 46.0
			_toward(e, dt, float(lunge[1]) * sm)
			if e.pos.length() <= stop:
				e.mode = 3
		3:
			if d < hold:
				var n: Vector2 = e.pos.normalized() if d > 0.001 else Vector2.UP
				e.pos += n * e.speed * 3.0 * dt * maxf(sm, 0.3)
			else:
				e.mode = 0
				e.lunge_t = float(lunge[0])
	# Minions.
	var emit: Array = b.get("emit", [])
	if emit.size() == 3 and d <= hold + 60.0:
		e.emit_t -= dt * (1.0 if sm > 0.0 else 0.25)
		if e.emit_t <= 0.0:
			e.emit_t = float(emit[1])
			var n2: int = int(emit[2])
			var base: float = e.pos.angle() + PI
			for k: int in n2:
				if alive_count() >= MAX_ENEMIES:
					break
				var ang: float = base + (float(k) - float(n2 - 1) / 2.0) * (TAU / float(maxi(n2, 6)))
				spawn_enemy(int(emit[0]), e.pos + Vector2.from_angle(ang) * (e.radius + 14.0), e.hp_scale, e.speed_scale)
			events.append({"t": "emit", "pos": e.pos})


func _core_contact(e: Enemy) -> void:
	if e.is_boss:
		var n: Vector2 = e.pos.normalized() if e.pos.length() > 0.001 else Vector2.UP
		e.pos = n * (float(e.boss.get("hold", 260.0)) + 60.0)
		e.mode = 0
		e.lunge_t = float((e.boss.get("lunge", [3.0, 0.0]) as Array)[0]) + 1.0
	else:
		e.alive = false
		events.append({"t": "pop_at_core", "pos": e.pos, "color": e.color})
	if invuln_t > 0.0:
		return
	_lose_life()


func _lose_life() -> void:
	damage_taken += 1
	lives -= 1
	combo = 0
	_regen_t = 0.0
	invuln_t = INVULN
	events.append({"t": "damage", "lives": lives})
	if lives <= 0 and stats.has("second_wind") and not _second_wind_used:
		_second_wind_used = true
		lives = 1
		events.append({"t": "second_wind"})
		_blast(300.0, stats.damage * 2.0)
	else:
		# A shock from the core shoves nearby shapes away.
		_blast(170.0, 0.0)


## Pushes everything within `radius` away (and hurts it if `dmg` > 0).
func _blast(radius: float, dmg: float) -> void:
	var count: int = enemies.size()
	for i: int in count:
		var e: Enemy = enemies[i]
		if not e.alive:
			continue
		var d: float = e.pos.length()
		if d <= radius + e.radius:
			if dmg > 0.0:
				_damage(e, dmg, false, "blast")
			if e.alive and d > 0.001:
				e.pos += e.pos / d * (radius - d + 80.0) * (1.0 - e.kb_resist * 0.8)
	events.append({"t": "blast", "r": radius})


func _gem_step(dt: float) -> void:
	var mr: float = stats.magnet_r
	for g: Gem in gems:
		if not g.alive:
			continue
		g.age += dt
		var d: float = g.pos.length()
		if not g.pulled and (d <= mr or d <= CORE_R + 50.0):
			g.pulled = true
		if g.pulled:
			g.speed = minf(1400.0, g.speed + 2600.0 * dt)
			if d <= CORE_R or d <= g.speed * dt:
				g.alive = false
				xp += float(g.value) * stats.xp_multiplier()
				events.append({"t": "gem", "value": g.value})
				while xp >= xp_needed():
					xp -= xp_needed()
					level += 1
					pending_levels += 1
					events.append({"t": "level_up", "level": level})
			else:
				g.pos -= g.pos / d * g.speed * dt


func _aura_step(dt: float) -> void:
	# Thorns.
	var td: float = stats.thorns_damage()
	if td > 0.0:
		_thorns_t -= dt
		if _thorns_t <= 0.0:
			_thorns_t = stats.thorns_every()
			var tr: float = stats.thorns_radius()
			var any: bool = false
			var count: int = enemies.size()
			for i: int in count:
				var e: Enemy = enemies[i]
				if e.alive and not e.phased and e.pos.length() <= tr + e.radius:
					any = true
					_damage(e, td, false, "thorns")
					if e.alive:
						e.pos += e.pos.normalized() * 22.0 * (1.0 - e.kb_resist)
			if any:
				events.append({"t": "thorns", "r": tr})
	# Satellites.
	var n: int = stats.orbit_count()
	if n > 0:
		shard_angle = fposmod(shard_angle + 2.4 * dt, TAU)
		for k: int in n:
			var sp: Vector2 = Vector2.from_angle(shard_angle + TAU * float(k) / float(n)) * SHARD_RADIUS
			var count: int = enemies.size()
			for i: int in count:
				var e: Enemy = enemies[i]
				if not e.alive or e.phased or e.shard_t > 0.0:
					continue
				if e.pos.distance_to(sp) <= SHARD_SIZE + e.radius:
					e.shard_t = 0.5
					_damage(e, 0.8 * stats.damage, false, "shard")
	for e: Enemy in enemies:
		if e.shard_t > 0.0:
			e.shard_t -= dt
	# Heartbeat.
	var every: float = stats.pulse_every()
	if every > 0.0:
		_pulse_t += dt
		if _pulse_t >= every:
			_pulse_t = 0.0
			_add_wave(WaveKind.PULSE, 150.0, stats.damage * 0.7, false)
			events.append({"t": "pulse"})


func _timers(dt: float) -> void:
	invuln_t = maxf(0.0, invuln_t - dt)
	var rt: float = stats.regen_time()
	if rt > 0.0 and lives < stats.max_lives:
		_regen_t += dt
		if _regen_t >= rt:
			_regen_t = 0.0
			_gain_life("regen")


func _gain_life(why: String) -> void:
	if lives < stats.max_lives:
		lives += 1
		events.append({"t": "shield", "why": why, "lives": lives})


func _cleanup() -> void:
	# Whiffs: a main wave that finished without touching anything breaks the combo.
	for w: Wave in waves:
		if w.done and w.kind == WaveKind.MAIN and w.hits == 0 and not w.crit:
			whiffs += 1
			if not stats.has("combo_keeper") and combo > 0:
				combo = 0
				events.append({"t": "combo_lost"})
	waves = waves.filter(func(w: Wave) -> bool: return not w.done)
	if ticks % 4 == 0:
		enemies = enemies.filter(func(e: Enemy) -> bool: return e.alive)
		gems = gems.filter(func(g: Gem) -> bool: return g.alive)


func _check_end() -> void:
	if lives <= 0:
		state = State.LOST
		charging = false
		events.append({"t": "lost"})
		return
	if str(spec.get("mode", "")) != "endless" and boss_spawned and _queue.is_empty() and not boss_alive():
		state = State.WON
		charging = false
		score += lives * LIFE_BONUS
		for e: Enemy in enemies:
			if e.alive:
				e.alive = false
				events.append({"t": "kill", "pos": e.pos, "type": e.type, "boss": false, "color": e.color, "radius": e.radius, "sides": e.sides})
		events.append({"t": "won"})


## Coins this run pays (before any first-clear star bonus).
func coins_earned() -> int:
	var base: float = float(score) / 200.0 + (20.0 if state == State.WON else 0.0)
	return int(round(base * stats.coin_multiplier()))
