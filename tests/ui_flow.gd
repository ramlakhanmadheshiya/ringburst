extends Node
## End-to-end flow through the real app with a throwaway save, the simulated
## store and the mock ad provider: home, worlds and the level grid, the level
## card and its task, the hands-on tutorial, a real level (HUD and task bar,
## pause, win, stars, sharing), the next level, a lost level with a revive,
## the result card's buttons, a Giant level, the shop (Supporter removes the
## banner), awards, how to play, settings, Back, and an app restart.
##
##   godot --headless --path . res://tests/ui_flow.tscn

const SAVE: String = "user://ui_flow_save.json"
const MockProvider: GDScript = preload("res://game/ads/providers/mock_ad_provider.gd")

var t: Check = Check.new("UI FLOW")
var app: App
var mock: Node


func _ready() -> void:
	_wipe()
	Save.path = SAVE
	Save.load_data()
	Profile.set_setting("music_volume", 0.0)
	Profile.set_setting("sound_volume", 0.0)
	Store.simulate = true
	mock = MockProvider.new()
	mock.auto_finish = true
	AdManager.use_provider(mock)
	App.skip_splash = true
	await _boot()
	await _home()
	await _menus()
	await _tutorial()
	await _first_level()
	await _lost_level()
	await _giant()
	await _shop()
	await _settings()
	await _restart_app()
	_wipe()
	get_tree().quit(t.report())


func _wipe() -> void:
	for s: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + s))


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


## Waits until `cond` is true (polling every frame), up to `limit` seconds, so
## slow machines (CI) don't fail on fixed delays.
func _until(cond: Callable, limit: float = 10.0) -> void:
	var t0: int = Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(limit * 1000.0):
		await get_tree().process_frame


func _find(root: Node, n: String) -> Node:
	return root.find_child(n, true, false) if root != null else null


func _press(root: Node, n: String) -> bool:
	var b: BaseButton = _find(root, n) as BaseButton
	if b == null:
		t.ok(false, "button %s exists" % n)
		return false
	if b.disabled:
		t.ok(false, "button %s is enabled" % n)
		return false
	b.pressed.emit()
	return true


func _boot() -> void:
	app = (load("res://game/scenes/main.tscn") as PackedScene).instantiate()
	add_child(app)
	await _wait(1.0)
	t.eq(app.screen_name, "home", "boots to the home screen")


func _home() -> void:
	t.ok(AdManager.banner_height > 0.0, "the banner is showing")
	var frame: MarginContainer = app.screen.get_child(0) as MarginContainer
	t.ok(frame.get_theme_constant("margin_bottom") >= int(AdManager.banner_height), "screens keep room for the banner")
	for n: String in ["Play", "Shop", "SettingsButton", "Worlds", "Awards", "HowToPlay", "Demo", "Stars"]:
		t.ok(_find(app.screen, n) != null, "home has %s" % n)
	for n: String in ["Forge", "Endless", "Daily", "Coins"]:
		t.ok(_find(app.screen, n) == null, "home has no %s" % n)
	t.eq((_find(app.screen, "NextLevel") as Label).text, "Neon Shore · Level 1", "home shows which level Play opens")
	var demo: ArenaView = app.screen._demo
	await _wait(0.5)
	t.ok(demo.sim.ticks > 10, "the home demo arena is playing")
	_press(app.screen, "Awards")
	await _wait(0.4)
	t.ok(app.top_overlay() is AchievementsCard, "Awards opens")
	app.handle_back()
	await _wait(0.4)
	t.ok(app.top_overlay() == null, "Back closes a card")
	_press(app.screen, "HowToPlay")
	await _wait(0.4)
	var how: Overlay = app.top_overlay()
	t.ok(how is HowToCard, "How to play opens")
	for i: int in HowToCard.PAGES.size() - 1:
		_press(how, "Next")
		await _wait(0.1)
	t.eq((_find(how, "Next") as Button).text, "Got it", "How to play pages through to the end")
	_press(how, "Next")
	await _wait(0.4)
	t.ok(app.top_overlay() == null, "Got it closes it")
	_press(app.screen, "Play")
	await _wait(0.5)
	var card: Overlay = app.top_overlay()
	t.ok(card is LevelCard, "Play opens the next level's card")
	t.eq((_find(card, "TaskText") as Label).text, "Burst 8 shapes", "the card shows the task")
	app.handle_back()
	await _wait(0.4)


