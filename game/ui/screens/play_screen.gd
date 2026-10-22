extends Screen
## A level: the arena under a slim HUD (Pause, score and combo, shields, and
## the task bar). Hold anywhere to grow the ring, let go to burst. Losing
## every shield offers one revive; the result card shows the stars and offers
## the next level.
##
## args: {"world": w, "level": k}.

var arena: ArenaView
var sim: RunSim
var spec: Dictionary = {}
var world_idx: int = 0
var level_idx: int = 0
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
	world_idx = int(args.get("world", 0))
	level_idx = int(args.get("level", 0))
	spec = Worlds.level_spec(world_idx, level_idx)
	AdManager.suppress_banner(true)
	arena = ArenaView.new()
	arena.name = "Arena"
	arena.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arena.set_world(world_idx)
	add_child(arena)
	move_child(arena, 0)
	arena.finished.connect(_on_finished)
	arena.sim_event.connect(_on_event)
	_build_hud()
	Profile.set_last_level(spec["id"])
	Audio.world_music(world_idx)
	if world_idx == 0 and level_idx == 0 and not Profile.seen("tutorial"):
		_start_tutorial()
	else:
		_start_run()
		if level_idx == 0 and world_idx > 0 and not Profile.seen("intro_" + str(Worlds.world(world_idx)["id"])):
			_show_new_shape.call_deferred()


func _exit_tree() -> void:
	# A new level replacing this one keeps the banner hidden.
	if app == null or app.screen == self or app.screen_name != "play":
		AdManager.suppress_banner(false)


func _build_hud() -> void:
	_hud = UIKit.vbox(10)
	_hud.name = "HUD"
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_hud)
	var top: HBoxContainer = UIKit.hbox(12, BoxContainer.ALIGNMENT_BEGIN)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.custom_minimum_size.y = 84
	_pause_btn = UIKit.icon_button("pause")
	_pause_btn.name = "Pause"
	_pause_btn.pressed.connect(pause)
	top.add_child(_pause_btn)
	var mid: VBoxContainer = UIKit.vbox(0)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(UIKit.caption(where_text(), Style.MUTED, 16))
	_score = UIKit.label("0", 40, Style.INK, 700)
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
	_combo = UIKit.label("", 24, Color("FFE98A") if Style.DARK else Color("A86A00"), 700)
	_combo.name = "Combo"
	_combo.custom_minimum_size.y = 32
	_hud.add_child(_combo)


## "Neon Shore · Level 12".
func where_text() -> String:
	return "%s · Level %d" % [Worlds.world(world_idx)["name"], level_idx + 1]


## The level's task in words, e.g. "Burst 12 shapes".
func task_text() -> String:
	return Worlds.goal_text(spec["goal"], str((spec["boss"] as Dictionary).get("name", "")))


func _fit() -> void:
	super._fit()
	if arena != null:
		var insets: Vector4 = App.safe_insets(self)
		arena.inset_top = insets.y + 200.0


func _start_run() -> void:
	sim = RunSim.new(spec)
	_finished = false
	arena.start(sim)
	_bars.sim = sim
	_bars.accent = accent()
	_refresh_lives()


func _start_tutorial() -> void:
	tutorial = Tutorial.new()
	tutorial.screen = self
	add_child(tutorial)
	var tspec: Dictionary = spec.duplicate()
	tspec["mode"] = "tutorial"
	sim = RunSim.new(tspec)
	arena.start(sim)
	_bars.sim = sim
	_bars.accent = accent()
	_bars.visible = false
	_refresh_lives()
	tutorial.begin(sim)
	tutorial.done.connect(func() -> void:
		Profile.mark_seen("tutorial")
		tutorial.queue_free()
		tutorial = null
		_bars.visible = true
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
	if str(ev["t"]) == "damage":
		_refresh_lives()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and (e as InputEventKey).keycode == KEY_SPACE and not e.is_echo():
		if e.pressed:
			arena.press()
		else:
			arena.lift()
		get_viewport().set_input_as_handled()


## Back pauses a level (and resumes from the pause card).
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


func _on_finished(won: bool) -> void:
	if tutorial != null:
		# Tutorial runs can't be lost: top the shields back up.
		sim.revive()
		arena._over = false
		return
	if not won and sim.revives == 0:
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
	var result: Dictionary = Profile.finish_level(spec["id"], sim)
	await get_tree().create_timer(1.1 if won else 0.6).timeout
	if not is_inside_tree():
		return
	AdManager.suppress_banner(false)
	var card: ResultCard = ResultCard.new()
	card.play = self
	card.result = result
	app.open(card)


func restart() -> void:
	app.go("play", args)


## The next level (or the world's levels if it isn't open yet).
func go_next() -> void:
	var w: int = world_idx
	var k: int = level_idx + 1
	if k >= Worlds.LEVELS_PER_WORLD:
		w += 1
		k = 0
	if w >= Worlds.count() or not Profile.level_unlocked(w, k):
		app.go("levels", {"world": world_idx})
		return
	app.go("play", {"world": w, "level": k})


func share_info() -> Dictionary:
	return {
		"id": spec.get("id", ""), "won": sim.state == RunSim.State.WON, "where": where_text(), "task": task_text(),
		"world": world_idx, "level": level_idx, "score": sim.score, "combo": sim.best_combo, "kills": sim.kills,
		"perfects": sim.perfects, "stars": sim.stars(), "time": sim.t,
		"time_text": "%d:%02d" % [int(sim.t) / 60, int(sim.t) % 60],
	}
