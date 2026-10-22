class_name HudBars
extends Control
## The task bar under the HUD: the level's task with its count (or the
## seconds left, or the Giant's or boss's health once it arrives) and one
## thin progress line.

var sim: RunSim
var accent: Color = Style.AMBER
var _t: float = 0.0
var _shown: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(0, 58)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	if sim != null:
		_shown = lerpf(_shown, sim.goal_progress(), minf(1.0, delta * 10.0))
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var w: float = size.x
	var f: Font = UIKit.font(600)
	var fs: int = 22
	var boss: bool = sim.is_boss_goal()
	var boss_here: bool = boss and sim.boss_alive()
	var label: String = Worlds.goal_text(sim.goal, _boss_name())
	var count: String = ""
	match sim.goal_type():
		"survive":
			count = "%ds" % maxi(0, int(ceil(float(sim.goal_target()) - sim.t)))
		"guardian", "boss":
			count = "%d%%" % int(round(sim.boss_hp_ratio() * 100.0)) if boss_here else "coming"
		_:
			count = "%d / %d" % [mini(sim.goal_count(), sim.goal_target()), sim.goal_target()]
	var icon: Texture2D = UIKit.icon(Worlds.goal_icon(sim.goal))
	var col: Color = Color("FF5C7A") if boss_here else accent
	if icon != null:
		draw_texture_rect(icon, Rect2(0, 2, 26, 26), false, col)
	draw_string(f, Vector2(36, 24), label, HORIZONTAL_ALIGNMENT_LEFT, w - 150.0, fs, Style.INK)
	var cw: float = f.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(w - cw, 24), count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	# Progress (a boss counts its health down instead).
	var y: float = 42.0
	var ratio: float = sim.boss_hp_ratio() if boss_here else _shown
	draw_style_box(UIKit.box(Color(Style.INK, 0.12), 4, Color.TRANSPARENT, 0, Vector2.ZERO), Rect2(0, y, w, 8))
	if ratio > 0.0:
		draw_style_box(UIKit.box(col, 4, Color.TRANSPARENT, 0, Vector2.ZERO), Rect2(0, y, maxf(8.0, w * ratio), 8))
	if boss and not boss_here and sim.state == RunSim.State.RUNNING:
		# The big one is on its way: a soft pulse along the bar.
		var a: float = 0.25 + 0.25 * sin(_t * 5.0)
		draw_style_box(UIKit.box(Color(Color("FF5C7A"), a), 4, Color.TRANSPARENT, 0, Vector2.ZERO), Rect2(0, y, w, 8))


func _boss_name() -> String:
	return str((sim.spec.get("boss", {}) as Dictionary).get("name", "the boss"))
