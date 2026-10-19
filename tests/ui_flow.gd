extends Node
## End-to-end flow through the real app with a throwaway save, the simulated
## store and the mock ad provider: home, locked modes, worlds and stages, the
## stage card, the hands-on tutorial, a real run (HUD, level-up choice, pause,
## win, stars and coins, double-coins video), a lost run with a revive, the
## result card's buttons, the shop (coins, Supporter removes the banner), the
## Forge, settings, the Daily Run, Endless, sharing, Back, and an app restart.
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
	await _first_run()
	await _lost_run()
	await _shop()
	await _forge()
	await _settings()
	await _daily()
	await _endless()
	await _restart_app()
	_wipe()
	get_tree().quit(t.report())


func _wipe() -> void:
	for s: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + s))


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


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
	for n: String in ["Play", "Shop", "SettingsButton", "Worlds", "Forge", "Endless", "Awards", "Daily", "Coins", "Demo"]:
		t.ok(_find(app.screen, n) != null, "home has %s" % n)
	t.eq((_find(app.screen, "NextStage") as Label).text, "Neon Shore · Stage 1", "home shows where Play continues")
	var demo: ArenaView = app.screen._demo
	await _wait(0.5)
	t.ok(demo.sim.ticks > 10, "the home demo arena is playing")
	_press(app.screen, "Endless")
	await _wait(0.4)
	t.eq(app.screen_name, "home", "Endless is locked at first")
	_press(app.screen, "Daily")
	await _wait(0.4)
	t.ok(app.top_overlay() == null, "the Daily is locked at first")
	_press(app.screen, "Awards")
	await _wait(0.4)
	t.ok(app.top_overlay() is AchievementsCard, "Awards opens")
	app.handle_back()
	await _wait(0.4)
	t.ok(app.top_overlay() == null, "Back closes a card")


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
	t.eq(app.screen_name, "stages", "an open world shows its stages")
	var rows: Node = _find(app.screen, "List")
	var n: int = 0
	for c: Node in rows.get_children():
		if c is StageRow:
			n += 1
	t.eq(n, 6, "six stages")
	_press(rows, "Stage2")
	await _wait(0.4)
	t.ok(app.top_overlay() == null, "a locked stage does not open")
	_press(rows, "Stage1")
	await _wait(0.5)
	t.ok(app.top_overlay() is StageCard, "an open stage shows its card")
	t.ok(_find(app.top_overlay(), "Goals") != null, "the stage card lists its star goals")
	_press(app.top_overlay(), "PlayStage")
	await _wait(0.8)
	t.eq(app.screen_name, "play", "Play starts the run")


func _tutorial() -> void:
	var play: Node = app.screen
	t.ok(play.tutorial != null, "the first run starts with the tutorial")
	t.eq(AdManager.banner_height, 0.0, "no banner during a run")
	var tut: Tutorial = play.tutorial
	var cap: Label = _find(tut, "TutorialText") as Label
	t.ok(cap.text.begins_with("Hold anywhere"), "the tutorial says to hold")
	# Wait for the shape to arrive, then hold to it and let go.
	await _wait(5.5)
	play.arena.press()
	await _wait(0.2)
	t.eq(tut.step, Tutorial.Step.AIM, "holding moves the tutorial on")
	var guard: int = 0
	while play.sim.ring_r < 222.0 and guard < 300:
		await get_tree().process_frame
		guard += 1
	play.arena.lift()
	await _wait(2.4)
	t.eq(tut.step, Tutorial.Step.GROUP, "bursting the shape moves on to a group")
	for i: int in 12:
		if play.tutorial == null:
			break
		await _burst_max(play)
	t.ok(play.tutorial == null, "the tutorial ends and the real stage starts")
	t.ok(Profile.seen("tutorial"), "the tutorial is remembered")
	t.eq(str(play.sim.spec["mode"]), "stage", "the real run is going")


## Holds to a full ring and lets go (enough to burst everything close).
func _burst_max(play: Node) -> void:
	play.arena.press()
	var guard: int = 0
	while (not play.sim.charging or play.sim.ring_r < play.sim.stats.max_r - 1.0) and guard < 200:
		await get_tree().process_frame
		guard += 1
	play.arena.lift()
	await _wait(0.9)


