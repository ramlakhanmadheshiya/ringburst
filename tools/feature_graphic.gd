extends Control
## The Google Play feature graphic (1024 x 500): a ring bursting through neon
## shapes on the night-blue brand colours, the name and a plain line about the
## game. Rendered by tools/render_feature_graphic.tscn.

const TOP: Color = Color("#1A2252")
const BOTTOM: Color = Color("#060918")
const CYAN: Color = Color("#3DF5FF")
const WHITE: Color = Color("#F2F4FF")


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]),
		PackedColorArray([TOP, TOP, BOTTOM, BOTTOM]))
	var c: Vector2 = Vector2(255, 250)
	var glow: Texture2D = Style.glow_texture()
	draw_texture_rect(glow, Rect2(c - Vector2(300, 300), Vector2(600, 600)), false, Color(CYAN, 0.35))
	for k: int in range(1, 4):
		draw_arc(c, 70.0 * k, 0.0, TAU, 96, Color(1, 1, 1, 0.05), 2.0, true)
	# The wave, mid-burst, with shapes shattering on its edge.
	draw_arc(c, 180.0, 0.0, TAU, 128, Color(CYAN, 0.25), 40.0, true)
	draw_arc(c, 180.0, 0.0, TAU, 128, CYAN.lerp(Color.WHITE, 0.4), 13.0, true)
	var shapes: Array = [[3, "#FF4FA3", -1.2, 180.0], [4, "#FFD23F", 0.1, 180.0], [6, "#7CFF6B", 1.9, 180.0], [5, "#B98CFF", 2.8, 236.0], [0, "#4FF0FF", -2.3, 230.0], [3, "#FF7A4F", 0.9, 240.0]]
	for sh: Array in shapes:
		var p: Vector2 = c + Vector2.from_angle(float(sh[2])) * float(sh[3])
		var col: Color = Color(str(sh[1]))
		if float(sh[3]) == 180.0:
			for i: int in 8:
				var a: float = float(sh[2]) + TAU * float(i) / 8.0
				var q: Vector2 = p + Vector2.from_angle(a) * 26.0
				draw_line(q, q + Vector2.from_angle(a) * 16.0, col, 5.0, true)
			draw_texture_rect(glow, Rect2(p - Vector2(40, 40), Vector2(80, 80)), false, Color(col, 0.5))
		else:
			Shapes.neon(self, p, 24.0, int(sh[0]), float(sh[2]), col)
	draw_circle(c, 62.0, Color(CYAN, 0.3))
	draw_circle(c, 48.0, Color("#E9FDFF"))
	draw_circle(c, 25.0, CYAN)
	var title: Font = UIKit.font(800)
	draw_string(title, Vector2(520, 228), "RINGBURST", HORIZONTAL_ALIGNMENT_LEFT, -1, 82, WHITE)
	var body: Font = UIKit.font(500)
	draw_string(body, Vector2(524, 290), "Hold. Release. Burst.", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, CYAN)
	draw_string(body, Vector2(524, 338), "A one-touch neon arcade.", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 1, 1, 0.75))
