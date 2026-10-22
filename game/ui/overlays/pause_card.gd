class_name PauseCard
extends Overlay
## The pause card: the level's task and how far it has got, Resume, Restart,
## Settings and Quit. Back resumes.

var play: Node


func build() -> void:
	name = "Pause"
	add_title("Paused")
	body.add_child(UIKit.caption(play.where_text(), play.accent(), 16))
	var task: HBoxContainer = UIKit.hbox(12)
	task.add_child(UIKit.icon_rect(Worlds.goal_icon(play.spec["goal"]), 32, play.accent()))
	var tl: Label = UIKit.label(play.task_text(), Style.SIZE_BODY, Style.INK, 600)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	task.add_child(tl)
	body.add_child(task)
	body.add_child(UIKit.progress_bar(play.sim.goal_progress(), play.accent(), 10))
	body.add_child(UIKit.gap(6))
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
	var quit: Button = UIKit.button("Quit level", "ghost", Style.AMBER, 72, 23, "x")
	quit.name = "Quit"
	quit.pressed.connect(func() -> void:
		close()
		play._finished = true
		app.back()
	)
	body.add_child(quit)
