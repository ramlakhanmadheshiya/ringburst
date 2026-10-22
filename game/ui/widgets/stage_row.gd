class_name StageRow
extends Button
## One stage on a world's path: a node with its number (a skull for the boss),
## the line to the next node, what ends the stage, its stars and best score.

var world: int = 0
var stage: int = 0
var unlocked: bool = false
var mask: int = 0
var best: int = 0
var current: bool = false
var _t: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(0, 128)
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
	var boss: bool = stage == Worlds.STAGES_PER_WORLD - 1
	var cx: float = 64.0
	var cy: float = size.y * 0.5
	# Path line to the next node.
	if stage < Worlds.STAGES_PER_WORLD - 1:
		draw_line(Vector2(cx, cy + 44), Vector2(cx, size.y + cy - 44), Color(acc, 0.35 if unlocked else 0.12), 4.0, true)
	var card: Rect2 = Rect2(Vector2(120, 10), Vector2(size.x - 124, size.y - 20))
	draw_style_box(UIKit.box(Style.SURFACE if unlocked else Color(Style.INK, 0.03), 28, Color(acc, 0.5) if current else Color.TRANSPARENT, 2 if current else 0), card)
	var r: float = 42.0 if boss else 36.0
	if current:
		draw_arc(Vector2(cx, cy), r + 8.0 + 3.0 * sin(_t * 4.0), 0.0, TAU, 48, Color(acc, 0.5), 3.0, true)
	draw_circle(Vector2(cx, cy), r, acc if unlocked else Color(Style.INK, 0.07))
	var f: Font = UIKit.font(800)
	if boss:
		draw_texture_rect(UIKit.art("skull"), Rect2(Vector2(cx, cy) - Vector2(26, 26), Vector2(52, 52)), false, Color(1, 1, 1, 1.0 if unlocked else 0.4))
	elif not unlocked:
		draw_texture_rect(UIKit.icon("lock"), Rect2(Vector2(cx, cy) - Vector2(16, 16), Vector2(32, 32)), false, Color(Style.INK, 0.4))
	else:
		var num: String = str(stage + 1)
		var w: float = f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		draw_string(f, Vector2(cx - w / 2.0, cy + 12), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Style.PAPER_INK)
	var ink: Color = Style.INK if unlocked else Color(Style.INK, 0.45)
	var x: float = card.position.x + 24.0
	draw_string(UIKit.font(700), Vector2(x, cy - 8), "Boss stage" if boss else "Stage %d" % (stage + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, ink)
	var end: String = "Boss: %s" % EnemyTypes.BOSSES[world]["name"] if boss else "Guardian: Giant %s" % EnemyTypes.info(world)["name"]
	draw_string(UIKit.font(500), Vector2(x, cy + 24), "%d s, then %s" % [int(Worlds.DURATIONS[stage]), end], HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 190, 19, Color(Style.MUTED, 1.0 if unlocked else 0.6))
	# Stars and best.
	var sx: float = card.end.x - 150.0
	for i: int in 3:
		var on: bool = mask & (1 << i) != 0
		draw_texture_rect(UIKit.art("star"), Rect2(sx + i * 42.0, cy - 34, 36, 36), false, Color.WHITE if on else Color(Style.INK, 0.14))
	if best > 0:
		var bt: String = "best %d" % best
		var bw: float = UIKit.font(600).get_string_size(bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_string(UIKit.font(600), Vector2(card.end.x - 24 - bw, cy + 30), bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Style.MUTED)
