class_name Director
extends RefCounted
## The spawn director: decides what comes in, where and when, from the level
## spec and its own seeded Rng only, never from what the player does. So a
## level brings the same shapes in the same order every time it's played.
##
## A threat budget fills at a rate that climbs smoothly over the level's
## length (smoothstep from a calm start to a busy end) and breathes in
## 20-second swells; every 16 s a surge sends a small pack from one edge. On a
## Giant or boss level the big one arrives after a short build-up, and the
## regular flow drops to a trickle.

const GRACE: float = 2.0
const SURGE_EVERY: float = 16.0
const SWELL_PERIOD: float = 20.0
## Spawn ring: just outside the visible arena (half-size 360 x 560).
const EDGE_HALF: Vector2 = Vector2(385.0, 585.0)

var spec: Dictionary
var rng: Rng
var t: float = 0.0
var budget: float = 0.0
var boss_spawned: bool = false
var _next_type: int = -1
var _next_surge: float = 14.0
var _weights: Array = []


func _init(level_spec: Dictionary) -> void:
	spec = level_spec
	rng = Rng.new(Rng.mix(int(spec.get("seed", 1)), 7))
	_weights = spec.get("weights", [1.0])
	if int(spec.get("featured", -1)) >= 0:
		# The world's new shape gets a moment on its own first.
		_next_surge = 18.0


func mode() -> String:
	return str(spec.get("mode", "level"))


func length() -> float:
	return float(spec.get("length", 45.0))


func difficulty() -> float:
	return float(spec.get("difficulty", 0.0))


func boss_at() -> float:
	return float(spec.get("boss_at", -1.0))


func boss_phase() -> bool:
	return boss_at() >= 0.0 and t >= boss_at()


## The smooth part of the spawn rate (threat points per second): from a calm
## start to a busy end of the level, without the swells.
func base_rate() -> float:
	var d: float = difficulty()
	var r0: float = 1.4 + 0.35 * d
	var r1: float = 2.8 + 0.80 * d
	var k: float = clampf(t / length(), 0.0, 1.0)
	var smooth: float = k * k * (3.0 - 2.0 * k)
	return r0 + (r1 - r0) * smooth


## Threat points per second now: the smooth curve breathing in 20-second
## swells, dropping to a trickle once the Giant or boss is here.
func rate() -> float:
	if boss_phase():
		return (0.9 + 0.30 * difficulty()) * 0.35
	return base_rate() * (1.0 + 0.25 * sin(TAU * t / SWELL_PERIOD))


## Shapes are one hit in the first two worlds; from Iron Bloom on they take
## two plain hits (or one PERFECT), and deeper levels bring them in faster.
func hp_mult() -> float:
	return 1.0 + 0.15 * maxf(0.0, difficulty() - 1.55)


func speed_mult() -> float:
	return 1.05 + 0.12 * minf(difficulty(), 8.0)


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
	if not boss_spawned and boss_phase() and not (spec.get("boss", {}) as Dictionary).is_empty():
		boss_spawned = true
		out.append({"boss": spec["boss"], "pos": Vector2(0, -EDGE_HALF.y - 20.0)})
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
	# Surges: a small pack from one edge.
	if not boss_phase() and t >= _next_surge:
		_next_surge += SURGE_EVERY
		var n: int = 3 + int(difficulty() * 0.8)
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
