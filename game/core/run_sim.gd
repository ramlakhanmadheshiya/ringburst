class_name RunSim
extends RefCounted
## One level of Ringburst, simulated deterministically at a fixed 60 Hz.
##
## The glowing core sits at (0, 0). HOLD grows a ring outward from the core;
## RELEASE fires it as a shockwave that damages every shape it passes, out to
## the radius the ring had. If a shape sits on the ring's edge at the moment of
## release, it is a PERFECT: the wave hits twice as hard, a spark jumps to a
## nearby shape and the combo rises (it multiplies score). A shape that
## touches the core costs a shield; lose them all and the level is lost. Meet
## the level's task (spec "goal") and it is won: the shields left are its stars.
##
## Nothing here touches the engine's scene tree, clocks or random numbers:
## the same spec and inputs always give the same level. The arena draws from
## this state and plays the `events` it leaves after each step; the tests and
## the bot drive it directly.

const TICK: float = 1.0 / 60.0
const CORE_R: float = 34.0
const RING_MIN: float = 42.0
const COOLDOWN: float = 0.12
const MAX_ENEMIES: int = 110
const INVULN: float = 1.3
const ARENA_HALF: Vector2 = Vector2(360.0, 560.0)
const CHAIN_RANGE: float = 210.0
const CRIT_MULT: float = 2.0
const PERFECT_BONUS: int = 10
const BOSS_SCORE: int = 1000
const LIFE_BONUS: int = 250
## A wave reaches a little past the ring it was fired from.
const REACH_SLACK: float = 6.0

enum State { RUNNING, WON, LOST }


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
	var hit_flash: float = 0.0
	var emit_t: float = 0.0
	var lunge_t: float = 0.0
	var wobble: float = 0.0
	## Tutorial shapes stop at this distance (0 = never stop).
	var hold_r: float = 0.0
	var score: int = 0
	var color: int = 0


class Wave:
	extends RefCounted
	var id: int = 0
	var r: float = 0.0
	var max_r: float = 0.0
	var speed: float = 1500.0
	var damage: float = 1.0
	var crit: bool = false
	var done: bool = false
	var hits: int = 0
	var hit: Dictionary = {}


var spec: Dictionary
var stats: RunStats
var director: Director
var rng: Rng
var state: int = State.RUNNING
## The level's task: {"type": "kills" | "perfects" | "survive" | "combo" |
## "hunt" | "guardian" | "boss", "n": int, "shape": int (hunt only)}.
var goal: Dictionary = {}

var t: float = 0.0
var ticks: int = 0
var enemies: Array[Enemy] = []
var waves: Array[Wave] = []
var events: Array[Dictionary] = []

var lives: int = 3
var invuln_t: float = 0.0
var charging: bool = false
var ring_r: float = 0.0
var cooldown_t: float = 0.0
var combo: int = 0
var best_combo: int = 0
var score: int = 0
var kills: int = 0
## Shapes of the hunted type burst so far (hunt levels).
var hunted: int = 0
var perfects: int = 0
var releases: int = 0
var whiffs: int = 0
var damage_taken: int = 0
var revives: int = 0
var bosses_killed: int = 0
var boss_spawned: bool = false

var _want_hold: bool = false
var _press_queued: bool = false
var _charge_ticks: int = 0
var _next_id: int = 1
var _queue: Array = []


func _init(level_spec: Dictionary, run_stats: RunStats = null) -> void:
	spec = level_spec
	stats = run_stats if run_stats != null else RunStats.make()
	goal = spec.get("goal", {})
	var seed_value: int = int(spec.get("seed", 1))
	director = Director.new(spec)
	rng = Rng.new(Rng.mix(seed_value, 11))
	lives = stats.max_lives


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
	_want_hold = false
	_press_queued = false


# --- Queries --------------------------------------------------------------------

func is_over() -> bool:
	return state == State.WON or state == State.LOST


func multiplier() -> float:
	return minf(4.0, 1.0 + 0.1 * float(combo))


func goal_type() -> String:
	return str(goal.get("type", ""))


func goal_target() -> int:
	return int(goal.get("n", 1))


func is_boss_goal() -> bool:
	return goal_type() == "guardian" or goal_type() == "boss"


## How far the task has got, in its own units (shapes, PERFECTs, seconds...).
func goal_count() -> int:
	match goal_type():
		"kills":
			return kills
		"perfects":
			return perfects
		"survive":
			return int(t)
		"combo":
			return best_combo
		"hunt":
			return hunted
		"guardian", "boss":
			return bosses_killed
	return 0