func _first_run() -> void:
	var play: Node = app.screen
	for n: String in ["Pause", "Score", "Lives", "Bars"]:
		t.ok(_find(play, n) != null, "the HUD has %s" % n)
	# Play with the bot until the first level-up.
	var sim: RunSim = play.sim
	var bot: Bot = Bot.new("perfect", 3)
	play.arena.paused = true
	while sim.state != RunSim.State.CHOOSING and not sim.is_over():
		bot.act(sim)
		sim.step()
	t.eq(sim.state, RunSim.State.CHOOSING, "collecting gems levels up")
	play._on_choosing()
	await _wait(0.5)
	var card: Overlay = app.top_overlay()
	t.ok(card is UpgradeCard, "the upgrade choice appears")
	var pick: String = sim.offers[0]
	_press(card, "Option1")
	await _wait(0.4)
	t.eq(sim.stats.level(pick), 1, "the chosen upgrade is taken")
	t.ok(not play.arena.paused, "the run resumes after choosing")
	_press(play, "Pause")
	await _wait(0.4)
	t.ok(app.top_overlay() is PauseCard and play.arena.paused, "Pause stops the run")
	_press(app.top_overlay(), "PauseSettings")
	await _wait(0.4)
	t.ok(_find(app.top_overlay(), "Reset") == null, "Reset progress is hidden during a run")
	app.top_overlay().close()
	await _wait(0.4)
	_press(app.top_overlay(), "Resume")
	await _wait(0.4)
	t.ok(not play.arena.paused, "Resume carries on")
	# Win it.
	play.arena.paused = true
	while not sim.is_over():
		bot.act(sim)
		if sim.state == RunSim.State.CHOOSING:
			sim.choose(0)
		sim.step()
	t.eq(sim.state, RunSim.State.WON, "the bot wins the first stage")
	var coins0: int = Profile.coins()
	play.arena.paused = false
	await _wait(2.0)
	var result: Overlay = app.top_overlay()
	t.ok(result is ResultCard, "the result card appears")
	t.eq((_find(result, "ResultTitle") as Label).text, "Stage clear!", "the win title")
	t.ok(Profile.is_cleared("shore-1"), "the stage is cleared")
	t.ok(Profile.coins() > coins0, "the run paid coins")
	t.ok(AdManager.banner_height > 0.0, "the banner is back on the result card")
	var c1: int = Profile.coins()
	_press(result, "Double")
	await _wait(0.4)
	t.ok(Profile.coins() > c1, "a video doubles the run's coins")
	t.ok((_find(result, "Double") as Button).disabled, "doubling is once")
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
	t.eq(app.screen_name, "play", "Next starts the next stage")
	t.eq(str(app.screen.spec["id"]), "shore-2", "it is stage 2")


func _lost_run() -> void:
	var play: Node = app.screen
	var sim: RunSim = play.sim
	await _wait(0.3)
	sim.invuln_t = 0.0
	sim.lives = 1
	sim.spawn_enemy(EnemyTypes.DRIFTER, Vector2(RunSim.CORE_R + 8.0, 0), 1.0, 1.0)
	await _wait(1.5)
	t.eq(sim.state, RunSim.State.LOST, "a shape on the last shield ends the run")
	var card: Overlay = app.top_overlay()
	t.ok(card is ReviveCard, "a revive is offered")
	_press(card, "ReviveVideo")
	await _wait(0.5)
	t.eq(sim.state, RunSim.State.RUNNING, "the video revives")
	t.eq(sim.lives, 2, "with two shields")
	sim.invuln_t = 0.0
	sim.lives = 1
	sim.spawn_enemy(EnemyTypes.DRIFTER, Vector2(RunSim.CORE_R + 8.0, 0), 1.0, 1.0)
	await _wait(1.8)
	card = app.top_overlay()
	t.ok(card is ResultCard, "a second loss goes straight to the result")
	t.eq((_find(card, "ResultTitle") as Label).text, "Run over", "the loss title")
	t.eq((_find(card, "Next") as Button).text, "Try again", "a loss offers Try again")
	_press(card, "Stages")
	await _wait(0.7)
	t.eq(app.screen_name, "stages", "Stages goes to the world's stages")
	app.handle_back()
	await _wait(0.6)
	t.eq(app.screen_name, "worlds", "Back goes to worlds")
	app.handle_back()
	await _wait(0.6)
	t.eq(app.screen_name, "home", "Back goes home")


func _shop() -> void:
	_press(app.screen, "Shop")
	await _wait(0.7)
	t.eq(app.screen_name, "shop", "the shop opens")
	for id: String in Store.PRODUCTS:
		t.ok(_find(app.screen, "Product_" + id) != null, "the shop lists %s" % id)
	_press(app.screen, "Product_coins")
	await _wait(0.5)
	var c0: int = Profile.coins()
	_press(app.top_overlay(), "Buy_coins_500")
	await _wait(0.2)
	t.eq(Profile.coins(), c0 + 500, "buying a coin bag (simulated)")
	_press(app.top_overlay(), "FreeCoins")
	await _wait(0.4)
	t.eq(Profile.coins(), c0 + 500 + Economy.VIDEO_COINS, "a free-coins video pays")
	app.top_overlay().close()
	await _wait(0.4)
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


