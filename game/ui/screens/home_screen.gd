extends Screen
## Title screen, laid out like Single Shot's: Shop, coins and Settings along
## the top; the name; a live demo arena where the bot plays; one Play button
## with where it continues; a quiet row of round buttons (Worlds, Forge,
## Endless, Awards); and today's Daily Run as one slim row.

var _daily_status: Label
var _daily_btn: Button
var _demo: ArenaView


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
	var coins: CounterChip = UIKit.coin_chip()
	coins.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(coins)
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
	body.add_child(UIKit.gap(28))

	# One main action, and where it continues.
	var next: Array[int] = Profile.next_stage()
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
	var where: Label = UIKit.label("Every world cleared · try Endless" if all_done else "%s · Stage %d" % [Worlds.world(next[0])["name"], next[1] + 1], Style.SIZE_CAPTION + 1, Style.MUTED, 600)
	where.name = "NextStage"
	body.add_child(where)
	body.add_child(UIKit.gap(26))

	# Everything else: round buttons with small captions, like Single Shot's result card.
	var row: HBoxContainer = UIKit.hbox(30)
	row.add_child(_round("Worlds", "layout-grid", func() -> void: app.go("worlds")))
	row.add_child(_round("Forge", "hammer", func() -> void: app.go("forge")))
	row.add_child(_round("Endless", "infinity" if Profile.endless_unlocked() else "lock", func() -> void:
		if Profile.endless_unlocked():
			app.go("play", {"mode": "endless"})
		else:
			Audio.play("error", 1.2, -8.0)
			app.toast("Clear Neon Shore stage 3 to open Endless", "lock", Style.AMBER)
	))
	row.add_child(_round("Awards", "trophy", func() -> void: app.open(AchievementsCard.new())))
	body.add_child(row)
	body.add_child(UIKit.gap(22))
	body.add_child(_daily_row())

	var timer: Timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_update_daily)
	add_child(timer)
	_update_daily()


func _round(text: String, icon: String, cb: Callable) -> VBoxContainer:
	var box: VBoxContainer = UIKit.vbox(8)
	var b: Button = UIKit.icon_button(icon, 80)
	b.name = text
	b.pressed.connect(cb)
	box.add_child(b)
	box.add_child(UIKit.caption(text, Style.MUTED, 15))
	return box


func _play() -> void:
	if Profile.all_cleared():
		app.go("worlds")
		return
	var next: Array[int] = Profile.next_stage()
	app.open(StageCard.make(next[0], next[1]))


## Today's Daily Run as one quiet pill: the calendar, its modifier, and the
## streak or countdown. Tapping it opens the Daily card.
func _daily_row() -> Button:
	_daily_btn = UIKit.button("", "soft", Style.AMBER, 84, 22)
	_daily_btn.name = "Daily"
	_daily_btn.custom_minimum_size.x = 520
	_daily_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_daily_btn.pressed.connect(func() -> void:
		if not Profile.daily_unlocked():
			Audio.play("error", 1.2, -8.0)
			app.toast("Clear your first stage to open the Daily Run", "lock", Style.AMBER)
			return
		app.open(DailyCard.new())
	)
	var row: HBoxContainer = UIKit.hbox(14, BoxContainer.ALIGNMENT_BEGIN)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 26
	row.offset_right = -22
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_daily_btn.add_child(row)
	row.add_child(UIKit.icon_rect("calendar", 34, Style.PINK))
	var mid: VBoxContainer = UIKit.vbox(0)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mod: String = str(Worlds.daily_spec(Profile.today_key())["modifier"])
	mid.add_child(UIKit.label("Daily Run · %s" % Worlds.MODIFIERS[mod]["name"], Style.SIZE_SMALL + 1, Style.INK, 600, HORIZONTAL_ALIGNMENT_LEFT))
	_daily_status = UIKit.label("", Style.SIZE_CAPTION - 1, Style.MUTED, 500, HORIZONTAL_ALIGNMENT_LEFT)
	_daily_status.name = "DailyStatus"
	_daily_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mid.add_child(_daily_status)
	row.add_child(mid)
	row.add_child(UIKit.icon_rect("chevron-right", 28, Style.MUTED))
	return _daily_btn


func _update_daily() -> void:
	var today: String = Profile.today_key()
	if not Profile.daily_unlocked():
		_daily_status.text = "Clear your first stage to unlock"
		return
	var streak: int = Profile.current_streak()
	var streak_text: String = "%d-day streak" % streak if streak > 0 else "Start a streak"
	if Profile.daily_done(today):
		var now: Dictionary = Time.get_time_dict_from_system()
		var left: int = 86400 - (int(now["hour"]) * 3600 + int(now["minute"]) * 60 + int(now["second"]))
		_daily_status.text = "Done · best %d · new run in %dh %02dm" % [Profile.daily_best(today), left / 3600, (left % 3600) / 60]
	else:
		_daily_status.text = "%s · +%d coins" % [streak_text, Economy.daily_reward(streak + 1)]


func refresh() -> void:
	_update_daily()