func _menus() -> void:
	_press(app.screen, "Worlds")
	await _wait(0.6)
	t.eq(app.screen_name, "worlds", "Worlds opens")
	var list: Node = _find(app.screen, "List")
	var cards: int = 0
	for c: Node in list.get_children():
		if c is WorldCard:
			cards += 1
	t.eq(cards, 8, "8 world cards")
	_press(list, "World_pulse")
	await _wait(0.5)
	t.eq(app.screen_name, "worlds", "a locked world does not open")
	_press(list, "World_shore")
	await _wait(0.6)
	t.eq(app.screen_name, "levels", "an open world shows its levels")
	var grid: Node = _find(app.screen, "Grid")
	var n: int = 0
	for c: Node in grid.get_children():
		if c is LevelTile:
			n += 1
	t.eq(n, 40, "forty levels")
	t.ok((_find(grid, "Level1") as LevelTile).current, "level 1 is marked as next")
	_press(grid, "Level2")
	await _wait(0.4)
	t.ok(app.top_overlay() == null, "a locked level does not open")
	_press(grid, "Level1")
	await _wait(0.5)
	t.ok(app.top_overlay() is LevelCard, "an open level shows its card")
	t.ok(_find(app.top_overlay(), "Task") != null, "the level card shows its task")
	_press(app.top_overlay(), "PlayLevel")
	await _wait(0.8)
	t.eq(app.screen_name, "play", "Play starts the level")


func _tutorial() -> void:
	var play: Node = app.screen
	t.ok(play.tutorial != null, "the first level starts with the tutorial")
	t.eq(AdManager.banner_height, 0.0, "no banner during a level")
	var tut: Tutorial = play.tutorial
	var cap: Label = _find(tut, "TutorialText") as Label
	t.ok(cap.text.begins_with("Hold anywhere"), "the tutorial says to hold")
	# Wait for the shape to arrive, then hold to it and let go.
	await _until(func() -> bool:
		for e: RunSim.Enemy in play.sim.enemies:
			if e.alive and e.pos.length() <= e.hold_r + 0.5:
				return true
		return false, 20.0)
	play.arena.press()
	await _wait(0.2)
	t.eq(tut.step, Tutorial.Step.AIM, "holding moves the tutorial on")
	var guard: int = 0
	while play.sim.ring_r < 222.0 and guard < 300:
		await get_tree().process_frame
		guard += 1
	play.arena.lift()
	await _until(func() -> bool: return tut.step == Tutorial.Step.GROUP, 6.0)
	t.eq(tut.step, Tutorial.Step.GROUP, "bursting the shape moves on to a group")
	for i: int in 12:
		if play.tutorial == null:
			break
		await _burst_max(play)
	t.ok(play.tutorial == null, "the tutorial ends and the real level starts")
	t.ok(Profile.seen("tutorial"), "the tutorial is remembered")
	t.eq(str(play.sim.spec["mode"]), "level", "the real level is going")


## Holds to a full ring and lets go (enough to burst everything close).
func _burst_max(play: Node) -> void:
	play.arena.press()
	var guard: int = 0
	while (not play.sim.charging or play.sim.ring_r < play.sim.stats.max_r - 1.0) and guard < 200:
		await get_tree().process_frame
		guard += 1
	play.arena.lift()
	await _wait(0.9)


