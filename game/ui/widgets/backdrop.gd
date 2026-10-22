class_name Backdrop
extends Control
## The calm sky behind every screen: a vertical gradient that eases between
## world colours, a few softly twinkling stars (dark looks only) and one faint
## ring pulsing out now and then. Kept quiet on purpose so the content reads.

const STAR_COUNT: int = 36

var top: Color = Style.DEFAULT_SKY_TOP
var bottom: Color = Style.DEFAULT_SKY_BOTTOM
var accent: Color = Style.AMBER
var _stars: Array[Vector4] = []
var _t: float = 0.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng: Rng = Rng.new(7)
	for i: int in STAR_COUNT:
		_stars.append(Vector4(rng.next_float(), rng.next_float(), rng.range_f(0.7, 1.8), rng.next_float() * TAU))


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
	queue_redraw()


func _draw() -> void:
	var s: Vector2 = size
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	if Style.DARK:
		for st: Vector4 in _stars:
			var a: float = 0.12 + 0.28 * (0.5 + 0.5 * sin(_t * 1.1 + st.w))
			draw_circle(Vector2(st.x * s.x, st.y * s.y), st.z, Color(1, 1, 1, a))
	# A slow, faint ring pulse from the middle.
	var k: float = fposmod(_t / 6.0, 1.0)
	var c: Vector2 = Vector2(s.x * 0.5, s.y * 0.42)
	draw_arc(c, 40.0 + k * s.y * 0.7, 0.0, TAU, 96, Color(accent, 0.06 * (1.0 - k)), 2.0, true)
