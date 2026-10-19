class_name HowToCard
extends Overlay
## How to play, one page per idea, each with a small looping demo. The last
## page offers to replay the hands-on tutorial.

const PAGES: Array[Dictionary] = [
	{"demo": "hold", "title": "Hold, then let go", "text": "Hold anywhere and a ring grows from your core. Let go and it bursts outward as a shockwave that hits every shape inside the ring. A bigger ring reaches further, but while it grows you aren't attacking."},
	{"demo": "perfect", "title": "PERFECT", "text": "Let go while a shape sits right on the ring's edge (it lights up white) for a PERFECT: double damage, a spark that jumps to nearby shapes, and +1 combo. Your combo multiplies your score, up to x4. A burst that hits nothing breaks it."},
	{"demo": "core", "title": "Guard your core", "text": "A shape that touches your core breaks a shield and shoves everything back. Lose every shield and the run ends (you can revive once). Some upgrades bring shields back."},
	{"demo": "gems", "title": "Gems and upgrades", "text": "Burst shapes drop gems; your waves pull them in. Fill the XP bar to level up and pick 1 of 3 upgrades: Echo, Frost Ring, Chain Lightning and 23 more. Some pairs unlock a powerful synergy."},
	{"demo": "shapes", "title": "Eight shapes, eight worlds", "text": "Each world brings one new shape with its own trick, taught before its first stage. Survive a stage until its Guardian or boss arrives, then beat it. Stars: clear, take no hits, and reach the combo goal."},
	{"demo": "modes", "title": "Forge, Daily and Endless", "text": "Every run pays coins, win or lose. Spend them in the Forge on permanent upgrades, ring types and starting perks. The Daily Run is built from the date, the same for everyone. Endless keeps going until you fall."},
]

var _index: int = 0
var _holder: VBoxContainer
var _prev: Button
var _next: Button
var _dots: HBoxContainer


func build() -> void:
	name = "HowTo"
	add_title("How to play")
	_holder = UIKit.vbox(14)
	body.add_child(_holder)
	var nav: HBoxContainer = UIKit.hbox(16)
	_prev = UIKit.icon_button("chevron-left", 80)
	_prev.name = "Prev"
	_prev.pressed.connect(func() -> void: _show(_index - 1))
	nav.add_child(_prev)
	_dots = UIKit.hbox(10)
	_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(_dots)
	_next = UIKit.button("Next", "primary", Style.AMBER, 80, 28)
	_next.name = "Next"
	_next.custom_minimum_size.x = 200
	_next.pressed.connect(func() -> void:
		if _index >= PAGES.size() - 1:
			close()
		else:
			_show(_index + 1)
	)
	nav.add_child(_next)
	body.add_child(nav)
	var replay: Button = UIKit.button("Replay the tutorial", "ghost", Style.AMBER, 66, 21, "pointer")
	replay.name = "ReplayTutorial"
	replay.pressed.connect(func() -> void:
		Save.data["seen"].erase("tutorial")
		Save.mark_dirty()
		app.close_overlays()
		app.go("play", {"world": 0, "stage": 0})
	)
	body.add_child(replay)
	_show(0)


func _show(i: int) -> void:
	_index = clampi(i, 0, PAGES.size() - 1)
	for c: Node in _holder.get_children():
		c.queue_free()
	var page: Dictionary = PAGES[_index]
	var demo_name: String = str(page["demo"])
	if demo_name == "shapes":
		_holder.add_child(ShapeGrid.new())
	elif demo_name == "modes":
		var row: HBoxContainer = UIKit.hbox(26)
		row.custom_minimum_size.y = 200
		for a: String in ["hammer", "calendar", "infinity"]:
			row.add_child(UIKit.art_rect(a, 110))
		_holder.add_child(row)
	else:
		var demo: ShapeDemo = ShapeDemo.new(demo_name, 0)
		demo.accent = Style.AMBER
		demo.custom_minimum_size = Vector2(0, 260)
		_holder.add_child(demo)
	_holder.add_child(UIKit.label(page["title"], Style.SIZE_H2, Style.AMBER, 700))
	_holder.add_child(UIKit.para(page["text"], Style.SIZE_BODY - 3, Style.INK))
	_prev.disabled = _index == 0
	_next.text = "Got it" if _index == PAGES.size() - 1 else "Next"
	for c: Node in _dots.get_children():
		c.queue_free()
	for k: int in PAGES.size():
		var dot: ColorRect = ColorRect.new()
		dot.custom_minimum_size = Vector2(14, 14) if k != _index else Vector2(34, 14)
		dot.color = Style.AMBER if k == _index else Color(Style.INK, 0.25)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_dots.add_child(dot)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	refit()


## The eight shapes in a 4 x 2 grid with their names.
class ShapeGrid:
	extends Control
	var _t: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 260)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var light: bool = not Style.DARK
		var cw: float = size.x / 4.0
		for i: int in 8:
			var info: Dictionary = EnemyTypes.info(i)
			var col: Color = Color(str(Worlds.world(i)["enemies"][0]))
			if light:
				col = col.darkened(0.3)
			var c: Vector2 = Vector2(cw * (float(i % 4) + 0.5), 70.0 + 130.0 * float(i / 4))
			Shapes.neon(self, c, 26.0, int(info["sides"]), _t * 0.6 + i, col, light)
			var f: Font = UIKit.font(600)
			var name: String = str(info["name"])
			var w: float = f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
			draw_string(f, c + Vector2(-w / 2.0, 54), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Style.INK)
