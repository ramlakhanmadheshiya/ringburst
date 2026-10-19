class_name Director
extends RefCounted
## The spawn director: decides what comes in, where and when, from the stage
## spec and its own seeded Rng only, never from what the player does. So the
## same stage (or the same day's Daily Run) brings the same shapes in the
## same order to everyone.
##
## A threat budget fills at a rate that climbs smoothly over the stage
## (smoothstep from a calm start to a busy end) and breathes in 20-second
## swells; every 16 s a surge sends a pack from one edge. When the timer runs
## out the boss arrives and regular spawns drop to a trickle.

const GRACE: float = 2.0
const SURGE_EVERY: float = 16.0
const SWELL_PERIOD: float = 20.0
## Spawn ring: just outside the visible arena (half-size 360 x 560).
const EDGE_HALF: Vector2 = Vector2(385.0, 585.0)
const BOSS_EVERY_ENDLESS: float = 120.0

var spec: Dictionary
var rng: Rng
var t: float = 0.0
var budget: float = 0.0
var boss_spawned: bool = false
var bosses_spawned: int = 0
var _next_type: int = -1
var _next_surge: float = 14.0
var _weights: Array = []


func _init(stage_spec: Dictionary) -> void:
	spec = stage_spec
	rng = Rng.new(Rng.mix(int(spec.get("seed", 1)), 7))
	_weights = spec.get("weights", [1.0])
	if int(spec.get("featured", -1)) >= 0:
		# The world's new shape gets a moment on its own first.
		_next_surge = 18.0


func mode() -> String:
	return str(spec.get("mode", "stage"))


func duration() -> float:
	return float(spec.get("duration", 90.0))


## Difficulty now: fixed for a stage, climbing with time in Endless.
func difficulty() -> float:
	var d: float = float(spec.get("difficulty", 0.0))
	if mode() == "endless":
		return d + t / 40.0
	return d


func boss_phase() -> bool:
	return mode() != "endless" and mode() != "tutorial" and t >= duration()


## The smooth part of the spawn rate (threat points per second): from a calm
## start to a busy end of the stage, without the swells.
func base_rate() -> float:
	var d: float = difficulty()
	var r0: float = 0.9 + 0.35 * d
	var r1: float = 2.0 + 0.70 * d
	var k: float
	if mode() == "endless":
		k = clampf(t / 90.0, 0.0, 1.0)
	else:
		k = clampf(t / duration(), 0.0, 1.0)
	var smooth: float = k * k * (3.0 - 2.0 * k)
	var r: float = r0 + (r1 - r0) * smooth
	if str(spec.get("modifier", "")) == "swarm":
		r *= 1.5
	return r


## Threat points per second now: the smooth curve breathing in 20-second
## swells, dropping to a trickle once the boss is here.
func rate() -> float:
	if boss_phase():
		return (2.0 + 0.70 * difficulty()) * 0.22
	return base_rate() * (1.0 + 0.3 * sin(TAU * t / SWELL_PERIOD))


## Health and speed scaling for shapes spawned now.
func hp_mult() -> float:
	var m: float = 1.0 + 0.38 * difficulty()
	match str(spec.get("modifier", "")):
		"swarm":
			m *= 0.7
		"giants":
			m *= 1.5
	return m


func speed_mult() -> float:
	var m: float = 1.0 + 0.11 * minf(difficulty(), 10.0)
	match str(spec.get("modifier", "")):
		"giants":
			m *= 0.8
		"blitz":
			m *= 1.2
	return m


## Advances the director by dt and returns spawn requests:
## {"type": int, "pos": Vector2, "hp": float, "speed": float} or a boss
## {"boss": Dictionary, "pos": Vector2}.
func step(dt: float) -> Array:
	var out: Array = []
	t += dt
	if t < GRACE or mode() == "tutorial":
		return out
	var featured: int = int(spec.get("featured", -1))
	if featured >= 0 and t - dt < 3.0 and t >= 3.0:
		out.append(_request(featured, Vector2(0, -EDGE_HALF.y)))
		budget = 0.0
		return out
	if featured >= 0 and t < 8.0:
		return out
	# Bosses.
	if mode() == "endless":
		if t >= BOSS_EVERY_ENDLESS * float(bosses_spawned + 1):
			var b: Dictionary = EnemyTypes.boss(bosses_spawned % EnemyTypes.BOSSES.size(), difficulty() * 0.6)
			bosses_spawned += 1
			out.append({"boss": b, "pos": Vector2(0, -EDGE_HALF.y - 20.0)})
	elif not boss_spawned and t >= duration():
		boss_spawned = true
		bosses_spawned = 1
		out.append({"boss": spec.get("boss", {}), "pos": Vector2(0, -EDGE_HALF.y - 20.0)})
	# Steady flow.
	budget += rate() * dt
	if _next_type < 0:
		_next_type = rng.weighted(_weights)
	var guard: int = 0
	while budget >= _cost(_next_type) and guard < 8:
		budget -= _cost(_next_type)
		out.append(_request(_next_type, edge_point(rng.next_float())))
		_next_type = rng.weighted(_weights)
		guard += 1
	# Surges: a pack from one edge.
	if not boss_phase() and t >= _next_surge:
		_next_surge += SURGE_EVERY
		var n: int = 3 + int(difficulty() * 0.7)
		var u: float = rng.next_float()
		var type: int = rng.weighted(_weights)
		for i: int in n:
			var p: Vector2 = edge_point(u + rng.range_f(-0.03, 0.03))
			out.append(_request(type if i % 2 == 0 else EnemyTypes.DRIFTER, p))
	return out


func _cost(type: int) -> float:
	return float(EnemyTypes.info(type)["cost"])


func _request(type: int, pos: Vector2) -> Dictionary:
	return {"type": type, "pos": pos, "hp": hp_mult(), "speed": speed_mult()}


## A point on the spawn rectangle, u in [0, 1) going round the perimeter.
static func edge_point(u: float) -> Vector2:
	u = fposmod(u, 1.0)
	var w: float = EDGE_HALF.x * 2.0
	var h: float = EDGE_HALF.y * 2.0
	var p: float = u * (2.0 * w + 2.0 * h)
	if p < w:
		return Vector2(-EDGE_HALF.x + p, -EDGE_HALF.y)
	p -= w
	if p < h:
		return Vector2(EDGE_HALF.x, -EDGE_HALF.y + p)
	p -= h
	if p < w:
		return Vector2(EDGE_HALF.x - p, EDGE_HALF.y)
	p -= w
	return Vector2(-EDGE_HALF.x, EDGE_HALF.y - p)
