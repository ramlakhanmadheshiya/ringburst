extends Screen
## Title screen, laid out like Single Shot's: Shop and Settings along the top;
## the name; a live demo arena where the bot plays; one Play button that opens
## the next level, with which level that is; and a quiet row of round buttons
## (Worlds, Awards, How to play).

var _demo: ArenaView
var _demo_spec: Dictionary = {}


func build() -> void:
	Audio.music("menu")
	body.add_theme_constant_override("separation", 0)
	var top: HBoxContainer = UIKit.hbox(12, BoxContainer.ALIGNMENT_BEGIN)
	top.custom_minimum_size.y = 84
	var shop: Button = UIKit.icon_button("shopping-bag")
	shop.name = "Shop"
	shop.pressed.connect(func() -> void: app.go("shop"))
	top.add_child(shop)
	var fill: Control = Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(fill)
	var stars: Label = UIKit.label("★ %d" % Profile.total_stars(), Style.SIZE_SMALL + 1, Style.MUTED, 600)
	stars.name = "Stars"
	top.add_child(stars)
	top.add_child(UIKit.gap(4))
	var settings: Button = UIKit.icon_button("settings")
	settings.name = "SettingsButton"
	settings.pressed.connect(func() -> void: app.open_settings())
	top.add_child(settings)
	body.add_child(top)
	body.add_child(UIKit.gap(18))

	var title: Label = UIKit.label("Ringburst", 88, Style.INK, 500)
	title.name = "Title"
	title.add_theme_color_override("font_shadow_color", Color(Style.AMBER, 0.28 if Style.DARK else 0.0))
	title.add_theme_constant_override("shadow_offset_y", 0)
	title.add_theme_constant_override("shadow_outline_size", 18)
	body.add_child(title)
	body.add_child(UIKit.caption("One touch · hold · release", Style.AMBER, 18))
	body.add_child(UIKit.gap(26))

	# A live arena where the bot plays: the game, before you've touched it.
	var frame: PanelContainer = PanelContainer.new()
	frame.name = "Demo"
	frame.add_theme_stylebox_override("panel", UIKit.box(Color(Style.INK, 0.035), 44, Color.TRANSPARENT, 0, Vector2(0, 0)))
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size = Vector2(0, 240)
	_demo = ArenaView.new()
	_demo.demo = true
	_demo.clip_contents = true
	_demo.zoom = 1.9
	_demo.set_world(0)
	frame.add_child(_demo)
	body.add_child(frame)
	# A Neon Shore level with no task, so the demo never ends on its own.
	_demo_spec = Worlds.level_spec(0, 20)
	_demo_spec["goal"] = {}
	_demo_spec["length"] = 20.0
	_start_demo()
	frame.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_play()
	)
	body.add_child(UIKit.gap(28))

	# One main action, and which level it opens.
	var next: Array[int] = Profile.next_level()
	var all_done: bool = Profile.all_cleared()
	var play: Button = UIKit.button("Play", "primary", Style.AMBER, 96, 34, "play")
	play.name = "Play"
	play.custom_minimum_size.x = 340
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(_play)
	body.add_child(play)
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property(play, "scale", Vector2(1.03, 1.03), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(play, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	play.resized.connect(func() -> void: play.pivot_offset = play.size / 2)
	play.button_down.connect(func() -> void: pulse.kill())
	body.add_child(UIKit.gap(12))
	var where: Label = UIKit.label("Every level cleared · chase three stars" if all_done else "%s · Level %d" % [Worlds.world(next[0])["name"], next[1] + 1], Style.SIZE_CAPTION + 1, Style.MUTED, 600)
	where.name = "NextLevel"
	body.add_child(where)
	body.add_child(UIKit.gap(26))

	# Everything else: round buttons with small captions, like Single Shot's result card.
	var row: HBoxContainer = UIKit.hbox(34)
	row.add_child(_round("Worlds", "layout-grid", func() -> void: app.go("worlds")))
	row.add_child(_round("Awards", "trophy", func() -> void: app.open(AchievementsCard.new())))
	row.add_child(_round("How to play", "circle-help", func() -> void: app.open(HowToCard.new()), "HowToPlay"))
	body.add_child(row)


func _round(text: String, icon: String, cb: Callable, node_name: String = "") -> VBoxContainer:
	var box: VBoxContainer = UIKit.vbox(8)
	var b: Button = UIKit.icon_button(icon, 80)
	b.name = node_name if not node_name.is_empty() else text
	b.pressed.connect(cb)
	box.add_child(b)
	box.add_child(UIKit.caption(text, Style.MUTED, 15))
	return box


func _start_demo() -> void:
	var sim: RunSim = RunSim.new(_demo_spec)
	# Start in the middle of the action.
	var bot: Bot = Bot.new("perfect", 11)
	while sim.t < 9.0:
		bot.act(sim)
		sim.step()
	_demo.start(sim)


func _process(_delta: float) -> void:
	# The bot can (rarely) lose: start the demo again.
	if _demo != null and _demo.sim != null and _demo.sim.is_over():
		_start_demo()


func _play() -> void:
	if Profile.all_cleared():
		app.go("worlds")
		return
	var next: Array[int] = Profile.next_level()
	app.open(LevelCard.make(next[0], next[1]))