## The task's progress from 0 to 1 (a Giant or boss counts its health down).
func goal_progress() -> float:
	if state == State.WON:
		return 1.0
	if is_boss_goal():
		return 0.0 if not boss_spawned else clampf(1.0 - boss_hp_ratio(), 0.0, 0.99)
	if goal_type() == "survive":
		return clampf(t / float(goal_target()), 0.0, 1.0)
	return clampf(float(goal_count()) / float(maxi(1, goal_target())), 0.0, 1.0)


func _goal_met() -> bool:
	if goal.is_empty():
		return false
	if is_boss_goal():
		return boss_spawned and _queue.is_empty() and not boss_alive()
	if goal_type() == "survive":
		return t >= float(goal_target())
	return goal_count() >= goal_target()


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
	var band: float = stats.perfect_band()
	return r >= d - e.radius - band and r <= d + minf(e.radius, 22.0) * 0.5 + band * 0.5


## Shapes a release at radius r would catch PERFECT.
func perfect_targets(r: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e: Enemy in enemies:
		if on_edge(e, r):
			out.append(e)
	return out


## Stars for the level: the shields left when it was won (one after a revive).
func stars() -> int:
	if state != State.WON:
		return 0
	if revives > 0:
		return 1
	return clampi(lives, 1, 3)


## Back from a lost level (a revive): two shields, a blast, a moment of safety.
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

## Advances the level by one fixed tick.
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
	invuln_t = maxf(0.0, invuln_t - dt)
	_cleanup()
	_check_end()


func _input_step(dt: float) -> void:
	cooldown_t = maxf(0.0, cooldown_t - dt)
	if charging:
		_charge_ticks += 1
		if not _want_hold and _charge_ticks >= 1:
			_release()
			return
		ring_r = minf(stats.max_r, ring_r + stats.grow * dt)
	elif (_want_hold or _press_queued) and cooldown_t <= 0.0:
		_press_queued = false
		charging = true
		_charge_ticks = 0
		ring_r = RING_MIN
		events.append({"t": "charge"})


func _release() -> void:
	releases += 1
	var r: float = ring_r
	var targets: Array[Enemy] = perfect_targets(r)
	var crit: bool = not targets.is_empty()
	var dmg: float = stats.damage
	var reach: float = r + REACH_SLACK
	for e: Enemy in targets:
		# A perfect always lands on what it caught.
		reach = maxf(reach, e.pos.length() - e.radius + 2.0)
	_add_wave(reach, dmg, crit)
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
	events.append({"t": "release", "r": r, "reach": reach, "crit": crit})
	charging = false
	ring_r = 0.0
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


func _add_wave(max_r: float, dmg: float, crit: bool) -> Wave:
	var w: Wave = Wave.new()
	w.id = _next_id
	_next_id += 1
	w.r = RING_MIN
	w.max_r = max_r
	w.speed = stats.wave_speed
	w.damage = dmg
	w.crit = crit
	waves.append(w)
	return w


func _spawn_step(dt: float) -> void:
	for req: Dictionary in director.step(dt):
		_queue.append(req)
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
	e.hp_scale = hp_scale
	e.speed_scale = speed_scale
	e.max_hp = float(info["hp"]) * hp_scale
	e.hp = e.max_hp
	e.speed = float(info["speed"]) * speed_scale
	e.score = int(info["score"])
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
	for w: Wave in waves:
		if w.done:
			continue
		w.r = minf(w.max_r, w.r + w.speed * dt)
		_wave_hits(w)
		if w.r >= w.max_r:
			w.done = true


func _wave_hits(w: Wave) -> void:
	var count: int = enemies.size()
	for i: int in count:
		var e: Enemy = enemies[i]
		if not e.alive or e.phased or w.hit.has(e.id):
			continue
		var d: float = e.pos.length()
		if d - e.radius > w.r:
			continue
		w.hit[e.id] = true
		w.hits += 1
		_damage(e, w.damage, w.crit, "wave")
		if e.alive and d > 0.001:
			e.pos += e.pos / d * stats.knockback_force() * (1.0 - e.kb_resist)


func _damage(e: Enemy, amount: float, crit: bool, source: String) -> void:
	if not e.alive or e.phased:
		return
	var a: float = amount
	if crit:
		a *= CRIT_MULT
	if e.shield:
		if crit:
			e.shield = false
			if e.is_boss:
				e.shield_t = float(e.boss.get("shield", 0.0))
			events.append({"t": "shield_break", "pos": e.pos})
		else:
			events.append({"t": "blocked", "pos": e.pos})
			return
	if e.armour > 0.0 and not crit:
		a *= 1.0 - e.armour
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
	if goal_type() == "hunt" and e.type == int(goal.get("shape", -1)):
		hunted += 1
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
		return
	if e.type == EnemyTypes.SPLITTER:
		var base: float = rng.next_float() * TAU
		for k: int in EnemyTypes.SPLIT_CHILDREN:
			var p: Vector2 = e.pos + Vector2.from_angle(base + TAU * float(k) / 3.0) * (e.radius + 6.0)
			spawn_enemy(EnemyTypes.MINI, p, e.hp_scale, e.speed_scale)


func _enemy_step(dt: float) -> void:
	var count: int = enemies.size()
	for i: int in count:
		var e: Enemy = enemies[i]
		if not e.alive:
			continue
		e.age += dt
		e.hit_flash = maxf(0.0, e.hit_flash - dt)
		if e.is_boss:
			_boss_step(e, dt)
		else:
			_shape_step(e, dt)
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


func _shape_step(e: Enemy, dt: float) -> void:
	var d: float = e.pos.length()
	match e.type:
		EnemyTypes.DASHER:
			e.timer -= dt
			match e.mode:
				0:
					_toward(e, dt, e.speed)
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
					e.pos += e.dir * EnemyTypes.DASH_SPEED * e.speed_scale * dt
					if e.timer <= 0.0:
						e.mode = 0
						e.timer = EnemyTypes.DASH_EVERY
		EnemyTypes.ORBITER:
			if d > 0.001:
				var a: float = e.pos.angle() + EnemyTypes.ORBIT_SPIN * e.spin * dt * clampf(220.0 / d, 0.5, 1.6)
				var nd: float = maxf(0.0, d - e.speed * 0.6 * dt)
				e.pos = Vector2.from_angle(a) * nd
		EnemyTypes.SPAWNER:
			if d > EnemyTypes.SPAWNER_HOLD:
				_toward(e, dt, e.speed)
			else:
				e.timer -= dt
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
			_toward(e, dt, e.speed * (1.35 if e.phased else 1.0))
		EnemyTypes.DRIFTER, EnemyTypes.MINI:
			_toward(e, dt, e.speed)
			if d > 60.0:
				var perp: Vector2 = Vector2(-e.pos.y, e.pos.x) / d
				e.pos += perp * sin(e.age * 2.6 + e.wobble) * e.speed * 0.22 * dt
		_:
			_toward(e, dt, e.speed)


func _boss_step(e: Enemy, dt: float) -> void:
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
				_toward(e, dt, e.speed * e.speed_scale * (2.2 if d > 520.0 else 1.0))
			else:
				var orbit: float = float(b.get("orbit", 0.0))
				if orbit != 0.0 and d > 0.001:
					e.pos = Vector2.from_angle(e.pos.angle() + orbit * e.spin * dt) * d
				if float(lunge[0]) > 0.0:
					e.lunge_t -= dt
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
			_toward(e, dt, float(lunge[1]))
			if e.pos.length() <= stop:
				e.mode = 3
		3:
			if d < hold:
				var n: Vector2 = e.pos.normalized() if d > 0.001 else Vector2.UP
				e.pos += n * e.speed * 3.0 * dt
			else:
				e.mode = 0
				e.lunge_t = float(lunge[0])
	# Minions.
	var emit: Array = b.get("emit", [])
	if emit.size() == 3 and d <= hold + 60.0:
		e.emit_t -= dt
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
	invuln_t = INVULN
	events.append({"t": "damage", "lives": lives})
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


func _cleanup() -> void:
	# Whiffs: a wave that finished without touching anything breaks the combo.
	for w: Wave in waves:
		if w.done and w.hits == 0 and not w.crit:
			whiffs += 1
			if combo > 0:
				combo = 0
				events.append({"t": "combo_lost"})
	waves = waves.filter(func(w: Wave) -> bool: return not w.done)
	if ticks % 4 == 0:
		enemies = enemies.filter(func(e: Enemy) -> bool: return e.alive)


func _check_end() -> void:
	if lives <= 0:
		state = State.LOST
		charging = false
		events.append({"t": "lost"})
		return
	if str(spec.get("mode", "")) == "tutorial" or not _goal_met():
		return
	state = State.WON
	charging = false
	score += lives * LIFE_BONUS
	for e: Enemy in enemies:
		if e.alive:
			e.alive = false
			events.append({"t": "kill", "pos": e.pos, "type": e.type, "boss": false, "color": e.color, "radius": e.radius, "sides": e.sides})
	events.append({"t": "won"})
