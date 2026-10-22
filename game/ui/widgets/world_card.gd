class_name WorldCard
extends Button
## A world on the worlds list, painted in its own colours: number, name,
## tagline, its new shape, stars and progress, or what opens it when locked.

var world: int = 0
var clears: int = 0
var stars: int = 0
var unlocked: bool = false
var lock_text: String = ""
var _t: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(0, 186)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	for st: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	UIKit.juice(self)


func _process(delta: float) -> void:
	_t += delta
	if unlocked:
		queue_redraw()


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	var w: Dictionary = Worlds.world(world)
	var pal: Dictionary = Look.arena(world)
	var accent: Color = pal["accent"]
	var bg: Color = (pal["top"] as Color).lerp(pal["bottom"], 0.3).lerp(accent, 0.06)
	if not unlocked:
		bg = Color(Style.INK, 0.04)
	draw_style_box(UIKit.box(bg, 36), r)
	if has_focus():
		draw_style_box(UIKit.box(Color.TRANSPARENT, 36, Color(Style.INK, 0.8), 3), r.grow(4))
	var light: bool = bool(pal["light"])
	var ink: Color = (Color("141A3C") if light else Color("F2F4FF")) if unlocked else Color(Style.INK, 0.45)
	var muted: Color = Color(ink, 0.7)
	var pad: float = 28.0
	var cap: FontVariation = (UIKit.font(700) as FontVariation).duplicate()
	cap.spacing_glyph = 3
	draw_string(cap, Vector2(pad, 46), "WORLD %d" % (world + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(accent, 0.9) if unlocked else Color(Style.INK, 0.35))
	draw_string(UIKit.font(600), Vector2(pad, 92), str(w["name"]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 200, 38, ink)
	var tag: String = str(w["tagline"]) if unlocked else lock_text
	draw_string(UIKit.font(400), Vector2(pad, 126), tag, HORIZONTAL_ALIGNMENT_LEFT, size.x - 200, 20, muted)
	# The world's new shape, floating on the right.
	var c: Vector2 = Vector2(size.x - 92.0, size.y * 0.5 + sin(_t * 1.6 + world) * 6.0)
	var col: Color = (pal["enemies"] as Array)[world % 4]
	var info: Dictionary = EnemyTypes.info(world)
	if unlocked:
		draw_circle(c, 58.0, Color(accent, 0.08))
		Shapes.neon(self, c, 30.0, int(info["sides"]), _t * 0.7, col, light)
	else:
		draw_circle(c, 46.0, Color(Style.INK, 0.05))
		draw_texture_rect(UIKit.icon("lock"), Rect2(c - Vector2(18, 18), Vector2(36, 36)), false, Color(Style.INK, 0.4))
	var by: float = size.y - 34.0
	if unlocked:
		var bw: float = size.x - pad - 330.0
		draw_style_box(UIKit.box(Color(ink, 0.12), 3, Color.TRANSPARENT, 0, Vector2.ZERO), Rect2(pad, by - 3, bw, 6))
		if clears > 0:
			draw_style_box(UIKit.box(accent, 3, Color.TRANSPARENT, 0, Vector2.ZERO), Rect2(pad, by - 3, maxf(6.0, bw * clears / float(Worlds.STAGES_PER_WORLD)), 6))
		var f: Font = UIKit.font(600)
		draw_string(f, Vector2(pad + bw + 16, by + 8), "%d/%d" % [clears, Worlds.STAGES_PER_WORLD], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, muted)
		draw_texture_rect(UIKit.art("star"), Rect2(pad + bw + 70, by - 12, 24, 24), false)
		draw_string(f, Vector2(pad + bw + 100, by + 8), "%d/18" % stars, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, muted)
	else:
		draw_string(UIKit.font(600), Vector2(pad, by + 7), "6 stages · boss: %s" % EnemyTypes.BOSSES[world]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(Style.INK, 0.35))
