extends Screen
## A run: the arena under a slim HUD (Pause, score and combo, shields, the
## stage/boss bar and XP). Hold anywhere to grow the ring, let go to burst.
## Level-ups pause for an upgrade choice; losing every shield offers one
## revive; the result card pays out and offers Next, Again, Share.
##
## args: {"world": w, "stage": k} for the campaign, {"mode": "endless"}, or
## {"mode": "daily", "date": "YYYY-MM-DD"}.

var arena: ArenaView
var sim: RunSim
var spec: Dictionary = {}
var mode: String = "stage"
var world_idx: int = 0
var stage_idx: int = 0
var date_key: String = ""
var tutorial: Tutorial
var _score: Label
var _combo: Label
var _lives: HBoxContainer
var _bars: HudBars
var _hud: VBoxContainer
var _finished: bool = false
var _pause_btn: Button
var _shown_score: float = 0.0


func world_index() -> int:
	return world_idx


func in_game() -> bool:
	return true


func build() -> void:
	mode = str(args.get("mode", "stage"))
	date_key = str(args.get("date", Profile.today_key()))
	if mode == "stage":
		world_idx = int(args.get("world", 0))
		stage_idx = int(args.get("stage", 0))
		spec = Worlds.stage_spec(world_idx, stage_idx)
	elif mode == "daily":
		spec = Worlds.daily_spec(date_key)
		world_idx = int(spec["world"])
	else:
		spec = Worlds.endless_spec(int(Time.get_unix_time_from_system()) % 100000 + 1)
		world_idx = posmod(Profile.unlocked_world_count() - 1, Worlds.count())
	AdManager.suppress_banner(true)
	arena = ArenaView.new()
	arena.name = "Arena"
	arena.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arena.set_world(world_idx)
	add_child(arena)
	move_child(arena, 0)
	arena.choosing.connect(_on_choosing)
	arena.finished.connect(_on_finished)
	arena.sim_event.connect(_on_event)
	_build_hud()
	if mode == "stage":
		Profile.set_last_stage(spec["id"])
	var w: int = world_idx
	Audio.world_music(w)
	if mode == "stage" and world_idx == 0 and stage_idx == 0 and not Profile.seen("tutorial"):
		_start_tutorial()
	else:
		_start_run()
		if mode == "stage" and stage_idx == 0 and world_idx > 0 and not Profile.seen("intro_" + str(Worlds.world(world_idx)["id"])):
			_show_new_shape.call_deferred()


func _exit_tree() -> void:
	# A new run replacing this one keeps the banner hidden.
	if app == null or app.screen == self or app.screen_name != "play":
		AdManager.suppress_banner(false)


func _build_hud() -> void:
	_hud = UIKit.vbox(6)
	_hud.name = "HUD"
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_hud)
	var top: HBoxContainer = UIKit.hbox(12, BoxContainer.ALIGNMENT_BEGIN)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.custom_minimum_size.y = 92
	_pause_btn = UIKit.icon_button("pause", Style.TOP_BUTTON)
	_pause_btn.name = "Pause"
	_pause_btn.pressed.connect(pause)
	top.add_child(_pause_btn)
	var mid: VBoxContainer = UIKit.vbox(0)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(UIKit.caption(_where_text(), accent(), 17))
	_score = UIKit.label("0", 46, Style.INK, 800)
	_score.name = "Score"
	mid.add_child(_score)
	top.add_child(mid)
	_lives = UIKit.hbox(4, BoxContainer.ALIGNMENT_END)
	_lives.name = "Lives"
	_lives.custom_minimum_size.x = Style.TOP_BUTTON
	_lives.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_lives)
	_hud.add_child(top)
	_bars = HudBars.new()
	_bars.name = "Bars"
	_hud.add_child(_bars)
	_combo = UIKit.label("", 26, Color("FFE98A") if Style.DARK else Color("A86A00"), 800)
	_combo.name = "Combo"
	_combo.custom_minimum_size.y = 34
	_hud.add_child(_combo)


func _where_text() -> String:
	match mode:
		"daily":
			return "Daily run · " + date_key
		"endless":
			return "Endless"
	return "%s · Stage %d" % [Worlds.world(world_idx)["name"], stage_idx + 1]


func _fit() -> void:
	super._fit()
	if arena != null:
		var insets: Vector4 = App.safe_insets(self)
		arena.inset_top = insets.y + 200.0


func _start_run() -> void:
	sim = RunSim.new(spec, Profile.run_stats())
	_finished = false
	arena.start(sim)
	_bars.sim = sim
	_bars.accent = accent()
	_bars.gem = arena.pal["gem"]
	_refresh_lives()


func _start_tutorial() -> void:
	tutorial = Tutorial.new()
	tutorial.screen = self
	add_child(tutorial)
	var tspec: Dictionary = spec.duplicate()
	tspec["mode"] = "tutorial"
	var stats: RunStats = RunStats.make()
	stats.max_lives = 3
	sim = RunSim.new(tspec, stats)
	arena.start(sim)
	_bars.sim = sim
	_bars.accent = accent()
	_bars.gem = arena.pal["gem"]
	_refresh_lives()
	tutorial.begin(sim)
	tutorial.done.connect(func() -> void:
		Profile.mark_seen("tutorial")
		tutorial.queue_free()
		tutorial = null
		_start_run()
	)


