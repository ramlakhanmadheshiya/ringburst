class_name ResultCard
extends Overlay
## The end of a level, laid out like Single Shot's: the stars (one for every
## shield left), the task, one big score, one line of good news (new best,
## more stars, what opened), then Next level (or Try again) and a row of
## round actions.

var play: Node
var result: Dictionary = {}


func _init() -> void:
	super._init()
	dismissable = false


func build() -> void:
	name = "Result"
	body.add_theme_constant_override("separation", 10)
	var sim: RunSim = play.sim
	var won: bool = sim.state == RunSim.State.WON
	var acc: Color = play.accent()
	body.add_child(UIKit.caption(play.where_text(), acc, 16))
	var title: Label = UIKit.label("Level clear!" if won else "Not this time", Style.SIZE_H1, Style.INK, 600)
	title.name = "ResultTitle"
	body.add_child(title)
	if won:
		var row: StarRow = StarRow.new()
		row.name = "Stars"
		row.custom_minimum_size.y = 92
		body.add_child(row)
		row.play(sim.stars())
		body.add_child(UIKit.label(_stars_text(sim), Style.SIZE_CAPTION, Style.MUTED, 500))
	else:
		var task: Label = UIKit.label("%s · %d%% done" % [play.task_text(), int(round(sim.goal_progress() * 100.0))], Style.SIZE_SMALL, Style.MUTED, 600)
		task.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(task)
	body.add_child(UIKit.gap(4))
	var score: Label = UIKit.label(play._thousands(sim.score), 60, Style.INK, 700)
	score.name = "StatScore"
	body.add_child(score)
	body.add_child(UIKit.label("Best combo %d · %d PERFECTs · %d shapes" % [sim.best_combo, sim.perfects, sim.kills], Style.SIZE_CAPTION, Style.MUTED, 500))
	var notes: Array[String] = _notes()
	if not notes.is_empty():
		var n: Label = UIKit.para(" · ".join(notes), Style.SIZE_SMALL - 1, Style.GOLD if Style.DARK else Color("A86A00"))
		n.name = "Notes"
		body.add_child(n)
	if not won:
		body.add_child(UIKit.para(_tip(), Style.SIZE_CAPTION, Style.MUTED))
	body.add_child(UIKit.gap(8))
	var next: Button = UIKit.button("Next level" if won else "Try again", "primary", acc, 88, 30)
	next.name = "Next"
	next.pressed.connect(func() -> void:
		close()
		if won:
			play.go_next()
		else:
			play.restart()
	)
	body.add_child(next)
	body.add_child(UIKit.gap(4))
	var actions: HBoxContainer = UIKit.hbox(26)
	if won:
		actions.add_child(_action("rotate-ccw", "Again", "Again", func() -> void:
			close()
			play.restart()))
	actions.add_child(_action("layout-grid", "Levels", "Levels", func() -> void:
		close()
		app.go("levels", {"world": play.world_idx})))
	actions.add_child(_action("share-2", "Share", "Share", func() -> void: open_child(_share_card())))
	actions.add_child(_action("house", "Home", "Home", func() -> void:
		close()
		app.go("home")))
	body.add_child(actions)


## How the stars were won, in one short line.
func _stars_text(sim: RunSim) -> String:
	if sim.revives > 0:
		return "Revived: one star. Clear it with shields left for more."
	if sim.stars() == 3:
		return "Every shield intact!"
	return "%d %s left. Keep all three for three stars." % [sim.lives, "shield" if sim.lives == 1 else "shields"]


## Good news from this level, short enough to share one line.
func _notes() -> Array[String]:
	var out: Array[String] = []
	if bool(result.get("new_best", false)):
		out.append("New best score")
	if int(result.get("new_stars", 0)) > 0 and not bool(result.get("first", false)):
		var n: int = int(result["new_stars"])
		out.append("+%d %s" % [n, "star" if n == 1 else "stars"])
	if bool(result.get("world_done", false)):
		out.append("World complete!")
	if not str(result.get("unlocked", "")).is_empty():
		var wk: Array[int] = Worlds.parse_level_id(str(result["unlocked"]))
		if wk[1] == 0:
			out.append("%s is open" % Worlds.world(wk[0])["name"])
	return out


func _tip() -> String:
	var tips: Array[String] = [
		"Tip: let go when a shape sits on the ring's edge. A PERFECT hits twice as hard.",
		"Tip: a full-size ring reaches far, but you're not bursting while it grows.",
		"Tip: watch the closest shapes first. Anything that reaches your core breaks a shield.",
		"Tip: one burst hits everything inside the ring. Let shapes bunch up, then pop them together.",
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
	app.go("levels", {"world": play.world_idx})
