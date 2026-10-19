extends Screen
## Title screen: Shop, coins and Settings along the top; the name; a live
## demo arena where the bot plays; one centred column with Play (and where it
## continues), Worlds, Forge, Endless and Awards; and today's Daily Run.

var _daily_status: Label
var _daily_btn: Button
var _demo: ArenaView


func build() -> void:
	Audio.music("menu")
	body.add_theme_constant_override("separation", 14)
	var top: HBoxContainer = UIKit.hbox(12, BoxContainer.ALIGNMENT_BEGIN)
	top.custom_minimum_size.y = 92
	var shop: Button = UIKit.icon_button("art:bag", Style.TOP_BUTTON)
	shop.name = "Shop"
	shop.pressed.connect(func() -> void: app.go("shop"))
	top.add_child(shop)
	var fill: Control = Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(fill)
	var coins: CounterChip = UIKit.coin_chip()
	coins.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(coins)
	var settings: Button = UIKit.icon_button("settings", Style.TOP_BUTTON)
	settings.name = "SettingsButton"
	settings.pressed.connect(func() -> void: app.open_settings())
	top.add_child(settings)
	body.add_child(top)

	var title_box: VBoxContainer = UIKit.vbox(0)
	var title: Label = UIKit.label("RINGBURST", 84, Style.INK, 800)
	title.name = "Title"
	title.add_theme_color_override("font_shadow_color", Color(Style.AMBER, 0.45 if Style.DARK else 0.25))
	title.add_theme_constant_override("shadow_offset_y", 0)
	title.add_theme_constant_override("shadow_outline_size", 22)
	title_box.add_child(title)
	title_box.add_child(UIKit.caption("One touch · hold · release · burst", Style.AMBER))
	body.add_child(title_box)

	# A live arena where the bot plays: the game, before you've touched it.
	var frame: PanelContainer = PanelContainer.new()
	frame.name = "Demo"
	frame.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.0), 34, Color(Style.AMBER, 0.35), 2, Vector2(4, 4)))
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size = Vector2(0, 250)
	_demo = ArenaView.new()
	_demo.demo = true
	_demo.clip_contents = true
	_demo.zoom = 1.9
	_demo.set_world(0)
	frame.add_child(_demo)
	body.add_child(frame)
	var demo_spec: Dictionary = Worlds.endless_spec(4242)
	demo_spec["difficulty"] = 1.2
	var demo_sim: RunSim = RunSim.new(demo_spec, RunStats.make({"power": 2}))
	# Start in the middle of the action.
	var bot: Bot = Bot.new("perfect", 11)
	while demo_sim.t < 9.0:
		bot.act(demo_sim)
		demo_sim.step()
	_demo.start(demo_sim)
	frame.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_play()
	)

	# One centred column for every action, all the same width.
	var column: VBoxContainer = UIKit.vbox(14)
	column.custom_minimum_size.x = 580
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var next: Array[int] = Profile.next_stage()
	var all_done: bool = Profile.all_cleared()
	var play: Button = UIKit.button("Play", "primary", Style.AMBER, 112, 40, "play")
	play.name = "Play"
	play.pressed.connect(_play)
	column.add_child(play)
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property(play, "scale", Vector2(1.03, 1.03), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(play, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	play.resized.connect(func() -> void: play.pivot_offset = play.size / 2)
	play.button_down.connect(func() -> void: pulse.kill())
	var where: Label = UIKit.label("Every world cleared · try Endless" if all_done else "%s · Stage %d" % [Worlds.world(next[0])["name"], next[1] + 1], Style.SIZE_SMALL + 1, Style.MUTED, 600)
	where.name = "NextStage"
	column.add_child(where)
	var row: HBoxContainer = UIKit.hbox(14)
	row.add_child(_wide("Worlds", "layout-grid", func() -> void: app.go("worlds")))
	row.add_child(_wide("Forge", "art:hammer", func() -> void: app.go("forge")))
	column.add_child(row)
	var row2: HBoxContainer = UIKit.hbox(14)
	var endless: Button = _wide("Endless", "art:infinity" if Profile.endless_unlocked() else "lock", func() -> void:
		if Profile.endless_unlocked():
			app.go("play", {"mode": "endless"})
		else:
			Audio.play("error", 1.2, -8.0)
			app.toast("Clear Neon Shore stage 3 to open Endless", "lock", Style.AMBER)
	)
	row2.add_child(endless)
	row2.add_child(_wide("Awards", "art:trophy", func() -> void: app.open(AchievementsCard.new())))
	column.add_child(row2)
	column.add_child(_daily_card())
	body.add_child(column)

	var timer: Timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_update_daily)
	add_child(timer)
	_update_daily()


func _wide(text: String, icon: String, cb: Callable) -> Button:
	var b: Button = UIKit.button(text, "soft", Style.AMBER, 84, 26, icon)
	b.name = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b


func _play() -> void:
	if Profile.all_cleared():
		app.go("worlds")
		return
	var next: Array[int] = Profile.next_stage()
	app.open(StageCard.make(next[0], next[1]))


func _daily_card() -> PanelContainer:
	var row: HBoxContainer = UIKit.hbox(16, BoxContainer.ALIGNMENT_BEGIN)
	row.add_child(UIKit.art_rect("calendar", 60))
	var mid: VBoxContainer = UIKit.vbox(2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mod: String = str(Worlds.daily_spec(Profile.today_key())["modifier"])
	mid.add_child(UIKit.label("Daily Run · %s" % Worlds.MODIFIERS[mod]["name"], Style.SIZE_BODY - 2, Style.INK, 700, HORIZONTAL_ALIGNMENT_LEFT))
	_daily_status = UIKit.label("", Style.SIZE_CAPTION + 1, Style.MUTED, 500, HORIZONTAL_ALIGNMENT_LEFT)
	_daily_status.name = "DailyStatus"
	_daily_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mid.add_child(_daily_status)
	row.add_child(mid)
	_daily_btn = UIKit.button("Play", "primary", Style.PINK, 72, 26)
	_daily_btn.name = "Daily"
	_daily_btn.custom_minimum_size.x = 140
	_daily_btn.pressed.connect(func() -> void:
		if not Profile.daily_unlocked():
			Audio.play("error", 1.2, -8.0)
			app.toast("Clear your first stage to open the Daily Run", "lock", Style.AMBER)
			return
		app.open(DailyCard.new())
	)
	row.add_child(_daily_btn)
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.lip_box(Style.PANEL, 30, Style.LIP, 6, Vector2(20, 14)))
	p.add_child(row)
	return p


func _update_daily() -> void:
	var today: String = Profile.today_key()
	if not Profile.daily_unlocked():
		_daily_status.text = "Clear your first stage to unlock"
		_daily_btn.text = "Play"
		return
	var streak: int = Profile.current_streak()
	var streak_text: String = "%d-day streak" % streak if streak > 0 else "Start a streak"
	if Profile.daily_done(today):
		var now: Dictionary = Time.get_time_dict_from_system()
		var left: int = 86400 - (int(now["hour"]) * 3600 + int(now["minute"]) * 60 + int(now["second"]))
		_daily_status.text = "Best %d · %s · next in %dh %02dm" % [Profile.daily_best(today), streak_text, left / 3600, (left % 3600) / 60]
		_daily_btn.text = "Replay"
	else:
		_daily_status.text = "%s · +%d coins" % [streak_text, Economy.daily_reward(streak + 1)]
		_daily_btn.text = "Play"


func refresh() -> void:
	_update_daily()