func _show_new_shape() -> void:
	Profile.mark_seen("intro_" + str(Worlds.world(world_idx)["id"]))
	arena.paused = true
	var o: NewShapeCard = NewShapeCard.new()
	o.type = world_idx
	o.closed.connect(func() -> void: arena.paused = false)
	app.open(o)


func _process(_delta: float) -> void:
	if sim == null:
		return
	_shown_score = lerpf(_shown_score, float(sim.score), 0.25)
	if absf(_shown_score - sim.score) < 1.0:
		_shown_score = sim.score
	_score.text = _thousands(int(_shown_score))
	if sim.combo >= 2:
		_combo.text = "COMBO %d  ·  x%.1f" % [sim.combo, sim.multiplier()]
	else:
		_combo.text = ""
	if _lives.get_child_count() != sim.stats.max_lives or _lives.get_meta("lives", -1) != sim.lives:
		_refresh_lives()


static func _thousands(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func _refresh_lives() -> void:
	for c: Node in _lives.get_children():
		c.queue_free()
	for i: int in sim.stats.max_lives:
		var ic: TextureRect = UIKit.art_rect("shield", 34)
		ic.modulate = Color.WHITE if i < sim.lives else Color(1, 1, 1, 0.2)
		_lives.add_child(ic)
	_lives.set_meta("lives", sim.lives)


func _on_event(ev: Dictionary) -> void:
	match str(ev["t"]):
		"damage":
			_refresh_lives()
		"won", "lost":
			pass


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and (e as InputEventKey).keycode == KEY_SPACE and not e.is_echo():
		if e.pressed:
			arena.press()
		else:
			arena.lift()
		get_viewport().set_input_as_handled()


## Back pauses a run (and resumes from the pause card).
func on_back() -> bool:
	if _finished:
		return false
	pause()
	return true


func pause() -> void:
	if _finished or arena.paused or sim == null:
		return
	arena.paused = true
	sim.cancel_charge()
	var o: PauseCard = PauseCard.new()
	o.play = self
	o.closed.connect(func() -> void:
		if is_instance_valid(self) and not _finished and app.top_overlay() == null:
			arena.paused = false
	)
	app.open(o)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not _finished and sim != null and sim.state == RunSim.State.RUNNING and tutorial == null:
			pause()


func _on_choosing() -> void:
	if tutorial != null:
		sim.choose(0)
		return
	arena.paused = true
	var o: UpgradeCard = UpgradeCard.new()
	o.play = self
	o.closed.connect(func() -> void:
		if is_instance_valid(self) and not _finished:
			arena.paused = false
			if sim.state == RunSim.State.CHOOSING:
				_on_choosing.call_deferred()
	)
	app.open(o)


func _on_finished(won: bool) -> void:
	if tutorial != null:
		# Tutorial runs can't be lost: top the shields back up.
		sim.revive()
		arena._over = false
		return
	if not won and sim.revives == 0 and mode != "tutorial":
		arena.paused = true
		var r: ReviveCard = ReviveCard.new()
		r.play = self
		await get_tree().create_timer(0.7).timeout
		if is_inside_tree():
			app.open(r)
		return
	_finish(won)


## Called by the revive card.
func revive() -> void:
	sim.revive()
	arena._over = false
	arena.paused = false
	_refresh_lives()


func _finish(won: bool) -> void:
	if _finished:
		return
	_finished = true
	arena.paused = false
	var reward: Dictionary
	match mode:
		"daily":
			reward = Profile.finish_daily(date_key, sim)
		"endless":
			reward = Profile.finish_endless(sim)
		_:
			reward = Profile.finish_stage(spec["id"], sim)
	await get_tree().create_timer(1.1 if won else 0.6).timeout
	if not is_inside_tree():
		return
	AdManager.suppress_banner(false)
	var card: ResultCard = ResultCard.new()
	card.play = self
	card.reward = reward
	app.open(card)


func restart() -> void:
	app.go("play", args)


## Next stage (or Home after a daily / endless run, or the worlds list at the end).
func go_next() -> void:
	if mode != "stage":
		app.go("home")
		return
	var w: int = world_idx
	var k: int = stage_idx + 1
	if k >= Worlds.STAGES_PER_WORLD:
		w += 1
		k = 0
	if w >= Worlds.count() or not Profile.stage_unlocked(w, k):
		app.go("stages", {"world": world_idx})
		return
	app.go("play", {"world": w, "stage": k})


func share_info() -> Dictionary:
	var stars: int = Economy.star_count(sim.stars_mask())
	return {
		"mode": mode, "id": spec.get("id", ""), "date": date_key, "won": sim.state == RunSim.State.WON,
		"where": _where_text(), "world": world_idx, "score": sim.score, "combo": sim.best_combo, "kills": sim.kills,
		"perfects": sim.perfects, "stars": stars, "mask": sim.stars_mask(), "time": sim.t,
		"time_text": "%d:%02d" % [int(sim.t) / 60, int(sim.t) % 60], "upgrades": sim.stats.levels.duplicate(),
		"modifier": str(spec.get("modifier", "")), "ring": Profile.ring(),
	}
