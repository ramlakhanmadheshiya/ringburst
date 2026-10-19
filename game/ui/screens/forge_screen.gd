extends Screen
## The Forge: spend coins from runs on permanent upgrades, new ring types and
## starting perks. Three tabs on a thin slider: Upgrades, Rings, Perks.

const TABS: Array[String] = ["upgrades", "rings", "perks"]

var _tab: int = 0
var _list: VBoxContainer
var _scroll: TouchScroll


func build() -> void:
	body.add_child(header("Forge", "Permanent upgrades"))
	body.add_child(chip_row([UIKit.coin_chip()]))
	var tabs: SegmentedSlider = SegmentedSlider.new(PackedStringArray(["Upgrades", "Rings", "Perks"]), int(args.get("tab", 0)))
	tabs.name = "Tabs"
	tabs.custom_minimum_size = Vector2(0, 64)
	tabs.changed.connect(func(i: int) -> void:
		_tab = i
		_fill()
	)
	body.add_child(tabs)
	_tab = int(args.get("tab", 0))
	_scroll = TouchScroll.new()
	_scroll.name = "Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_scroll)
	_list = UIKit.vbox(14)
	_list.name = "List"
	_scroll.set_content(_list)
	Profile.coins_changed.connect(func(_c: int) -> void:
		if is_inside_tree():
			_fill.call_deferred()
	)
	_fill()


func _fill() -> void:
	for c: Node in _list.get_children():
		c.queue_free()
	match TABS[_tab]:
		"upgrades":
			_list.add_child(UIKit.para("Every run pays coins, won or lost. Forge upgrades last forever.", Style.SIZE_SMALL))
			for id: String in RingTypes.forge_ids():
				_list.add_child(_forge_row(id))
		"rings":
			_list.add_child(UIKit.para("Ring types change how the ring plays. Pick one before each stage.", Style.SIZE_SMALL))
			for id: String in RingTypes.ring_ids():
				_list.add_child(_ring_row(id))
		"perks":
			_list.add_child(UIKit.para("A starting perk is an upgrade you begin every run with. Unlock once, then pick one before each stage.", Style.SIZE_SMALL))
			for id: String in Upgrades.PERKS:
				_list.add_child(_perk_row(id))
	_list.add_child(UIKit.gap(16))
	_scroll.scroll_to(0)


func _row(icon: Control, title: String, sub: String, right: Control, node_name: String, extra: Control = null) -> PanelContainer:
	var row: HBoxContainer = UIKit.hbox(16, BoxContainer.ALIGNMENT_BEGIN)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var text: VBoxContainer = UIKit.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_child(UIKit.label(title, 27, Style.INK, 700, HORIZONTAL_ALIGNMENT_LEFT))
	var s: Label = UIKit.label(sub, 19, Style.MUTED, 500, HORIZONTAL_ALIGNMENT_LEFT)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(s)
	if extra != null:
		text.add_child(extra)
	row.add_child(text)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)
	var p: PanelContainer = UIKit.panel(row, Style.SURFACE, 30, Vector2(20, 16))
	p.name = node_name
	return p


func _badge(icon_name: String, tint: Color) -> PanelContainer:
	var b: PanelContainer = UIKit.panel(UIKit.icon_rect(icon_name, 40, tint), Color(tint, 0.15), 30, Vector2(14, 14))
	return b


func _buy_button(cost: int, node_name: String, cb: Callable) -> Button:
	var b: Button = UIKit.button(str(cost), "primary", Style.GOLD, 68, 24, "art:coin")
	b.name = node_name
	b.custom_minimum_size.x = 150
	b.disabled = Profile.coins() < cost
	b.pressed.connect(cb)
	return b


