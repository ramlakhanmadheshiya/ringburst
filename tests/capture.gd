extends Node
## Screenshots of every screen and card at a given window size, for visual
## review (and, with "store", the Play Store screenshots). Runs the real app
## with a throwaway save and the mock ad banner. Needs a display (not
## --headless):
##
##   godot --path . res://tests/capture.tscn -- <out_dir> [width] [height] [clean|store]
##
## "clean" hides the test ad banner; "store" also writes only the store set.

const SAVE: String = "user://capture_save.json"

var out_dir: String = "/tmp/ringburst_shots"
var app: App
var store: bool = false
var _n: int = 0


func _ready() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() >= 1:
		out_dir = a[0]
	var win: Vector2i = Vector2i(450, 800)
	if a.size() >= 3:
		win = Vector2i(int(a[1]), int(a[2]))
	DisplayServer.window_set_size(win)
	DirAccess.make_dir_recursive_absolute(out_dir)
	for s: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + s))
	Save.path = SAVE
	Save.load_data()
	Profile.set_setting("music_volume", 0.0)
	Profile.set_setting("sound_volume", 0.0)
	Profile.set_setting("haptics", false)
	Store.simulate = true
	Profile.set_setting("appearance", "dark")
	if a.size() >= 4 and (a[3] == "clean" or a[3] == "store"):
		AdManager.use_provider(null)
	store = a.size() >= 4 and a[3] == "store"
	App.skip_splash = true
	_seed_progress()
	app = (load("res://game/scenes/main.tscn") as PackedScene).instantiate()
	add_child(app)
	await _wait(1.6)
	if store:
		await _store_set()
	else:
		await _review_set()
	for s: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + s))
	print("CAPTURE: %d screenshots in %s" % [_n, out_dir])
	get_tree().quit()


func _review_set() -> void:
	await _shot("home")
	app.go("worlds")
	await _wait(0.9)
	await _shot("worlds")
	app.go("stages", {"world": 3})
	await _wait(0.9)
	await _shot("stages")
	app.open(StageCard.make(3, 4))
	await _wait(0.7)
	await _shot("stage_card")
	app.close_overlays()
	await _wait(0.3)
	# A run in Fracture, mid-fight, with a charging ring.
	await _run_scene(3, 3, 24.0)
	await _shot("play")
	await _choice()
	await _shot("levelup")
	app.close_overlays()
	await _wait(0.2)
	var play: Node = app.screen
	play.pause()
	await _wait(0.6)
	await _shot("pause")
	app.close_overlays()
	await _wait(0.3)
	await _finish_run(true)
	await _shot("result")
	var result: Overlay = app.top_overlay()
	if result != null:
		result.open_child(result._share_card())
		await _wait(2.2)
		await _shot("share")
	app.close_overlays()
	await _wait(0.3)
	# Boss fight.
	await _run_scene(5, 5, 104.0)
	await _shot("boss")
	app.screen.arena.paused = true
	var revive: ReviveCard = ReviveCard.new()
	revive.play = app.screen
	app.open(revive)
	await _wait(0.6)
	await _shot("revive")
	app.close_overlays()
	await _wait(0.3)
	app.go("forge")
	await _wait(0.9)
	await _shot("forge")
	app.go("forge", {"tab": 1})
	await _wait(0.9)
	await _shot("forge_rings")
	app.go("forge", {"tab": 2})
	await _wait(0.9)
	await _shot("forge_perks")
	app.go("shop")
	await _wait(1.0)
	await _shot("shop")
	for o: Overlay in [_product("complete_pack"), _product("style_pack"), CoinsCard.new(), TipCard.new(), _picker("themes"), _picker("styles"), SettingsCard.new(), AchievementsCard.new(), AboutCard.new(), CreditsCard.new(), DailyCard.new(), HowToCard.new(), _new_shape(4)]:
		app.open(o)
		await _wait(0.9)
		await _shot(o.name.to_lower() + ("_" + str(o.get("mode")) if o is PickerCard else ("_" + str(o.get("product")) if o is ProductCard else "")))
		o.close()
		await _wait(0.35)
	# The first-play tutorial.
	Save.data["seen"].erase("tutorial")
	app.go("play", {"world": 0, "stage": 0})
	await _wait(2.5)
	await _shot("tutorial")
	app.screen.arena.press()
	await _wait(0.6)
	await _shot("tutorial_hold")
	app.screen.arena.lift()
	await _wait(0.3)
	Profile.mark_seen("tutorial")
	# Bought themes and ring styles.
	Save.data["owned"]["theme_pack"] = true
	Save.data["owned"]["style_pack"] = true
	Profile.set_setting("theme", "synthwave")
	Profile.set_setting("ring_style", "prism")
	await _run_scene(1, 2, 20.0)
	await _shot("play_themed")
	app.go("home")
	await _wait(1.0)
	await _shot("home_themed")
	Profile.set_setting("theme", "worlds")
	Profile.set_setting("ring_style", "classic")
	Profile.set_setting("appearance", "light")
	app.go("home")
	await _wait(1.0)
	await _shot("home_light")
	await _run_scene(2, 2, 20.0)
	await _shot("play_light")
	app.go("worlds")
	await _wait(1.0)
	await _shot("worlds_light")


