class_name LevelTile
extends Button
## One level in a world's grid: its number (a skull for a Giant or the boss),
## the stars earned under it, a lock while it's closed, and a soft pulse on
## the level to play next.

var world: int = 0
var level: int = 0
var unlocked: bool = false
var stars: int = 0
var current: bool = false
var _t: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(0, 112)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	for st: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	UIKit.juice(self)


func _process(delta: float) -> void:
	_t += delta
	if current:
		queue_redraw()


func _draw() -> void:
	var acc: Color = Look.accent(world)
	var r: Rect2 = Rect2(Vector2(4, 4), size - Vector2(8, 8))
	var big: bool = Worlds.is_boss(level) or Worlds.is_guardian(level)
	var fill: Color = Style.SURFACE if unlocked else Color(Style.INK, 0.03)
	if current:
		fill = Color(acc, 0.16)
	draw_style_box(UIKit.box(fill, 26), r)
	if current:
		var a: float = 0.45 + 0.35 * sin(_t * 4.0)
		draw_style_box(UIKit.box(Color.TRANSPARENT, 26, Color(acc, a), 3), r)
	if has_focus():
		draw_style_box(UIKit.box(Color.TRANSPARENT, 28, Color(Style.INK, 0.8), 3), r.grow(3))
	var c: Vector2 = Vector2(size.x * 0.5, size.y * 0.42)
	if not unlocked:
		draw_texture_rect(UIKit.icon("lock"), Rect2(c - Vector2(15, 15), Vector2(30, 30)), false, Color(Style.INK, 0.3))
		return
	var ink: Color = Style.INK
	if big:
		var icon: Texture2D = UIKit.icon("skull")
		draw_texture_rect(icon, Rect2(c - Vector2(17, 19), Vector2(34, 34)), false, Color("FF5C7A") if Worlds.is_boss(level) else acc)
	else:
		var f: Font = UIKit.font(600)
		var num: String = str(level + 1)
		var w: float = f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
		draw_string(f, Vector2(c.x - w / 2.0, c.y + 11.0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, ink)
	# Stars under the number.
	var sy: float = size.y - 30.0
	for i: int in 3:
		var sx: float = size.x * 0.5 + (float(i) - 1.0) * 22.0 - 9.0
		draw_texture_rect(UIKit.art("star"), Rect2(sx, sy, 18, 18), false, Color.WHITE if i < stars else Color(Style.INK, 0.14))
