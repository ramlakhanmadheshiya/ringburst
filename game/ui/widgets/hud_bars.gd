class_name HudBars
extends Control
## The two thin bars under the score: how far the stage is to its boss (or
## the boss's health once it arrives), and XP towards the next upgrade.

var sim: RunSim
var accent: Color = Style.AMBER
var gem: Color = Color("7CFFCB")
var _t: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(0, 64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var w: float = size.x
	var f: Font = UIKit.font(700)
	var fs: int = 17
	var track: Color = Color(Style.INK, 0.12)
	# Stage / boss bar.
	var y: float = 6.0
	var bar_x: float = 0.0
	var bar_w: float = w - 44.0
	var boss: bool = sim.boss_alive()
	draw_style_box(UIKit.box(track, 6, Color.TRANSPARENT, 0, Vector2.ZERO), Rect2(bar_x, y, bar_w, 12))
	if boss:
		var ratio: float = sim.boss_hp_ratio()
		var red: Color = Color("FF5C7A")
		if ratio > 0.0:
			draw_style_box(UIKit.box(red, 6, Color.TRANSPARENT, 0, Vector2.ZERO), Rect2(bar_x, y, maxf(12.0, bar_w * ratio), 12))
		draw_texture_rect(UIKit.art("skull"), Rect2(w - 36, y - 10, 32, 32), false)
	else:
		var p: float = sim.stage_progress()
		if p > 0.0:
			draw_style_box(UIKit.box(accent, 6, Color.TRANSPARENT, 0, Vector2.ZERO), Rect2(bar_x, y, maxf(12.0, bar_w * p), 12))
		var mode: String = str(sim.spec.get("mode", "stage"))
		var icon: String = "infinity" if mode == "endless" else "skull"
		var a: float = 0.55 + (0.45 * (0.5 + 0.5 * sin(_t * 6.0)) if p > 0.9 else 0.0)
		draw_texture_rect(UIKit.art(icon), Rect2(w - 36, y - 10, 32, 32), false, Color(1, 1, 1, a))
	# XP bar.
	var y2: float = 40.0
	var lv: String = "LV %d" % (sim.level + 1)
	var lw: float = f.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(0, y2 + 13), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(gem, 0.95))
	var xw: float = w - lw - 14.0
	draw_style_box(UIKit.box(track, 4, Color.TRANSPARENT, 0, Vector2.ZERO), Rect2(lw + 14.0, y2 + 2, xw, 8))
	var xr: float = clampf(sim.xp / sim.xp_needed(), 0.0, 1.0)
	if xr > 0.0:
		draw_style_box(UIKit.box(gem, 4, Color.TRANSPARENT, 0, Vector2.ZERO), Rect2(lw + 14.0, y2 + 2, maxf(8.0, xw * xr), 8))
