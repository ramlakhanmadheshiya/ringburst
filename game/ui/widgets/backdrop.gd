class_name Backdrop
extends Control
## The neon sky behind every screen: a vertical gradient that eases between
## world colours, a faint dot grid, twinkling stars and a few hollow shapes
## drifting slowly upward, with a soft ring pulsing out now and then.

const STAR_COUNT: int = 60
const SHAPE_COUNT: int = 10

var top: Color = Style.DEFAULT_SKY_TOP
var bottom: Color = Style.DEFAULT_SKY_BOTTOM
var accent: Color = Style.AMBER
var _stars: Array[Vector4] = []
var _shapes: Array[Dictionary] = []
var _t: float = 0.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng: Rng = Rng.new(7)
	for i: int in STAR_COUNT:
		_stars.append(Vector4(rng.next_float(), rng.next_float(), rng.range_f(0.8, 2.2), rng.next_float() * TAU))
	var palette: Array = Worlds.world(0)["enemies"]
	for i: int in SHAPE_COUNT:
		_shapes.append({
			"x": rng.next_float(), "y": rng.next_float(), "speed": rng.range_f(0.006, 0.014),
			"size": rng.range_f(10.0, 26.0), "spin": rng.range_f(-0.6, 0.6), "sides": [3, 4, 5, 6, 0][rng.range_i(0, 4)],
			"color": Color(str(palette[rng.range_i(0, 3)])),
		})


## Eases the sky to a world's colours.
func set_sky(new_top: Color, new_bottom: Color, seconds: float = 0.8) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "top", new_top, seconds)
	_tween.tween_property(self, "bottom", new_bottom, seconds)
	accent = Style.AMBER


func _process(delta: float) -> void:
	_t += delta
	for sh: Dictionary in _shapes:
		sh["y"] = float(sh["y"]) - float(sh["speed"]) * delta
		if float(sh["y"]) < -0.08:
			sh["y"] = 1.08
	queue_redraw()


func _draw() -> void:
	var s: Vector2 = size
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	var ink: Color = Color.WHITE if Style.DARK else Color(0.1, 0.12, 0.3)
	# Dot grid.
	var step: float = 56.0
	var dot: Color = Color(ink, 0.05 if Style.DARK else 0.06)
	var y: float = fposmod(-_t * 6.0, step)
	while y < s.y:
		var x: float = step * 0.5
		while x < s.x:
			draw_rect(Rect2(x - 1.0, y - 1.0, 2.0, 2.0), dot)
			x += step
		y += step
	if Style.DARK:
		for st: Vector4 in _stars:
			var a: float = 0.2 + 0.45 * (0.5 + 0.5 * sin(_t * 1.4 + st.w))
			draw_circle(Vector2(st.x * s.x, st.y * s.y), st.z, Color(1, 1, 1, a))
	# A slow ring pulse from the middle.
	var k: float = fposmod(_t / 5.0, 1.0)
	var c: Vector2 = Vector2(s.x * 0.5, s.y * 0.42)
	draw_arc(c, 40.0 + k * s.y * 0.7, 0.0, TAU, 96, Color(accent, 0.10 * (1.0 - k)), 3.0, true)
	# Drifting hollow shapes.
	for sh: Dictionary in _shapes:
		var p: Vector2 = Vector2(float(sh["x"]) * s.x, float(sh["y"]) * s.y)
		var col: Color = Color(sh["color"], 0.22 if Style.DARK else 0.3)
		Shapes.outline(self, p, float(sh["size"]), int(sh["sides"]), _t * float(sh["spin"]), col, 2.0)
