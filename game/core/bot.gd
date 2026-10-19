class_name Bot
extends RefCounted
## An auto-player for RunSim. The tests use it to prove every stage can be
## beaten and that the curve climbs; the home screen uses it as a live demo.
##
## "perfect": holds, and lets go the moment a shape sits on the ring's edge
## (or when something slips inside a full-size ring).
## "sloppy": lets go at roughly the right size, late and imprecise, never
## aiming for perfects; a stand-in for a first-time player.

const PRIORITY: Array[String] = [
	"shatter", "resonance", "supernova", "inferno",
	"heavy_wave", "regen", "quick_charge", "long_reach", "pierce", "echo", "wide_band", "chain",
	"thorns", "orbit", "frost", "static", "second_wind", "afterglow", "knockback", "pulse",
	"overcharge", "ember", "ricochet", "split", "fast_wave", "magnet", "lifeline", "combo_keeper",
	"scholar", "greed",
]

var skill: String = "perfect"
var rng: Rng
var _late: int = 0
var _offset: float = 0.0


func _init(kind: String = "perfect", seed_value: int = 5) -> void:
	skill = kind
	rng = Rng.new(seed_value)
	_offset = rng.range_f(-50.0, 90.0)


## Decides input for the coming step (and answers upgrade choices).
func act(sim: RunSim) -> void:
	if sim.state == RunSim.State.CHOOSING:
		sim.choose(pick(sim))
		return
	if sim.state != RunSim.State.RUNNING:
		return
	if not sim.charging:
		sim.set_holding(_threat_near(sim))
		return
	if skill == "perfect":
		sim.set_holding(not _release_now(sim))
	else:
		sim.set_holding(not _sloppy_release(sim))


## Index of the best offer by a fixed priority list.
func pick(sim: RunSim) -> int:
	var best: int = 0
	var best_rank: int = 999
	for i: int in sim.offers.size():
		var rank: int = PRIORITY.find(str(sim.offers[i]))
		if rank < 0:
			rank = 500
		if rank < best_rank:
			best_rank = rank
			best = i
	return best


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


## Forge levels a player could plausibly own when they reach world `w`
## (used by the tests: the campaign assumes some meta-progression).
static func typical_forge(w: int) -> Dictionary:
	return {
		"power": mini(5, int(w * 0.8)), "charge": mini(5, int(w * 0.6)), "reach": mini(5, int(w * 0.6)),
		"eye": mini(5, int(w * 0.5)), "shield": 1 if w >= 5 else 0, "scholar": mini(5, int(w * 0.5)),
	}


## Plays a whole run to the end (or until max_seconds) and returns a summary.
static func play(spec: Dictionary, stats: RunStats, kind: String = "perfect", max_seconds: float = 400.0) -> Dictionary:
	var sim: RunSim = RunSim.new(spec, stats)
	var bot: Bot = Bot.new(kind, int(spec.get("seed", 3)))
	var limit: int = int(max_seconds * 60.0)
	while not sim.is_over() and sim.ticks < limit:
		bot.act(sim)
		sim.step()
	return {
		"won": sim.state == RunSim.State.WON, "lost": sim.state == RunSim.State.LOST, "time": sim.t,
		"score": sim.score, "kills": sim.kills, "damage": sim.damage_taken, "lives": sim.lives,
		"perfects": sim.perfects, "releases": sim.releases, "best_combo": sim.best_combo,
		"level": sim.level, "stars": sim.stars_mask(), "coins": sim.coins_earned(),
	}
