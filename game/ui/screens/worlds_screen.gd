extends Screen
## All 8 worlds as a calm vertical list, each card in its own colours.


func build() -> void:
	body.add_child(header("Worlds", "★ %d / %d" % [Profile.total_stars(), Worlds.total_levels() * 3]))
	body.add_child(UIKit.gap(6))
	var scroll: TouchScroll = TouchScroll.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var list: VBoxContainer = UIKit.vbox(16)
	list.name = "List"
	scroll.set_content(list)
	var focus_card: Control = null
	for i: int in Worlds.count():
		var wd: Dictionary = Worlds.world(i)
		var card: WorldCard = WorldCard.new()
		card.name = "World_" + str(wd["id"])
		card.world = i
		card.clears = Profile.world_clears(i)
		card.stars = Profile.world_stars(i)
		card.unlocked = Profile.world_unlocked(i)
		if not card.unlocked and i > 0:
			card.lock_text = "Beat %s in %s to open" % [EnemyTypes.BOSSES[i - 1]["name"], Worlds.world(i - 1)["name"]]
		var idx: int = i
		card.pressed.connect(func() -> void:
			if Profile.world_unlocked(idx):
				app.go("levels", {"world": idx})
			else:
				Audio.play("error", 1.2, -8.0)
				app.toast("Beat the boss of %s first" % Worlds.world(idx - 1)["name"], "lock", Style.AMBER)
		)
		list.add_child(card)
		if card.unlocked:
			focus_card = card
		card.modulate.a = 0.0
		create_tween().tween_property(card, "modulate:a", 1.0, 0.3).set_delay(0.03 * i)
	list.add_child(UIKit.gap(16))
	_scroll_to.call_deferred(scroll, focus_card)


## Brings the furthest open world into view.
func _scroll_to(scroll: TouchScroll, card: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if card == null or not card.is_inside_tree():
		return
	if card.position.y + card.size.y + 24.0 > scroll.size.y:
		var stride: float = card.size.y + 16.0
		var fit: int = maxi(2, int(scroll.size.y / stride))
		scroll.scroll_to(card.position.y - (fit - 2) * stride)
