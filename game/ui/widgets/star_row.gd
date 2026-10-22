class_name StarRow
extends Control
## Three stars that pop in one after another with rising notes (result card).
## The first `count` light up: one for every shield left at the end.

var _shown: Array[float] = [0.0, 0.0, 0.0]
var _mask: int = 0


func _init() -> void:
	custom_minimum_size = Vector2(0, 104)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows the stars at once, without animation (for the share picture).
func show_now(count: int) -> void:
	_mask = (1 << clampi(count, 0, 3)) - 1
	_shown = [1.0, 1.0, 1.0]
	queue_redraw()


func play(count: int) -> void:
	_mask = (1 << clampi(count, 0, 3)) - 1
	var lit: int = 0
	for i: int in 3:
		var tw: Tween = create_tween()
		tw.tween_interval(0.3 + 0.24 * float(i))
		var on: bool = _mask & (1 << i) != 0
		var note: int = lit
		if on:
			lit += 1
		tw.tween_callback(func() -> void:
			if on:
				Audio.play("star", [1.0, 1.2, 1.45][note], -4.0)
				Haptics.tick()
		)
		tw.tween_method(func(v: float) -> void:
			_shown[i] = v
			queue_redraw(), 0.0, 1.0, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	for i: int in 3:
		var s: float = (88.0 if i == 1 else 70.0) * _shown[i]
		if s <= 1.0:
			continue
		var c: Vector2 = Vector2(size.x * 0.5 + (float(i) - 1.0) * 112.0, size.y * 0.5 - (10.0 if i == 1 else 0.0))
		var r: Rect2 = Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s))
		if _mask & (1 << i) != 0:
			draw_texture_rect(Style.glow_texture(), r.grow(s * 0.35), false, Color(Style.GOLD, 0.35))
			draw_texture_rect(UIKit.art("star"), r, false)
		else:
			draw_texture_rect(UIKit.art("star"), r, false, Color(Style.INK, 0.16))
