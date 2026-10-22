extends Screen
## A world's 40 levels as a grid, like Single Shot's, under the world's new
## shape and its stars. Tapping an open level shows its card (task, Play).

const COLUMNS: int = 5

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
	var list: VBoxContainer = UIKit.vbox(14)
	list.name = "List"
	scroll.set_content(list)
	list.add_child(_hero())
	var grid: GridContainer = GridContainer.new()
	grid.name = "Grid"
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	list.add_child(grid)
	var next: Array[int] = Profile.next_level()
	var focus: LevelTile = null
	for k: int in Worlds.LEVELS_PER_WORLD:
		var tile: LevelTile = LevelTile.new()
		tile.name = "Level%d" % (k + 1)
		tile.world = world
		tile.level = k
		var id: String = Worlds.level_id(world, k)
		tile.unlocked = Profile.level_unlocked(world, k)
		tile.stars = Profile.level_stars(id)
		tile.current = next[0] == world and next[1] == k and not Profile.is_cleared(id)
		if tile.current:
			focus = tile
		var kk: int = k
		tile.pressed.connect(func() -> void:
			if Profile.level_unlocked(world, kk):
				app.open(LevelCard.make(world, kk))
			else:
				Audio.play("error", 1.2, -8.0)
				app.toast("Clear level %d first" % kk, "lock", Style.AMBER)
		)
		grid.add_child(tile)
	list.add_child(UIKit.gap(20))
	_scroll_to.call_deferred(scroll, focus)


## Brings the level to play next into view.
func _scroll_to(scroll: TouchScroll, tile: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if tile == null or not tile.is_inside_tree():
		return
	var y: float = tile.get_global_rect().position.y - scroll.get_global_rect().position.y
	if y + tile.size.y + 24.0 > scroll.size.y:
		scroll.scroll_to(y - scroll.size.y * 0.4)


func _hero() -> PanelContainer:
	var row: HBoxContainer = UIKit.hbox(18, BoxContainer.ALIGNMENT_BEGIN)
	var demo: ShapeDemo = ShapeDemo.new("shape", world)
	demo.custom_minimum_size = Vector2(200, 150)
	demo.accent = accent()
	demo.colors = Worlds.world(world)["enemies"]
	row.add_child(demo)
	var text: VBoxContainer = UIKit.vbox(4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_child(UIKit.caption("New shape" if world > 0 else "Your first shape", accent(), Style.SIZE_CAPTION, HORIZONTAL_ALIGNMENT_LEFT))
	text.add_child(UIKit.label(str(EnemyTypes.info(world)["name"]), Style.SIZE_H2, Style.INK, 600, HORIZONTAL_ALIGNMENT_LEFT))
	var tip: Label = UIKit.label(str(EnemyTypes.info(world)["tip"]), 19, Style.MUTED, 500, HORIZONTAL_ALIGNMENT_LEFT)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(tip)
	var stars: HBoxContainer = UIKit.hbox(8, BoxContainer.ALIGNMENT_BEGIN)
	stars.add_child(UIKit.art_rect("star", 26))
	stars.add_child(UIKit.label("%d / %d" % [Profile.world_stars(world), Worlds.LEVELS_PER_WORLD * 3], 21, Style.MUTED, 600))
	text.add_child(stars)
	row.add_child(text)
	return UIKit.panel(row, Style.PANEL, 30, Vector2(14, 14))
