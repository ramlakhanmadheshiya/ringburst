class_name ResultCard
extends Overlay
## The end of a run: the stars and their three goals (campaign), the score
## and best combo, coins counting up with an optional "double with a video"
## (asked for, never automatic), notes for a new best, a finished world or a
## streak, then Next / Again / Share / Home, like Single Shot.

var play: Node
var reward: Dictionary = {}
var _doubled: bool = false
var _status: Label
var _amount: Label


func _init() -> void:
	super._init()
	dismissable = false


func build() -> void:
	name = "Result"
	body.add_theme_constant_override("separation", 10)
	var sim: RunSim = play.sim
	var won: bool = sim.state == RunSim.State.WON
	var mode: String = play.mode
	var acc: Color = play.accent()
	body.add_child(UIKit.caption(play._where_text(), acc))
	var title_text: String = "Stage clear!" if won else "Run over"
	if mode == "daily":
		title_text = "Daily run done" if won else "Daily run over"
	elif mode == "endless":
		title_text = "Lasted %s" % play.share_info()["time_text"]
	var title: Label = UIKit.label(title_text, Style.SIZE_H1 + 6, Style.INK, 700)
	title.name = "ResultTitle"
	body.add_child(title)
	if mode == "stage":
		var mask: int = sim.stars_mask()
		var row: StarRow = StarRow.new()
		row.name = "Stars"
		row.custom_minimum_size.y = 92
		body.add_child(row)
		row.play(mask)
		var goals: VBoxContainer = UIKit.vbox(6)
		goals.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		goals.add_child(_goal(mask & 1 != 0, "Clear the stage"))
		goals.add_child(_goal(mask & 2 != 0, "Take no hits"))
		goals.add_child(_goal(mask & 4 != 0, "Reach a %d combo (best %d)" % [int(play.spec["combo_target"]), sim.best_combo]))
		body.add_child(goals)
	var stats: HBoxContainer = UIKit.hbox(8)
	for s: Array in [["Score", play._thousands(sim.score)], ["Best combo", str(sim.best_combo)], ["Perfects", str(sim.perfects)], ["Shapes", str(sim.kills)]]:
		var col: VBoxContainer = UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v: Label = UIKit.label(str(s[1]), Style.SIZE_H2 - 4, Style.INK, 800)
		v.name = "Stat" + str(s[0]).replace(" ", "")
		col.add_child(v)
		col.add_child(UIKit.label(str(s[0]), Style.SIZE_CAPTION, Style.MUTED, 600))
		stats.add_child(col)
	body.add_child(UIKit.panel(stats, Style.FIELD, 26, Vector2(10, 12)))
	if bool(reward.get("new_best", false)) and sim.score > 0:
		body.add_child(_note("trophy", "New best score!" if mode != "stage" else "New best for this stage", Style.GOLD))
	elif mode != "stage":
		body.add_child(UIKit.label("Best: %s" % play._thousands(int(reward.get("best", 0))), Style.SIZE_SMALL, Style.MUTED, 600))
	var coins: int = int(reward.get("coins", 0))
	var coin_row: HBoxContainer = UIKit.hbox(12)
	coin_row.add_child(UIKit.art_rect("coin", 52))
	_amount = UIKit.label("+0", 40, Style.GOLD, 800)
	_amount.name = "Reward"
	coin_row.add_child(_amount)
	body.add_child(coin_row)
	var tw: Tween = create_tween()
	tw.tween_interval(0.9)
	tw.tween_method(func(v: float) -> void: _amount.text = "+%d" % int(v), 0.0, float(coins), 0.6)
	tw.tween_callback(func() -> void:
		if coins > 0:
			Audio.play("coin")
	)
	var run_coins: int = int(reward.get("run_coins", 0))
	if run_coins > 0:
		var dbl: Button = UIKit.button("Double %d coins · watch a video" % run_coins if not Profile.is_supporter() else "Double %d coins (Supporter)" % run_coins, "soft", Style.AMBER, 68, 21, "art:watch")
		dbl.name = "Double"
		dbl.pressed.connect(func() -> void:
			if _doubled:
				return
			if not AdManager.rewarded_ready():
				_say("No video available right now." if AdManager.provider != null else "Videos are available in the Android app.")
				return
			AdManager.show_rewarded(func(ok: bool) -> void:
				if not is_inside_tree():
					return
				if ok and not _doubled:
					_doubled = true
					Profile.add_coins(run_coins)
					_amount.text = "+%d" % (coins + run_coins)
					Audio.play("coin", 1.2)
					dbl.disabled = true
					dbl.text = "Doubled!"
				elif not ok:
					_say("The video was closed early, so no bonus this time.")
			)
		)
		body.add_child(dbl)
	_status = UIKit.para("", Style.SIZE_SMALL, Style.MUTED)
	_status.name = "Status"
	_status.visible = false
	body.add_child(_status)
	if int(reward.get("new_stars", 0)) > 0 and not bool(reward.get("first", false)):
		body.add_child(_note("star-filled", "%d new %s" % [int(reward["new_stars"]), "star" if int(reward["new_stars"]) == 1 else "stars"], Style.GOLD))
	if bool(reward.get("world_done", false)):
		body.add_child(_note("trophy", "World complete! +%d bonus coins" % Economy.WORLD_BONUS, Style.GOLD))
	if not str(reward.get("unlocked", "")).is_empty():
		var wk: Array[int] = Worlds.parse_stage_id(str(reward["unlocked"]))
		var txt: String = "New world open: %s" % Worlds.world(wk[0])["name"] if wk[1] == 0 else "Stage %d is open" % (wk[1] + 1)
		body.add_child(_note("lock", txt, Look.accent(wk[0])))
	if mode == "daily" and bool(reward.get("first", false)):
		body.add_child(_note("flame", "%d-day streak · a new Daily Run tomorrow" % int(reward.get("streak", 1)), Color("FF8A3D")))
	if not won and mode == "stage":
		body.add_child(UIKit.para(_tip(), Style.SIZE_CAPTION, Style.MUTED))
	body.add_child(UIKit.gap(4))
	var next_text: String = "Home"
	var next_icon: String = "house"
	if mode == "stage":
		next_text = "Next stage" if won else "Try again"
		next_icon = "arrow-right" if won else "rotate-ccw"
	elif mode == "endless":
		next_text = "Play again"
		next_icon = "rotate-ccw"
	var next: Button = UIKit.button(next_text, "primary", acc, 92, 32, next_icon)
	next.name = "Next"
	next.pressed.connect(func() -> void:
		close()
		if mode == "stage" and not won or mode == "endless":
			play.restart()
		else:
			play.go_next()
	)
	body.add_child(next)
	var actions: HBoxContainer = UIKit.hbox(24)
	if mode == "stage" and won:
		actions.add_child(_action("rotate-ccw", "AGAIN", "Again", func() -> void:
			close()
			play.restart()))
	if mode == "stage":
		actions.add_child(_action("layout-grid", "STAGES", "Stages", func() -> void:
			close()
			app.go("stages", {"world": play.world_idx})))
	actions.add_child(_action("hammer", "FORGE", "Forge", func() -> void:
		close()
		app.go("forge")))
	actions.add_child(_action("share-2", "SHARE", "Share", func() -> void: open_child(_share_card())))
	actions.add_child(_action("house", "HOME", "Home", func() -> void:
		close()
		app.go("home")))
	body.add_child(actions)


