class_name ShapeDemo
extends Control
## A small looping illustration for How to play and the "new shape" card:
## the core, a growing ring, and a shape doing its thing until the ring
## bursts it. `page` picks the idea: "hold", "perfect", "core", "gems",
## "upgrades", or "shape" with `type` set to an EnemyTypes id.

var page: String = "hold"
var type: int = 0
var accent: Color = Style.AMBER
var colors: Array = ["#FF4FA3", "#FFD23F", "#7CFF6B", "#B98CFF"]
var _t: float = 0.0
const LOOP: float = 3.2


func _init(p: String = "hold", t: int = 0) -> void:
	page = p
	type = t
	custom_minimum_size = Vector2(0, 300)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t = fposmod(_t + delta, LOOP)
	queue_redraw()


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	draw_style_box(UIKit.box(Color(0, 0, 0, 0.25) if Style.DARK else Color(Style.INK, 0.05), 28), r)
	var k: float = minf(size.x, size.y) / 300.0
	var c: Vector2 = Vector2(size.x * 0.32, size.y * 0.5)
	var light: bool = not Style.DARK
	var col: Color = Color(str(colors[type % colors.size()]))
	if light:
		col = col.darkened(0.3)
	var t: float = _t
	# Timeline: shape approaches 0..1.6, ring grows 0.6..1.6, burst at 1.6.
	var start_d: float = 220.0
	var hit_t: float = 1.6
	var d: float = lerpf(start_d, 110.0, clampf(t / hit_t, 0.0, 1.0))
	var ang: float = 0.0
	var alive: bool = t < hit_t
	var ring: float = 0.0
	var phased: bool = false
	var shield: bool = false
	var sides: int = int(EnemyTypes.info(type)["sides"])
	var size_r: float = float(EnemyTypes.info(type)["radius"]) * 1.3
	match page:
		"core":
			d = lerpf(start_d, 34.0 + size_r, clampf(t / 1.8, 0.0, 1.0))
			alive = t < 1.8
		"shape":
			match type:
				EnemyTypes.DASHER:
					if t < 0.7:
						d = lerpf(start_d, 190.0, t / 0.7)
					elif t < 1.2:
						d = 190.0
					else:
						d = lerpf(190.0, 110.0, clampf((t - 1.2) / 0.25, 0.0, 1.0))
				EnemyTypes.ORBITER:
					ang = -t * 1.2
				EnemyTypes.SPAWNER:
					d = lerpf(start_d, 170.0, clampf(t / 0.8, 0.0, 1.0))
					hit_t = 2.2
					alive = t < hit_t
				EnemyTypes.PHASER:
					phased = t < 1.0 and int(t * 4.0) % 2 == 0
				EnemyTypes.SHIELDED:
					shield = t < hit_t
	# Ring timing.
	var ring_end: float = hit_t
	if page != "core":
		ring = lerpf(42.0, d, clampf((t - (ring_end - 1.0)) / 1.0, 0.0, 1.0)) if t < ring_end else 0.0
	var pos: Vector2 = c + Vector2.from_angle(ang) * d * k
	# Core.
	var core_col: Color = Color("141A3C") if light else Color("E9FDFF")
	draw_circle(c, 40.0 * k, Color(accent, 0.25))
	draw_circle(c, 30.0 * k, core_col)
	var hurt: bool = page == "core" and t > 1.8 and t < 2.4
	for i: int in 3:
		var a: float = -PI / 2.0 + TAU * (float(i) - 1.0) / 14.0
		var on: bool = not (page == "core" and t > 1.8 and i == 2)
		draw_circle(c + Vector2.from_angle(a) * 44.0 * k, 5.0 * k, Color(accent, 1.0 if on else 0.18))
	if hurt:
		draw_arc(c, (40.0 + (t - 1.8) * 200.0) * k, 0.0, TAU, 48, Color(1, 0.3, 0.4, 1.0 - (t - 1.8) / 0.6), 4.0 * k, true)
	# Ring and burst.
	if ring > 0.0:
		var hot: bool = ring > d - size_r - 12.0
		draw_arc(c, ring * k, 0.0, TAU, 64, accent.lerp(Color.WHITE, 0.5) if hot else accent, (9.0 if hot else 6.0) * k, true)
		if hot:
			draw_arc(pos, (size_r + 10.0) * k, 0.0, TAU, 32, Color(1, 1, 1, 0.8), 3.0 * k, true)
	if page != "core" and t >= hit_t and t < hit_t + 0.6:
		var bk: float = (t - hit_t) / 0.6
		draw_arc(c, lerpf(d, d + 60.0, bk) * k, 0.0, TAU, 64, Color(Color("FFE98A"), 1.0 - bk), 10.0 * k, true)
		for i: int in 10:
			var a2: float = TAU * float(i) / 10.0
			var p2: Vector2 = pos + Vector2.from_angle(a2) * (10.0 + 70.0 * bk) * k
			draw_circle(p2, 4.0 * k * (1.0 - bk), Color(col, 1.0 - bk))
		var f: Font = UIKit.font(800)
		var txt: String = "PERFECT"
		var fs: int = int(26 * k)
		var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, pos + Vector2(-w / 2.0, -40.0 * k - bk * 20.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Style.INK, 1.0 - bk))
		if type == EnemyTypes.SPLITTER and page == "shape":
			for i: int in 3:
				var a3: float = TAU * float(i) / 3.0
				Shapes.neon(self, pos + Vector2.from_angle(a3) * (20.0 + 40.0 * bk) * k, 10.0 * k, 3, a3, col, light)
	if page == "gems" and t >= hit_t:
		var gk: float = clampf((t - hit_t - 0.2) / 0.6, 0.0, 1.0)
		var gp: Vector2 = pos.lerp(c, gk * gk)
		if gk < 1.0:
			var gs: float = 9.0 * k
			draw_colored_polygon(PackedVector2Array([gp + Vector2(0, -gs), gp + Vector2(gs * 0.7, 0), gp + Vector2(0, gs), gp + Vector2(-gs * 0.7, 0)]), Color("7CFFCB") if not light else Color("168A68"))
		var bar: Rect2 = Rect2(size.x * 0.62, size.y * 0.78, size.x * 0.3, 10.0 * k)
		draw_style_box(UIKit.box(Color(Style.INK, 0.12), 5), bar)
		draw_style_box(UIKit.box(Color("7CFFCB") if not light else Color("168A68"), 5), Rect2(bar.position, Vector2(bar.size.x * (0.4 + 0.5 * gk), bar.size.y)))
	# The shape.
	if alive:
		var rot: float = t * 0.8
		if page == "shape" and type == EnemyTypes.DASHER and t > 0.7 and t < 1.2 and int(t * 12.0) % 2 == 0:
			draw_line(pos, c, Color(col, 0.35), 3.0 * k, true)
		var a: float = 0.3 if phased else 1.0
		Shapes.neon(self, pos, size_r * k, sides, rot, Color(col, a), light)
		if type == EnemyTypes.ORBITER and page == "shape":
			draw_circle(pos, size_r * 0.35 * k, col)
		if shield:
			for i: int in 6:
				var a0: float = t * 1.5 + TAU * float(i) / 6.0
				draw_arc(pos, (size_r + 9.0) * k, a0, a0 + 0.7, 6, Color("9FE8FF"), 3.0 * k, true)
		if page == "shape" and type == EnemyTypes.SPAWNER and t > 0.9:
			var mk: float = fposmod(t - 0.9, 0.6) / 0.6
			Shapes.neon(self, pos.lerp(c, mk * 0.6), 8.0 * k, 3, 0.0, col, light)
