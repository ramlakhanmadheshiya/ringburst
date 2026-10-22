class_name ResultCard
extends Overlay
## The end of a run, laid out like Single Shot's: the stars and which goals
## were met (campaign), one big score with a single line of stats, one line of
## good news (new best, new stars, what opened, streak), coins counting up
## with an optional "double with a video" (asked for, never automatic), then
## Next and a row of round actions.

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
	body.add_child(UIKit.caption(play._where_text(), acc, 16))
	var title_text: String = "Stage clear!" if won else "Run over"
	if mode == "daily":
		title_text = "Daily run done" if won else "Daily run over"
	elif mode == "endless":
		title_text = "Lasted %s" % play.share_info()["time_text"]
	var title: Label = UIKit.label(title_text, Style.SIZE_H1, Style.INK, 600)
	title.name = "ResultTitle"
	body.add_child(title)
	if mode == "stage":
		var mask: int = sim.stars_mask()
		var row: StarRow = StarRow.new()
		row.name = "Stars"
		row.custom_minimum_size.y = 84
		body.add_child(row)
		row.play(mask)
		body.add_child(UIKit.label(_goals_text(mask), Style.SIZE_CAPTION, Style.MUTED, 500))
	body.add_child(UIKit.gap(4))
	var score: Label = UIKit.label(play._thousands(sim.score), 64, Style.INK, 700)
	score.name = "StatScore"
	body.add_child(score)
	var line: String = "Best combo %d · %d perfects · %d shapes" % [sim.best_combo, sim.perfects, sim.kills]
	body.add_child(UIKit.label(line, Style.SIZE_CAPTION, Style.MUTED, 500))
	var notes: Array[String] = _notes(reward, mode, sim)
	if not notes.is_empty():
		var n: Label = UIKit.para(" · ".join(notes), Style.SIZE_SMALL - 1, Style.GOLD if Style.DARK else Color("A86A00"))
		n.name = "Notes"
		body.add_child(n)
	body.add_child(UIKit.gap(2))
	var coins: int = int(reward.get("coins", 0))
	var coin_row: HBoxContainer = UIKit.hbox(10)
	coin_row.add_child(UIKit.art_rect("coin", 40))
	_amount = UIKit.label("+0", 34, Style.INK, 700)
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
		var dbl: Button = UIKit.button("Double coins · watch a video" if not Profile.is_supporter() else "Double coins", "ghost", Style.AMBER, 64, 21, "art:watch")
		dbl.name = "Double"
		dbl.custom_minimum_size.x = 400
		dbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
	if not won and mode == "stage":
		body.add_child(UIKit.para(_tip(), Style.SIZE_CAPTION, Style.MUTED))
	body.add_child(UIKit.gap(8))
	var next_text: String = "Home"
	if mode == "stage":
		next_text = "Next stage" if won else "Try again"
	elif mode == "endless":
		next_text = "Play again"
	var next: Button = UIKit.button(next_text, "primary", acc, 88, 30)
	next.name = "Next"
	next.pressed.connect(func() -> void:
		close()
		if mode == "stage" and not won or mode == "endless":
			play.restart()
		else:
			play.go_next()
	)
	body.add_child(next)
	body.add_child(UIKit.gap(4))
	var actions: HBoxContainer = UIKit.hbox(26)
	if mode == "stage" and won:
		actions.add_child(_action("rotate-ccw", "Again", "Again", func() -> void:
			close()
			play.restart()))
	if mode == "stage":
		actions.add_child(_action("layout-grid", "Stages", "Stages", func() -> void:
			close()
			app.go("stages", {"world": play.world_idx})))
	if not won or mode != "stage":
		actions.add_child(_action("hammer", "Forge", "Forge", func() -> void:
			close()
			app.go("forge")))
	actions.add_child(_action("share-2", "Share", "Share", func() -> void: open_child(_share_card())))
	if mode != "stage" or won:
		actions.add_child(_action("house", "Home", "Home", func() -> void:
			close()
			app.go("home")))
	body.add_child(actions)


## Which of the three star goals this run met, in one short line.
func _goals_text(mask: int) -> String:
	var parts: Array[String] = []
	parts.append(("✓ " if mask & 1 != 0 else "") + "Clear")
	parts.append(("✓ " if mask & 2 != 0 else "") + "No hits")
	parts.append(("✓ " if mask & 4 != 0 else "") + "%d combo" % int(play.spec["combo_target"]))
	return "   ".join(parts)


## Good news from this run, short enough to share one line.
func _notes(rw: Dictionary, mode: String, sim: RunSim) -> Array[String]:
	var out: Array[String] = []
	if bool(rw.get("new_best", false)) and sim.score > 0:
		out.append("New best")
	elif mode != "stage" and int(rw.get("best", 0)) > 0:
		out.append("Best %s" % play._thousands(int(rw.get("best", 0))))
	if int(rw.get("new_stars", 0)) > 0 and not bool(rw.get("first", false)):
		out.append("%d new %s" % [int(rw["new_stars"]), "star" if int(rw["new_stars"]) == 1 else "stars"])
	if bool(rw.get("world_done", false)):
		out.append("World complete! +%d coins" % Economy.WORLD_BONUS)
	if not str(rw.get("unlocked", "")).is_empty():
		var wk: Array[int] = Worlds.parse_stage_id(str(rw["unlocked"]))
		out.append("%s is open" % Worlds.world(wk[0])["name"] if wk[1] == 0 else "Stage %d is open" % (wk[1] + 1))
	if mode == "daily" and bool(rw.get("first", false)):
		out.append("%d-day streak" % int(rw.get("streak", 1)))
	return out


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


func _share_card() -> ShareCardOverlay:
	var o: ShareCardOverlay = ShareCardOverlay.new()
	o.info = play.share_info()
	return o


func _action(icon_name: String, caption: String, node_name: String, cb: Callable) -> VBoxContainer:
	var box: VBoxContainer = UIKit.vbox(6)
	var b: Button = UIKit.icon_button(icon_name, 68)
	b.name = node_name
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	box.add_child(b)
	box.add_child(UIKit.caption(caption, Style.MUTED, 14))
	return box


func on_back() -> void:
	close()
	if play.mode == "stage":
		app.go("stages", {"world": play.world_idx})
	else:
		app.go("home")
