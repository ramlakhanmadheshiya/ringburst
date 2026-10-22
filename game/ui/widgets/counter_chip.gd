class_name CounterChip
extends PanelContainer
## The coin balance pill. Counts smoothly to new values, pulses when it
## changes, and can be tapped (it opens the coin bags).

signal pressed

var _label: Label
var _shown: float = 0.0
var _tween: Tween


func _init() -> void:
	name = "Coins"
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("panel", UIKit.box(Color(Style.INK, 0.07), 32, Color.TRANSPARENT, 0, Vector2(14, 10)))
	var row: HBoxContainer = UIKit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	row.add_child(UIKit.art_rect("coin", 34))
	_label = UIKit.label("0", 25, Style.INK, 600)
	_label.custom_minimum_size.x = 56
	row.add_child(_label)
	row.add_child(UIKit.icon_rect("plus", 20, Style.MUTED))


func _ready() -> void:
	_shown = Profile.coins()
	_label.text = str(Profile.coins())
	Profile.coins_changed.connect(_on_changed)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		Audio.play("click", 1.0, -6.0)
		pressed.emit()
		accept_event()


func _on_changed(total: int) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_method(func(v: float) -> void:
		_shown = v
		_label.text = str(int(round(v)))
	, _shown, float(total), 0.6)
	pivot_offset = size / 2
	scale = Vector2(1.12, 1.12)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
