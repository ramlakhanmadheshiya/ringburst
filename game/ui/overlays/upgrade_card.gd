class_name UpgradeCard
extends Overlay
## Level up: pick one of three upgrades (or reroll them). The run waits.

var play: Node
var _list: VBoxContainer


func _init() -> void:
	super._init()
	dismissable = false


func build() -> void:
	name = "LevelUp"
	body.add_theme_constant_override("separation", 12)
	body.add_child(UIKit.caption("Level %d" % (play.sim.level + 1 - play.sim.pending_levels + 1), Color("7CFFCB")))
	var t: Label = UIKit.label("Choose an upgrade", Style.SIZE_H1, Style.INK, 700)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(t)
	_list = UIKit.vbox(12)
	body.add_child(_list)
	_fill()
	if play.sim.rerolls_left > 0:
		var rr: Button = UIKit.button("Reroll (%d left)" % play.sim.rerolls_left, "ghost", Style.AMBER, 70, 22, "refresh-cw")
		rr.name = "Reroll"
		rr.pressed.connect(func() -> void:
			if play.sim.reroll():
				Audio.play("click", 1.2, -2.0)
				rr.text = "Reroll (%d left)" % play.sim.rerolls_left
				rr.disabled = play.sim.rerolls_left <= 0
				_fill()
		)
		body.add_child(rr)
	Audio.play("levelup", 1.2, -6.0)


func _fill() -> void:
	for c: Node in _list.get_children():
		c.queue_free()
	var offers: Array = play.sim.offers
	for i: int in offers.size():
		_list.add_child(_option(i, str(offers[i])))
	refit()


func _option(i: int, id: String) -> Button:
	var d: Dictionary = Upgrades.def(id)
	var lvl: int = play.sim.stats.level(id) + 1
	var synergy: bool = d.has("requires")
	var b: Button = Button.new()
	b.name = "Option%d" % (i + 1)
	b.custom_minimum_size = Vector2(0, 132)
	b.focus_mode = Control.FOCUS_ALL
	var tint: Color = Style.GOLD if synergy else Style.AMBER
	var fill: Color = Style.SURFACE.lerp(tint, 0.12 if synergy else 0.04)
	for st: String in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, UIKit.lip_box(fill.lightened(0.05 if st == "hover" else 0.0), 30, Style.LIP, 7, Vector2(8, 8), false, tint if synergy else Color.TRANSPARENT))
	b.add_theme_stylebox_override("pressed", UIKit.lip_box(fill.darkened(0.05), 30, Style.LIP, 7, Vector2(8, 8), true))
	b.add_theme_stylebox_override("hover_pressed", UIKit.lip_box(fill.darkened(0.05), 30, Style.LIP, 7, Vector2(8, 8), true))
	UIKit.juice(b)
	b.pressed.connect(func() -> void: _pick(i))
	var row: HBoxContainer = UIKit.hbox(18, BoxContainer.ALIGNMENT_BEGIN)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20
	row.offset_right = -20
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var badge: PanelContainer = UIKit.panel(UIKit.icon_rect(str(d.get("icon", "zap")), 44, tint), Color(tint, 0.16), 34, Vector2(16, 16))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(badge)
	var text: VBoxContainer = UIKit.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if synergy:
		text.add_child(UIKit.caption("Synergy", Style.GOLD, 15, HORIZONTAL_ALIGNMENT_LEFT))
	var name_l: Label = UIKit.label("%s %s" % [str(d["name"]), Upgrades.roman(lvl) if int(d["max"]) > 1 else ""], 29, Style.INK, 700, HORIZONTAL_ALIGNMENT_LEFT)
	text.add_child(name_l)
	var desc: Label = UIKit.label(Upgrades.describe(id, lvl), 20, Style.MUTED, 500, HORIZONTAL_ALIGNMENT_LEFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(desc)
	row.add_child(text)
	var pips: HBoxContainer = UIKit.hbox(4)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for k: int in int(d["max"]):
		var dot: ColorRect = ColorRect.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.color = tint if k < lvl else Color(Style.INK, 0.18)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(dot)
	if int(d["max"]) > 1:
		row.add_child(pips)
	b.modulate.a = 0.0
	create_tween().tween_property(b, "modulate:a", 1.0, 0.2).set_delay(0.06 * i)
	return b


func _unhandled_key_input(e: InputEvent) -> void:
	if e.pressed and e is InputEventKey:
		var k: int = (e as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_3:
			_pick(k - KEY_1)
			get_viewport().set_input_as_handled()


func _pick(i: int) -> void:
	if _closing or i >= play.sim.offers.size():
		return
	Audio.play("upgrade", 1.0, -2.0)
	Haptics.success()
	play.sim.choose(i)
	close()