## The Play Store set (1080 x 1920 when the window is 1080 x 1920 or scaled).
func _store_set() -> void:
	await _wait(1.0)
	await _shot("01_home")
	await _run_scene(0, 3, 40.0)
	await _shot("02_shore")
	await _run_scene(3, 3, 50.0, "perfect")
	await _shot("03_fracture")
	await _run_scene(5, 5, 104.0, "perfect")
	await _shot("04_boss")
	await _run_scene(4, 2, 30.0)
	await _choice()
	await _shot("05_upgrades")
	app.close_overlays()
	await _finish_run(true)
	await _shot("06_result")
	app.close_overlays()
	app.go("worlds")
	await _wait(1.0)
	await _shot("07_worlds")
	app.go("forge")
	await _wait(1.0)
	await _shot("08_forge")


## Opens a stage and lets the bot play it for `seconds` of game time, then
## freezes it with the ring charging (or just after a PERFECT burst).
func _run_scene(w: int, k: int, seconds: float, moment: String = "charge") -> void:
	app.close_overlays()
	app.go("play", {"world": w, "stage": k})
	await _wait(0.8)
	app.close_overlays()
	var play: Node = app.screen
	var sim: RunSim = play.sim
	var bot: Bot = Bot.new("perfect", 5)
	play.arena.paused = true
	while sim.t < seconds and not sim.is_over():
		bot.act(sim)
		if sim.state == RunSim.State.CHOOSING:
			sim.choose(bot.pick(sim))
		sim.step()
	play.arena.paused = false
	# Let the arena play live for a moment so effects are on screen.
	var live: float = 0.0
	while live < 1.2:
		bot.act(sim)
		if sim.state == RunSim.State.CHOOSING:
			sim.choose(bot.pick(sim))
		await get_tree().process_frame
		live += get_process_delta_time()
	if moment == "perfect":
		var got: Array = [false]
		var cb: Callable = func(ev: Dictionary) -> void:
			if ev["t"] == "perfect" and int(ev["combo"]) >= 3:
				got[0] = true
		play.arena.sim_event.connect(cb)
		var guard: int = 0
		while not got[0] and guard < 900 and not sim.is_over():
			bot.act(sim)
			if sim.state == RunSim.State.CHOOSING:
				sim.choose(bot.pick(sim))
			await get_tree().process_frame
			guard += 1
		play.arena.sim_event.disconnect(cb)
		await _wait(0.22)
		play.arena.paused = true
		await _wait(0.1)
		app.close_overlays()
		return
	# Hold the ring partway grown.
	sim.cancel_charge()
	sim.input_down()
	var target: float = minf(sim.stats.max_r * 0.75, 260.0)
	var frames: int = 0
	while sim.ring_r < target and not sim.is_over() and frames < 600:
		# A level-up pauses the ring; take the bot's pick and hold again.
		if sim.state == RunSim.State.CHOOSING:
			sim.choose(bot.pick(sim))
			sim.input_down()
		await get_tree().process_frame
		frames += 1
	play.arena.paused = true
	await _wait(0.1)
	app.close_overlays()