func _forge() -> void:
	Profile.add_coins(3000)
	_press(app.screen, "Forge")
	await _wait(0.6)
	t.eq(app.screen_name, "forge", "the Forge opens")
	var c0: int = Profile.coins()
	_press(app.screen, "Buy_power")
	await _wait(0.4)
	t.eq(Profile.forge_level("power"), 1, "buying Core Power")
	t.ok(Profile.coins() < c0, "it costs coins")
	(_find(app.screen, "Tabs") as SegmentedSlider).select(1)
	await _wait(0.4)
	_press(app.screen, "BuyRing_twin")
	await _wait(0.4)
	t.ok(Profile.owns_ring("twin") and Profile.ring() == "twin", "buying and equipping a ring type")
	(_find(app.screen, "Tabs") as SegmentedSlider).select(2)
	await _wait(0.4)
	_press(app.screen, "BuyPerk_echo")
	await _wait(0.4)
	t.eq(Profile.perk(), "echo", "buying a perk equips it")
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
	t.ok(_find(s, "Reset") != null, "Reset progress is offered outside a run")
	_press(s, "HowToPlay")
	await _wait(0.5)
	t.ok(app.top_overlay() is HowToCard, "How to play opens")
	app.top_overlay().close()
	await _wait(0.4)
	t.ok(app.top_overlay() is SettingsCard, "closing it returns to Settings")
	app.top_overlay().close()
	await _wait(0.4)
	Profile.set_setting("music_volume", 0.0)


func _daily() -> void:
	_press(app.screen, "Daily")
	await _wait(0.5)
	t.ok(app.top_overlay() is DailyCard, "the Daily card opens once a stage is cleared")
	_press(app.top_overlay(), "PlayDaily")
	await _wait(0.8)
	t.eq(app.screen_name, "play", "the Daily Run starts")
	var play: Node = app.screen
	t.eq(play.mode, "daily", "in daily mode")
	var sim: RunSim = play.sim
	var bot: Bot = Bot.new("perfect", 4)
	play.arena.paused = true
	while not sim.is_over():
		bot.act(sim)
		if sim.state == RunSim.State.CHOOSING:
			sim.choose(0)
		sim.step()
	play.arena.paused = false
	await _wait(2.2)
	var card: Overlay = app.top_overlay()
	if card is ReviveCard:
		_press(card, "EndRun")
		await _wait(1.0)
		card = app.top_overlay()
	t.ok(card is ResultCard, "the daily result appears")
	t.ok(Profile.daily_done(Profile.today_key()), "today's daily is done")
	t.eq(Profile.current_streak(), 1, "a streak starts")
	_press(card, "Home")
	await _wait(0.7)
	t.eq(app.screen_name, "home", "Home from the result")


func _endless() -> void:
	Save.data["cleared"]["shore-3"] = {"stars": 1, "best": 100}
	app.reload_screen()
	await _wait(0.7)
	_press(app.screen, "Endless")
	await _wait(0.8)
	t.eq(app.screen_name, "play", "Endless opens once Neon Shore 3 is cleared")
	var play: Node = app.screen
	t.eq(play.mode, "endless", "in endless mode")
	await _wait(0.5)
	var sim: RunSim = play.sim
	sim.invuln_t = 0.0
	sim.lives = 1
	sim.spawn_enemy(EnemyTypes.DRIFTER, Vector2(RunSim.CORE_R + 8.0, 0), 1.0, 1.0)
	await _wait(1.6)
	var card: Overlay = app.top_overlay()
	t.ok(card is ReviveCard, "Endless offers a revive too")
	_press(card, "EndRun")
	await _wait(1.0)
	t.ok(app.top_overlay() is ResultCard, "then the result")
	t.ok(Profile.endless_best() > 0 or sim.score == 0, "the Endless best is recorded")
	app.close_overlays()
	app.go("home")
	await _wait(0.7)


func _restart_app() -> void:
	Save.flush()
	var coins: int = Profile.coins()
	app.queue_free()
	await _wait(0.3)
	Save.data = {}
	Save.load_data()
	app = (load("res://game/scenes/main.tscn") as PackedScene).instantiate()
	add_child(app)
	await _wait(1.0)
	t.eq(app.screen_name, "home", "the app starts again")
	t.eq(Profile.coins(), coins, "coins survive a restart")
	t.ok(Profile.is_cleared("shore-1") and Profile.forge_level("power") == 1, "progress survives a restart")