func _first_level() -> void:
	var play: Node = app.screen
	for n: String in ["Pause", "Score", "Lives", "Bars"]:
		t.ok(_find(play, n) != null, "the HUD has %s" % n)
	t.ok((_find(play, "Bars") as Control).visible, "the task bar shows once the level starts")
	var sim: RunSim = play.sim
	t.eq(sim.goal_type(), "kills", "level 1 asks to burst shapes")
	_press(play, "Pause")
	await _wait(0.4)
	t.ok(app.top_overlay() is PauseCard and play.arena.paused, "Pause stops the level")
	_press(app.top_overlay(), "PauseSettings")
	await _wait(0.4)
	t.ok(_find(app.top_overlay(), "Reset") == null, "Reset progress is hidden during a level")
	app.top_overlay().close()
	await _wait(0.4)
	_press(app.top_overlay(), "Resume")
	await _wait(0.4)
	t.ok(not play.arena.paused, "Resume carries on")
	# Win it with the bot.
	var bot: Bot = Bot.new("perfect", 3)
	play.arena.paused = true
	while not sim.is_over():
		bot.act(sim)
		sim.step()
	t.eq(sim.state, RunSim.State.WON, "the bot wins level 1")
	play.arena.paused = false
	await _until(func() -> bool: return app.top_overlay() is ResultCard, 8.0)
	await _wait(0.4)
	var result: Overlay = app.top_overlay()
	t.ok(result is ResultCard, "the result card appears")
	t.eq((_find(result, "ResultTitle") as Label).text, "Level clear!", "the win title")
	t.ok(Profile.is_cleared("shore-1"), "the level is cleared")
	t.eq(Profile.level_stars("shore-1"), sim.stars(), "its stars are saved")
	t.ok(AdManager.banner_height > 0.0, "the banner is back on the result card")
	_press(result, "Share")
	await _wait(0.5)
	t.ok(app.top_overlay() is ShareCardOverlay, "Share opens the share card")
	_press(app.top_overlay(), "CopyLink")
	await _wait(0.2)
	t.ok(DisplayServer.get_name() == "headless" or DisplayServer.clipboard_get().contains("theramlakhan.com/ringburst"), "Copy link copies the message")
	app.top_overlay().close()
	await _wait(0.4)
	_press(app.top_overlay(), "Next")
	await _wait(0.9)
	t.eq(app.screen_name, "play", "Next starts the next level")
	t.eq(str(app.screen.spec["id"]), "shore-2", "it is level 2")


func _lost_level() -> void:
	var play: Node = app.screen
	var sim: RunSim = play.sim
	await _wait(0.3)
	sim.invuln_t = 0.0
	sim.lives = 1
	sim.spawn_enemy(EnemyTypes.DRIFTER, Vector2(RunSim.CORE_R + 8.0, 0), 1.0, 1.0)
	await _until(func() -> bool: return app.top_overlay() is ReviveCard, 8.0)
	t.eq(sim.state, RunSim.State.LOST, "a shape on the last shield loses the level")
	var card: Overlay = app.top_overlay()
	t.ok(card is ReviveCard, "a revive is offered")
	_press(card, "ReviveVideo")
	await _wait(0.5)
	t.eq(sim.state, RunSim.State.RUNNING, "the video revives")
	t.eq(sim.lives, 2, "with two shields")
	sim.invuln_t = 0.0
	sim.lives = 1
	sim.spawn_enemy(EnemyTypes.DRIFTER, Vector2(RunSim.CORE_R + 8.0, 0), 1.0, 1.0)
	await _until(func() -> bool: return app.top_overlay() is ResultCard, 8.0)
	await _wait(0.3)
	card = app.top_overlay()
	t.ok(card is ResultCard, "a second loss goes straight to the result")
	t.eq((_find(card, "ResultTitle") as Label).text, "Not this time", "the loss title")
	t.eq((_find(card, "Next") as Button).text, "Try again", "a loss offers Try again")
	t.ok(not Profile.is_cleared("shore-2"), "a lost level stays to do")
	_press(card, "Levels")
	await _wait(0.7)
	t.eq(app.screen_name, "levels", "Levels goes to the world's grid")
	app.handle_back()
	await _wait(0.6)
	t.eq(app.screen_name, "worlds", "Back goes to worlds")
	app.handle_back()
	await _wait(0.6)
	t.eq(app.screen_name, "home", "Back goes home")