func _forge_row(id: String) -> PanelContainer:
	var d: Dictionary = RingTypes.FORGE[id]
	var lvl: int = Profile.forge_level(id)
	var mx: int = int(d["max"])
	var pips: HBoxContainer = UIKit.hbox(6, BoxContainer.ALIGNMENT_BEGIN)
	for k: int in mx:
		var dot: ColorRect = ColorRect.new()
		dot.custom_minimum_size = Vector2(26, 8)
		dot.color = Style.AMBER if k < lvl else Color(Style.INK, 0.15)
		pips.add_child(dot)
	var right: Control
	if lvl >= mx:
		right = UIKit.label("MAX", 24, Style.SUCCESS, 800)
	else:
		var cost: int = Profile.forge_next_cost(id)
		right = _buy_button(cost, "Buy_" + id, func() -> void:
			if Profile.buy_forge(id):
				Audio.play("unlock", 1.0, -3.0)
				Haptics.success()
				app.toast("%s %s" % [d["name"], Upgrades.roman(Profile.forge_level(id))], "hammer", Style.GOLD)
				_fill()
		)
	return _row(_badge(str(d["icon"]), Style.AMBER), str(d["name"]), str(d["desc"]), right, "Forge_" + id, pips)


func _ring_row(id: String) -> PanelContainer:
	var d: Dictionary = RingTypes.RINGS[id]
	var right: Control
	if Profile.owns_ring(id):
		if Profile.ring() == id:
			right = UIKit.label("In use", 22, Style.SUCCESS, 800)
		else:
			var use: Button = UIKit.button("Use", "soft", Style.AMBER, 64, 22)
			use.name = "Use_" + id
			use.custom_minimum_size.x = 130
			use.pressed.connect(func() -> void:
				Profile.set_ring(id)
				Audio.play("click", 1.2, -4.0)
				_fill()
			)
			right = use
	else:
		right = _buy_button(int(d["cost"]), "BuyRing_" + id, func() -> void:
			if Profile.buy_ring(id):
				Audio.play("unlock", 1.0, -3.0)
				Haptics.success()
				app.toast("%s ring unlocked" % d["name"], "circle-dot", Style.GOLD)
				_fill()
		)
	var pv: RingBadge = RingBadge.new()
	pv.ring = id
	return _row(pv, str(d["name"]), str(d["blurb"]), right, "Ring_" + id)


func _perk_row(id: String) -> PanelContainer:
	var right: Control
	if Profile.owns_perk(id):
		if Profile.perk() == id:
			right = UIKit.label("In use", 22, Style.SUCCESS, 800)
		else:
			var use: Button = UIKit.button("Use", "soft", Style.AMBER, 64, 22)
			use.name = "UsePerk_" + id
			use.custom_minimum_size.x = 130
			use.pressed.connect(func() -> void:
				Profile.set_perk(id)
				Audio.play("click", 1.2, -4.0)
				_fill()
			)
			right = use
	else:
		right = _buy_button(RingTypes.PERK_COST, "BuyPerk_" + id, func() -> void:
			if Profile.buy_perk(id):
				Audio.play("unlock", 1.0, -3.0)
				Haptics.success()
				_fill()
		)
	return _row(_badge(str(Upgrades.def(id)["icon"]), Style.PINK), Upgrades.display_name(id), "Start with: " + Upgrades.describe(id, 1), right, "Perk_" + id)


## A small drawing of a ring type: the core and its ring, with a hint of
## what makes it different.
class RingBadge:
	extends Control
	var ring: String = "classic"
	var _t: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(72, 72)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size / 2.0
		var acc: Color = Style.AMBER
		draw_style_box(UIKit.box(Color(acc, 0.12), 30), Rect2(Vector2.ZERO, size))
		draw_circle(c, 9.0, Style.INK)
		var r: float = 18.0 + 8.0 * (0.5 + 0.5 * sin(_t * 2.0))
		var w: float = 4.0
		match ring:
			"twin":
				draw_arc(c, r, 0.0, TAU, 48, acc, w, true)
				draw_arc(c, r * 0.7, 0.0, TAU, 48, Color(acc, 0.6), 3.0, true)
			"glacier":
				draw_arc(c, r, 0.0, TAU, 48, Color("9FE8FF"), w, true)
			"lens":
				draw_arc(c, r, 0.0, TAU, 48, acc, w * 2.2, true)
			"nova":
				draw_arc(c, r * 0.85, 0.0, TAU, 48, Color("FFE98A"), w, true)
			"cinder":
				draw_arc(c, r, 0.0, TAU, 48, Color("FF7A3D"), w, true)
			"titan":
				draw_arc(c, r, 0.0, TAU, 48, Color("FF4FA3"), w * 1.8, true)
			_:
				draw_arc(c, r, 0.0, TAU, 48, acc, w, true)
