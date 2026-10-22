class_name Bot
extends RefCounted
## An auto-player for RunSim. The tests use it to prove every level can be
## beaten and that the curve climbs; the home screen uses it as a live demo.
##
## "perfect": holds, and lets go the moment a shape sits on the ring's edge
## (or when something slips inside a full-size ring).
## "sloppy": a stand-in for a first-time player, with human limits: it pauses
## a moment after every burst, holds for at least half a second, and lets go
## at roughly the right size, late and imprecise, never aiming for perfects.

const SLOPPY_REST: Vector2 = Vector2(0.25, 0.45)
const SLOPPY_MIN_HOLD: int = 30

var skill: String = "perfect"
var rng: Rng
var _late: int = 0
var _offset: float = 0.0
var _rest: int = 0
var _held: int = 0


func _init(kind: String = "perfect", seed_value: int = 5) -> void:
	skill = kind
	rng = Rng.new(seed_value)
	_offset = rng.range_f(-50.0, 90.0)


## Decides input for the coming step.
func act(sim: RunSim) -> void:
	if sim.state != RunSim.State.RUNNING:
		return
	if not sim.charging:
		if _rest > 0:
			_rest -= 1
			sim.set_holding(false)
			return
		_held = 0
		sim.set_holding(_threat_near(sim))
		return
	if skill == "perfect":
		sim.set_holding(not _release_now(sim))
		return
	_held += 1
	var go: bool = _held >= SLOPPY_MIN_HOLD and _sloppy_release(sim)
	sim.set_holding(not go)
	if go:
		_rest = int(rng.range_f(SLOPPY_REST.x, SLOPPY_REST.y) * 60.0)


func _nearest(sim: RunSim) -> float:
	var best: float = INF
	for e: RunSim.Enemy in sim.enemies:
		if e.alive and not e.phased:
			best = minf(best, e.pos.length() - e.radius)
	return best


func _threat_near(sim: RunSim) -> bool:
	for e: RunSim.Enemy in sim.enemies:
		if e.alive and e.pos.length() - e.radius < sim.stats.max_r + 140.0:
			return true
	return false


func _release_now(sim: RunSim) -> bool:
	var r: float = sim.ring_r
	var near: float = _nearest(sim)
	var slack: float = RunSim.REACH_SLACK
	var room: float = near - RunSim.CORE_R
	if not sim.perfect_targets(r).is_empty():
		# Safe to wait, and more shapes just beyond the ring? Catch them too
		# with a bigger perfect. Otherwise take it now.
		if room < 45.0 or r >= sim.stats.max_r * 0.9:
			return true
		var top: float = minf(r + 70.0, sim.stats.max_r)
		for e: RunSim.Enemy in sim.enemies:
			if e.alive and not e.phased:
				var edge: float = e.pos.length() - e.radius
				if edge > r + slack and edge <= top:
					return false
		return true
	# Something already inside a full ring: fire rather than wait.
	if r >= sim.stats.max_r - 0.5 and near < r + slack:
		return true
	# Danger close and the ring already covers it.
	if room < 30.0 and near <= r + slack:
		return true
	return false


## Distance to the nearest shape whose edge is beyond `r`.
func _next_beyond(sim: RunSim, r: float) -> float:
	var best: float = INF
	for e: RunSim.Enemy in sim.enemies:
		if e.alive and not e.phased:
			var d: float = e.pos.length()
			if d > r:
				best = minf(best, d)
	return best


func _sloppy_release(sim: RunSim) -> bool:
	var r: float = sim.ring_r
	var near: float = _nearest(sim)
	if near == INF:
		return false
	if r >= minf(sim.stats.max_r, near + _offset) or r >= sim.stats.max_r - 0.5:
		_late += 1
		if _late >= 16:
			_late = 0
			_offset = rng.range_f(-50.0, 90.0)
			return true
	return false


## Plays a whole level to the end (or until max_seconds) and returns a summary.
static func play(spec: Dictionary, kind: String = "perfect", max_seconds: float = 400.0) -> Dictionary:
	var sim: RunSim = RunSim.new(spec)
	var bot: Bot = Bot.new(kind, int(spec.get("seed", 3)))
	var limit: int = int(max_seconds * 60.0)
	while not sim.is_over() and sim.ticks < limit:
		bot.act(sim)
		sim.step()
	return {
		"won": sim.state == RunSim.State.WON, "lost": sim.state == RunSim.State.LOST, "time": sim.t,
		"score": sim.score, "kills": sim.kills, "damage": sim.damage_taken, "lives": sim.lives,
		"perfects": sim.perfects, "releases": sim.releases, "best_combo": sim.best_combo,
		"stars": sim.stars(),
	}