func _choice() -> void:
	var play: Node = app.screen
	var sim: RunSim = play.sim
	sim.cancel_charge()
	sim.pending_levels += 1
	sim.state = RunSim.State.CHOOSING
	sim.offers = Upgrades.offer(sim.offer_rng, sim.stats.levels, 3)
	play._on_choosing()
	await _wait(0.9)


func _finish_run(win: bool) -> void:
	var play: Node = app.screen
	var sim: RunSim = play.sim
	var bot: Bot = Bot.new("perfect", 9)
	sim.cancel_charge()
	play.arena.paused = true
	if win:
		while not sim.is_over() and sim.t < 600.0:
			bot.act(sim)
			if sim.state == RunSim.State.CHOOSING:
				sim.choose(bot.pick(sim))
			sim.step()
	play.arena.paused = false
	await _wait(3.0)


func _product(id: String) -> ProductCard:
	var o: ProductCard = ProductCard.new()
	o.product = id
	return o


func _picker(mode: String) -> PickerCard:
	var o: PickerCard = PickerCard.new()
	o.mode = mode
	return o


func _new_shape(t: int) -> NewShapeCard:
	var o: NewShapeCard = NewShapeCard.new()
	o.type = t
	return o


## A believable mid-game save: three worlds done with mixed stars, the fourth
## part way, some Forge levels, rings and perks, coins.
func _seed_progress() -> void:
	for w: int in 4:
		var upto: int = 6 if w < 3 else 3
		for k: int in upto:
			Save.data["cleared"][Worlds.stage_id(w, k)] = {"stars": 7 if (w + k) % 3 != 0 else (3 if k % 2 == 0 else 5), "best": 8000 + 2500 * w + 700 * k}
	Save.data["coins"] = 1840
	Save.data["forge"] = {"power": 2, "charge": 1, "reach": 2, "eye": 1}
	Save.data["rings"] = {"classic": true, "twin": true, "glacier": true}
	Save.data["perks"] = {"heavy_wave": true, "echo": true}
	Save.data["perk"] = "heavy_wave"
	Save.data["stats"]["stages"] = 21
	Save.data["stats"]["stars"] = Profile.total_stars()
	Save.data["stats"]["perfects"] = 940
	Save.data["stats"]["best_combo"] = 46
	Save.data["stats"]["kills"] = 6400
	Save.data["daily"]["streak"] = 3
	Save.data["daily"]["last_date"] = Worlds.date_key_from_day(Worlds.day_number(Profile.today_key()) - 1)
	Save.data["seen"] = {"tutorial": true, "intro_pulse": true, "intro_bloom": true, "intro_fracture": true, "intro_orbit": true, "intro_hive": true}
	Profile.check_achievements()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	if DisplayServer.window_can_draw():
		await RenderingServer.frame_post_draw
	else:
		# A hidden window (screen locked or covered) skips drawing; draw anyway.
		RenderingServer.force_draw(false)
	var img: Image = get_viewport().get_texture().get_image()
	_n += 1
	if store:
		if img.get_size() != Vector2i(1080, 1920):
			img.resize(1080, 1920, Image.INTERPOLATE_LANCZOS)
		img.convert(Image.FORMAT_RGB8)
		img.save_png("%s/%s.png" % [out_dir, name])
	else:
		img.save_png("%s/%02d_%s.png" % [out_dir, _n, name])
