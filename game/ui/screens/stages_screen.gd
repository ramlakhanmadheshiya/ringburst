extends Screen
## A world's six stages as a path, its new shape, and its stars. Tapping an
## open stage shows the stage card (goals, ring and perk, Play).

var world: int = 0


func world_index() -> int:
	return world


func build() -> void:
	world = int(args.get("world", 0))
	var wd: Dictionary = Worlds.world(world)
	Audio.world_music(world)
	body.add_child(header(str(wd["name"]), "World %d" % (world + 1)))
	body.add_child(UIKit.gap(6))
	var scroll: TouchScroll = TouchScroll.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var list: VBoxContainer = UIKit.vbox(0)
	list.name = "List"
	scroll.set_content(list)
	list.add_child(_hero())
	list.add_child(UIKit.gap(14))
	var next: Array[int] = Profile.next_stage()
	for k: int in Worlds.STAGES_PER_WORLD:
		var row: StageRow = StageRow.new()
		row.name = "Stage%d" % (k + 1)
		row.world = world
		row.stage = k
		var id: String = Worlds.stage_id(world, k)
		row.unlocked = Profile.stage_unlocked(world, k)
		row.mask = Profile.stage_mask(id)
		row.best = Profile.stage_best(id)
		row.current = next[0] == world and next[1] == k and not Profile.is_cleared(id)
		var kk: int = k
		row.pressed.connect(func() -> void:
			if Profile.stage_unlocked(world, kk):
				app.open(StageCard.make(world, kk))
			else:
				Audio.play("error", 1.2, -8.0)
				app.toast("Clear stage %d first" % kk, "lock", Style.AMBER)
		)
		list.add_child(row)
	list.add_child(UIKit.gap(20))


func _hero() -> PanelContainer:
	var row: HBoxContainer = UIKit.hbox(18, BoxContainer.ALIGNMENT_BEGIN)
	var demo: ShapeDemo = ShapeDemo.new("shape", world)
	demo.custom_minimum_size = Vector2(230, 170)
	demo.accent = accent()
	demo.colors = Worlds.world(world)["enemies"]
	row.add_child(demo)
	var text: VBoxContainer = UIKit.vbox(4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_child(UIKit.caption("New shape", accent(), Style.SIZE_CAPTION, HORIZONTAL_ALIGNMENT_LEFT))
	text.add_child(UIKit.label(str(EnemyTypes.info(world)["name"]), Style.SIZE_H2, Style.INK, 700, HORIZONTAL_ALIGNMENT_LEFT))
	var tip: Label = UIKit.label(str(EnemyTypes.info(world)["tip"]), 19, Style.MUTED, 500, HORIZONTAL_ALIGNMENT_LEFT)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(tip)
	var stars: HBoxContainer = UIKit.hbox(8, BoxContainer.ALIGNMENT_BEGIN)
	stars.add_child(UIKit.art_rect("star", 28))
	stars.add_child(UIKit.label("%d / 18" % Profile.world_stars(world), 22, Style.GOLD, 700))
	text.add_child(stars)
	row.add_child(text)
	return UIKit.panel(row, Style.PANEL, 30, Vector2(14, 14))
