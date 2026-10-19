class_name StageCard
extends Overlay
## Before a stage: what ends it, its three star goals (with the ones already
## earned ticked), the best score, and the loadout: ring type and starting
## perk (both from the Forge). Play starts the run.

var world: int = 0
var stage: int = 0
var _ring_row: HFlowContainer
var _perk_row: HFlowContainer


static func make(w: int, k: int) -> StageCard:
	var o: StageCard = StageCard.new()
	o.world = w
	o.stage = k
	return o


func build() -> void:
	name = "StageCard"
	var wd: Dictionary = Worlds.world(world)
	var acc: Color = Look.accent(world)
	var id: String = Worlds.stage_id(world, stage)
	var boss: bool = stage == Worlds.STAGES_PER_WORLD - 1
	add_title("Boss stage" if boss else "Stage %d" % (stage + 1))
	body.add_child(UIKit.caption("%s · world %d" % [wd["name"], world + 1], acc))
	var end: String = "the boss, %s" % EnemyTypes.BOSSES[world]["name"] if boss else "a Guardian: Giant %s" % EnemyTypes.info(world)["name"]
	body.add_child(UIKit.para("Survive %d seconds, then beat %s." % [int(Worlds.DURATIONS[stage]), end], Style.SIZE_SMALL + 1, Style.INK))
	var mask: int = Profile.stage_mask(id)
	var goals: VBoxContainer = UIKit.vbox(8)
	goals.name = "Goals"
	goals.add_child(_goal(mask & 1 != 0, "Clear the stage"))
	goals.add_child(_goal(mask & 2 != 0, "Take no hits"))
	goals.add_child(_goal(mask & 4 != 0, "Reach a %d combo" % Worlds.combo_target(world, stage)))
	body.add_child(UIKit.panel(goals, Style.FIELD, 26, Vector2(22, 16)))
	if Profile.stage_best(id) > 0:
		body.add_child(UIKit.label("Best score: %d" % Profile.stage_best(id), Style.SIZE_SMALL, Style.MUTED, 600))
	body.add_child(UIKit.caption("Ring type", Style.MUTED, Style.SIZE_CAPTION, HORIZONTAL_ALIGNMENT_LEFT))
	_ring_row = _flow()
	_ring_row.name = "Rings"
	body.add_child(_ring_row)
	body.add_child(UIKit.caption("Starting perk", Style.MUTED, Style.SIZE_CAPTION, HORIZONTAL_ALIGNMENT_LEFT))
	_perk_row = _flow()
	_perk_row.name = "Perks"
	body.add_child(_perk_row)
	_fill_loadout()
	var play: Button = UIKit.button("Play", "primary", acc, 100, 36, "play")
	play.name = "PlayStage"
	play.pressed.connect(func() -> void:
		close()
		app.go("play", {"world": world, "stage": stage})
	)
	body.add_child(play)
	var forge: Button = UIKit.button("Forge: upgrades, rings, perks", "ghost", Style.AMBER, 66, 21, "hammer")
	forge.name = "OpenForge"
	forge.pressed.connect(func() -> void:
		close()
		app.go("forge")
	)
	body.add_child(forge)


func _flow() -> HFlowContainer:
	var f: HFlowContainer = HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 10)
	f.add_theme_constant_override("v_separation", 10)
	return f


func _fill_loadout() -> void:
	for c: Node in _ring_row.get_children():
		c.queue_free()
	for c: Node in _perk_row.get_children():
		c.queue_free()
	for rid: String in RingTypes.ring_ids():
		if Profile.owns_ring(rid):
			_ring_row.add_child(_chip(RingTypes.ring_name(rid), rid == Profile.ring(), func() -> void:
				Profile.set_ring(rid)
				_fill_loadout()))
	_perk_row.add_child(_chip("None", Profile.perk().is_empty(), func() -> void:
		Profile.set_perk("")
		_fill_loadout()))
	var any: bool = false
	for pid: String in Upgrades.PERKS:
		if Profile.owns_perk(pid):
			any = true
			_perk_row.add_child(_chip(Upgrades.display_name(pid), pid == Profile.perk(), func() -> void:
				Profile.set_perk(pid)
				_fill_loadout()))
	if not any:
		_perk_row.add_child(UIKit.label("Unlock perks in the Forge", 19, Style.MUTED, 500))
	refit()


func _chip(text: String, on: bool, cb: Callable) -> Button:
	var b: Button = UIKit.button(text, "primary" if on else "ghost", Style.AMBER, 58, 19)
	b.name = "Pick_" + text.replace(" ", "")
	b.pressed.connect(cb)
	return b


func _goal(done: bool, text: String) -> HBoxContainer:
	var row: HBoxContainer = UIKit.hbox(12, BoxContainer.ALIGNMENT_BEGIN)
	var star: TextureRect = UIKit.art_rect("star", 30)
	star.modulate = Color.WHITE if done else Color(Style.INK, 0.2)
	row.add_child(star)
	row.add_child(UIKit.label(text, 23, Style.INK if done else Style.MUTED, 600, HORIZONTAL_ALIGNMENT_LEFT))
	return row