func _say(msg: String) -> void:
	_status.text = msg
	_status.visible = true
	refit()


func _tip() -> String:
	var tips: Array[String] = [
		"Tip: coins from every run buy permanent upgrades in the Forge.",
		"Tip: let go when a shape sits on the ring's edge: a PERFECT hits twice as hard.",
		"Tip: a full-size ring reaches far, but you're not attacking while it grows.",
		"Tip: Shield Regen and Thorns keep you alive while you learn a world.",
		"Tip: ring types in the Forge change how the ring plays.",
	]
	return tips[posmod(play.sim.ticks, tips.size())]


func _goal(done: bool, text: String) -> HBoxContainer:
	var row: HBoxContainer = UIKit.hbox(10, BoxContainer.ALIGNMENT_BEGIN)
	row.add_child(UIKit.icon_rect("check" if done else "x", 26, Style.SUCCESS if done else Color(Style.INK, 0.35)))
	row.add_child(UIKit.label(text, 22, Style.INK if done else Style.MUTED, 600, HORIZONTAL_ALIGNMENT_LEFT))
	return row


func _share_card() -> ShareCardOverlay:
	var o: ShareCardOverlay = ShareCardOverlay.new()
	o.info = play.share_info()
	return o


func _action(icon_name: String, caption: String, node_name: String, cb: Callable) -> VBoxContainer:
	var box: VBoxContainer = UIKit.vbox(6)
	var b: Button = UIKit.icon_button(icon_name, 76)
	b.name = node_name
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	box.add_child(b)
	box.add_child(UIKit.caption(caption, Style.MUTED, 15))
	return box


func _note(icon_name: String, text: String, tint: Color) -> PanelContainer:
	var row: HBoxContainer = UIKit.hbox(12)
	row.add_child(UIKit.icon_rect(icon_name, 34, tint))
	var l: Label = UIKit.label(text, Style.SIZE_SMALL, Style.INK, 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return UIKit.panel(row, Color(tint, 0.14), 26, Vector2(20, 10))


func on_back() -> void:
	close()
	if play.mode == "stage":
		app.go("stages", {"world": play.world_idx})
	else:
		app.go("home")