## A Giant level: the task bar waits for it, then counts its health down.
func _giant() -> void:
	for k: int in range(1, 9):
		Save.data["cleared"][Worlds.level_id(0, k)] = {"stars": 2, "best": 100}
	app.go("play", {"world": 0, "level": 9})
	await _wait(0.8)
	var play: Node = app.screen
	var sim: RunSim = play.sim
	t.eq(sim.goal_type(), "guardian", "level 10 is a Giant")
	var bot: Bot = Bot.new("perfect", 2)
	play.arena.paused = true
	while not sim.boss_spawned and sim.t < 30.0:
		bot.act(sim)
		sim.step()
	t.ok(sim.boss_alive(), "the Giant arrives")
	while not sim.is_over() and sim.t < 200.0:
		bot.act(sim)
		sim.step()
	t.eq(sim.state, RunSim.State.WON, "beating it clears the level")
	play.arena.paused = false
	await _until(func() -> bool: return app.top_overlay() is ResultCard, 8.0)
	_press(app.top_overlay(), "Home")
	await _wait(0.7)
	t.eq(app.screen_name, "home", "Home from the result")
	t.eq((_find(app.screen, "NextLevel") as Label).text, "Neon Shore · Level 11", "Play moves on past the Giant")


func _shop() -> void:
	_press(app.screen, "Shop")
	await _wait(0.7)
	t.eq(app.screen_name, "shop", "the shop opens")
	for id: String in Store.PRODUCTS:
		t.ok(_find(app.screen, "Product_" + id) != null, "the shop lists %s" % id)
	t.ok(_find(app.screen, "Product_coins") == null, "no coin bags")
	_press(app.screen, "Product_style_pack")
	await _wait(0.5)
	_press(app.top_overlay(), "Trial")
	await _wait(0.8)
	t.ok(Profile.owns("style_pack"), "a video starts a pack trial")
	app.close_overlays()
	await _wait(0.3)
	_press(app.screen, "Product_supporter_pack")
	await _wait(0.5)
	_press(app.top_overlay(), "Buy")
	await _wait(0.4)
	t.ok(Profile.is_supporter(), "buying the Supporter pack")
	t.eq(AdManager.banner_height, 0.0, "Supporters see no banner")
	app.close_overlays()
	await _wait(0.3)
	_press(app.screen, "Restore")
	await _wait(0.2)
	t.ok((_find(app.screen, "Status") as Label).text.contains("Restored"), "Restore reports back")
	app.handle_back()
	await _wait(0.6)


func _settings() -> void:
	_press(app.screen, "SettingsButton")
	await _wait(0.5)
	var s: Overlay = app.top_overlay()
	t.ok(s is SettingsCard, "Settings opens")
	var music: HSlider = _find(s, "MusicSlider") as HSlider
	music.value = 0.3
	t.ok(absf(float(Profile.setting("music_volume")) - 0.3) < 0.01, "the music slider saves")
	var shake: CheckButton = _find(s, "Screenshake") as CheckButton
	t.ok(shake != null, "a screen shake switch")
	shake.button_pressed = false
	t.eq(Profile.setting("shake"), false, "screen shake can be turned off")
	shake.button_pressed = true
	t.ok(_find(s, "Reset") != null, "Reset progress is offered outside a level")
	_press(s, "HowToPlay")
	await _wait(0.5)
	t.ok(app.top_overlay() is HowToCard, "How to play opens")
	app.top_overlay().close()
	await _wait(0.4)
	t.ok(app.top_overlay() is SettingsCard, "closing it returns to Settings")
	app.top_overlay().close()
	await _wait(0.4)
	Profile.set_setting("music_volume", 0.0)


func _restart_app() -> void:
	Save.flush()
	var stars: int = Profile.total_stars()
	app.queue_free()
	await _wait(0.3)
	Save.data = {}
	Save.load_data()
	app = (load("res://game/scenes/main.tscn") as PackedScene).instantiate()
	add_child(app)
	await _wait(1.0)
	t.eq(app.screen_name, "home", "the app starts again")
	t.eq(Profile.total_stars(), stars, "stars survive a restart")
	t.ok(Profile.is_cleared("shore-10") and Profile.is_supporter(), "progress and purchases survive a restart")
