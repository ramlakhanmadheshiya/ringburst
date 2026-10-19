class_name Splash
extends Control
## The opening moment: the core lights, a ring grows while shapes drift in,
## the ring bursts right on their edge (PERFECT), they shatter, and the title
## appears. Matches the boot splash colour so the hand-off is seamless.
## Tap to skip.

signal finished

const BG_TOP: Color = Color("#141A3C")
const BG_BOTTOM: Color = Color("#070A1A")
const CYAN: Color = Color("#3DF5FF")
const LENGTH: float = 2.7
const SHAPES: Array = [[3, "#FF4FA3", -0.6], [4, "#FFD23F", 0.5], [6, "#7CFF6B", 1.6], [5, "#B98CFF", 2.6], [3, "#4FF0FF", 3.7]]

var _t: float = 0.0
## Driven frame by frame (e.g. for the store art) instead of by the clock.
var manual: bool = false
var _done: bool = false
var _burst: bool = false


func show_at(t: float) -> void:
	_t = t
	_burst = t > 1.25
	queue_redraw()


func _ready() -> void:
	if manual:
		set_process(false)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_finish()
	)


func _process(delta: float) -> void:
	_t += delta
	if not _burst and _t > 1.25:
		_burst = true
		Audio.play("release", 0.9, -4.0)
		Audio.play("perfect", 1.0, -6.0)
		Haptics.tap()
	if _t >= LENGTH:
		_finish()
	queue_redraw()


func _finish() -> void:
	if _done:
		return
	_done = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		finished.emit()
		queue_free()
	)


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]),
		PackedColorArray([BG_TOP, BG_TOP, BG_BOTTOM, BG_BOTTOM]))
	var s: float = minf(size.x, size.y) / 720.0
	var c: Vector2 = Vector2(size.x * 0.5, size.y * 0.42)
	var appear: float = clampf(_t / 0.35, 0.0, 1.0)
	var glow: Texture2D = Style.glow_texture()
	var ring_r: float = 150.0 * s
	# Shapes drift in toward the ring's final radius.
	for sh: Array in SHAPES:
		var ang: float = float(sh[2])
		var k: float = clampf(_t / 1.25, 0.0, 1.0)
		var d: float = lerpf(330.0 * s, ring_r, 1.0 - pow(1.0 - k, 2.0))
		var p: Vector2 = c + Vector2.from_angle(ang) * d
		var col: Color = Color(str(sh[1]))
		if not _burst:
			Shapes.neon(self, p, 22.0 * s, int(sh[0]), _t * 1.2 + ang, Color(col, appear))
		else:
			var bk: float = clampf((_t - 1.25) / 0.6, 0.0, 1.0)
			for i: int in 7:
				var a2: float = ang + TAU * float(i) / 7.0
				var q: Vector2 = p + Vector2.from_angle(a2) * (8.0 + 90.0 * bk) * s
				draw_line(q, q + Vector2.from_angle(a2) * 10.0 * s * (1.0 - bk), Color(col, 1.0 - bk), 4.0 * s, true)
	# Core.
	draw_texture_rect(glow, Rect2(c - Vector2(120, 120) * s, Vector2(240, 240) * s), false, Color(CYAN, 0.45 * appear))
	draw_circle(c, 46.0 * s, Color("#E9FDFF", appear))
	draw_circle(c, 24.0 * s, Color(CYAN, appear))
	# The growing ring, then the burst.
	if not _burst:
		var gk: float = clampf((_t - 0.35) / 0.9, 0.0, 1.0)
		if gk > 0.0:
			var rr: float = lerpf(56.0 * s, ring_r, gk)
			var hot: bool = gk > 0.85
			draw_arc(c, rr, 0.0, TAU, 96, Color(CYAN, 0.25), 26.0 * s, true)
			draw_arc(c, rr, 0.0, TAU, 96, CYAN.lerp(Color.WHITE, 0.6) if hot else CYAN, (10.0 if hot else 7.0) * s, true)
	else:
		var bk2: float = clampf((_t - 1.25) / 0.7, 0.0, 1.0)
		var wr: float = lerpf(ring_r, ring_r + 260.0 * s, 1.0 - pow(1.0 - bk2, 2.0))
		draw_arc(c, wr, 0.0, TAU, 128, Color("#FFE98A", 1.0 - bk2), 16.0 * s * (1.0 - bk2) + 2.0, true)
		if bk2 < 0.5:
			draw_rect(r, Color(1, 1, 1, 0.18 * (1.0 - bk2 * 2.0)))
	# Title.
	var ta: float = clampf((_t - 1.4) / 0.45, 0.0, 1.0)
	if ta > 0.0:
		var f2: Font = UIKit.font(800)
		var fs: int = int(clampf(size.x * 0.12, 48.0, 104.0))
		var title: String = "RINGBURST"
		var w: float = f2.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var y: float = c.y + 300.0 * s + 20.0 * (1.0 - ta)
		draw_string(f2, Vector2(size.x * 0.5 - w * 0.5, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#F2F4FF", ta))
		var f3: Font = UIKit.font(500)
		var tag: String = "hold · release · burst"
		var tw2: float = f3.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		draw_string(f3, Vector2(size.x * 0.5 - tw2 * 0.5, y + 48.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(CYAN, 0.8 * ta))
