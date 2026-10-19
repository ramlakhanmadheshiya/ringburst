class_name PauseCard
extends Overlay
## The pause card: the upgrades taken so far, Resume, Restart, Settings and
## Quit. Back resumes.

var play: Node


func build() -> void:
	name = "Pause"
	add_title("Paused")
	body.add_child(UIKit.caption(play._where_text(), play.accent()))
	var levels: Dictionary = play.sim.stats.levels
	if levels.is_empty():
		body.add_child(UIKit.para("No upgrades yet. Bursting shapes drops gems: collect them to level up.", Style.SIZE_SMALL))
	else:
		var grid: GridContainer = GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 10)
		for id: String in levels:
			var row: HBoxContainer = UIKit.hbox(10, BoxContainer.ALIGNMENT_BEGIN)
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(UIKit.icon_rect(str(Upgrades.def(id).get("icon", "zap")), 30, Style.AMBER))
			var l: Label = UIKit.label("%s %s" % [Upgrades.display_name(id), Upgrades.roman(int(levels[id]))], 21, Style.INK, 600, HORIZONTAL_ALIGNMENT_LEFT)
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			grid.add_child(row)
		body.add_child(UIKit.panel(grid, Style.FIELD, 26, Vector2(20, 14)))
	body.add_child(UIKit.gap(4))
	var resume: Button = UIKit.button("Resume", "primary", play.accent(), 96, 32, "play")
	resume.name = "Resume"
	resume.pressed.connect(close)
	body.add_child(resume)
	var row2: HBoxContainer = UIKit.hbox(12)
	var restart: Button = UIKit.button("Restart", "soft", Style.AMBER, 80, 24, "rotate-ccw")
	restart.name = "Restart"
	restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart.pressed.connect(func() -> void:
		close()
		play.restart()
	)
	row2.add_child(restart)
	var settings: Button = UIKit.button("Settings", "soft", Style.AMBER, 80, 24, "settings")
	settings.name = "PauseSettings"
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.pressed.connect(func() -> void: open_child(SettingsCard.new()))
	row2.add_child(settings)
	body.add_child(row2)
	var quit: Button = UIKit.button("Quit run", "ghost", Style.AMBER, 72, 23, "x")
	quit.name = "Quit"
	quit.pressed.connect(func() -> void:
		close()
		play._finished = true
		app.back()
	)
	body.add_child(quit)
	body.add_child(UIKit.para("Quitting ends the run without coins.", Style.SIZE_CAPTION))
