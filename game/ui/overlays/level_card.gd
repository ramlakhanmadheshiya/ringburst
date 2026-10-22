class_name LevelCard
extends Overlay
## Before a level: its one task, in big letters, the stars already earned
## and how stars are won, then Play.

var world: int = 0
var level: int = 0


static func make(w: int, k: int) -> LevelCard:
	var o: LevelCard = LevelCard.new()
	o.world = w
	o.level = k
	return o


func build() -> void:
	name = "LevelCard"
	body.add_theme_constant_override("separation", 12)
	var wd: Dictionary = Worlds.world(world)
	var acc: Color = Look.accent(world)
	var spec: Dictionary = Worlds.level_spec(world, level)
	var id: String = spec["id"]
	add_title("Level %d" % (level + 1))
	body.add_child(UIKit.caption(str(wd["name"]), acc, 16))
	body.add_child(UIKit.gap(8))
	# The task.
	var task: VBoxContainer = UIKit.vbox(12)
	task.name = "Task"
	var badge: PanelContainer = UIKit.panel(UIKit.icon_rect(Worlds.goal_icon(spec["goal"]), 48, acc), Color(acc, 0.14), 48, Vector2(22, 22))
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	task.add_child(badge)
	var boss_name: String = str((spec["boss"] as Dictionary).get("name", ""))
	var text: Label = UIKit.label(Worlds.goal_text(spec["goal"], boss_name), Style.SIZE_H2, Style.INK, 600)
	text.name = "TaskText"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	task.add_child(text)
	var hint: String = _hint(spec)
	if not hint.is_empty():
		task.add_child(UIKit.para(hint, Style.SIZE_SMALL, Style.MUTED))
	body.add_child(task)
	body.add_child(UIKit.gap(6))
	# Stars so far.
	var have: int = Profile.level_stars(id)
	var stars: HBoxContainer = UIKit.hbox(10)
	stars.name = "Stars"
	for i: int in 3:
		var st: TextureRect = UIKit.art_rect("star", 40)
		st.modulate = Color.WHITE if i < have else Color(Style.INK, 0.16)
		stars.add_child(st)
	body.add_child(stars)
	body.add_child(UIKit.para("One star for every shield you still have at the end.", Style.SIZE_CAPTION, Style.MUTED))
	body.add_child(UIKit.gap(8))
	var play: Button = UIKit.button("Play", "primary", acc, 96, 34, "play")
	play.name = "PlayLevel"
	play.pressed.connect(func() -> void:
		close()
		app.go("play", {"world": world, "level": level})
	)
	body.add_child(play)


## A short tip for the task, when it helps.
func _hint(spec: Dictionary) -> String:
	match str(spec["goal"]["type"]):
		"perfects":
			return "Let go when a shape sits right on the ring's edge."
		"combo":
			return "PERFECTs in a row. A burst that hits nothing, or a hit on your core, starts it again."
		"survive":
			return "Keep every shape away from your core."
		"hunt":
			return str(EnemyTypes.info(int(spec["goal"]["shape"]))["tip"])
		"guardian":
			return "A giant arrives after a few seconds. Keep bursting it."
		"boss":
			return "The world's boss. Beat it to open the next world."
	return ""
