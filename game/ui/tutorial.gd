class_name Tutorial
extends Control
## Hands-on first-play tutorial (Neon Shore level 1), like Single Shot's: it
## never blocks input. The player really holds and releases while an animated
## hand and short captions guide them; tutorial shapes wait at a set distance
## until they're burst. Then the real level starts.

signal done

enum Step { HOLD, AIM, AGAIN, GROUP, DANGER, READY }

var screen: Node
var sim: RunSim
var step: int = Step.HOLD
var _t: float = 0.0
var _caption: Label
var _bubble: PanelContainer
var _wait: float = 0.0
var _ended: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble = PanelContainer.new()
	_bubble.name = "TutorialBubble"
	var sb: StyleBoxFlat = UIKit.box(Color(Style.CARD, 0.94), 30, Color(Style.AMBER, 0.6), 2, Vector2(28, 16))
	_bubble.add_theme_stylebox_override("panel", sb)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption = UIKit.label("", 27, Style.INK, 600)
	_caption.name = "TutorialText"
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.custom_minimum_size = Vector2(520, 0)
	_bubble.add_child(_caption)
	add_child(_bubble)


func begin(run: RunSim) -> void:
	sim = run
	screen.arena.sim_event.connect(_on_event)
	_go(Step.HOLD)
	_spawn(Vector2(0, -585), 230.0)


func _spawn(pos: Vector2, hold: float) -> void:
	var e: RunSim.Enemy = sim.spawn_enemy(EnemyTypes.DRIFTER, pos, 1.0, 1.0)
	e.hold_r = hold
	e.wobble = 0.0


func _go(next: int) -> void:
	step = next
	_t = 0.0
	match step:
		Step.HOLD:
			_say("Hold anywhere on the screen to grow your ring")
		Step.AIM:
			_say("Let go when the ring touches the shape")
		Step.AGAIN:
			_say("A bit short! Hold again, and let go right on the shape")
		Step.GROUP:
			_say("One burst hits everything inside the ring. Catch a shape right on the edge for a PERFECT: double damage!")
		Step.DANGER:
			_say("Shapes that reach your core break a shield. Burst them first!")
		Step.READY:
			_say("You're ready! Every level has one task. Finish it to clear the level.")


func _say(text: String) -> void:
	_caption.text = text
	_bubble.modulate.a = 0.0
	create_tween().tween_property(_bubble, "modulate:a", 1.0, 0.25)


func _process(delta: float) -> void:
	_t += delta
	if sim == null or _ended:
		return
	_bubble.reset_size()
	_bubble.position = Vector2((size.x - _bubble.size.x) / 2.0, size.y * 0.74 - _bubble.size.y / 2.0)
	match step:
		Step.HOLD, Step.AGAIN:
			if sim.charging:
				_go(Step.AIM)
		Step.GROUP, Step.DANGER:
			if sim.alive_count() == 0:
				_wait += delta
				if _wait > 0.6:
					_wait = 0.0
					if step == Step.GROUP:
						_go(Step.DANGER)
						_spawn(Vector2(-385, -60), 0.0)
						_spawn(Vector2(385, 80), 0.0)
					else:
						_go(Step.READY)
		Step.READY:
			if _t > 2.4:
				_ended = true
				var tw: Tween = create_tween()
				tw.tween_property(self, "modulate:a", 0.0, 0.3)
				tw.tween_callback(func() -> void: done.emit())
	queue_redraw()


func _on_event(ev: Dictionary) -> void:
	if _ended:
		return
	match str(ev["t"]):
		"release":
			if step == Step.AIM:
				# Decide once the wave has had time to land.
				get_tree().create_timer(0.35).timeout.connect(func() -> void:
					if _ended or step != Step.AIM:
						return
					if sim.alive_count() == 0:
						_say("PERFECT! That's the timing." if bool(ev["crit"]) else "Nice! Next time let go right on its edge.")
						get_tree().create_timer(1.6).timeout.connect(func() -> void:
							if _ended:
								return
							_go(Step.GROUP)
							_spawn(Vector2(-385, -200), 150.0)
							_spawn(Vector2(385, 160), 230.0)
							_spawn(Vector2(0, 585), 300.0)
						)
					else:
						_go(Step.AGAIN)
				)


func _draw() -> void:
	if step != Step.HOLD and step != Step.AGAIN and step != Step.AIM:
		return
	# The hand presses low on the screen (where a thumb rests) while a ring
	# grows from the core, then lifts.
	var c: Vector2 = Vector2(size.x * 0.7, size.y * 0.88)
	var core: Vector2 = screen.arena.to_screen(Vector2.ZERO) if screen != null else size * 0.5
	var cycle: float = fposmod(_t, 2.2)
	var down: bool = cycle > 0.3 and cycle < 1.6
	if step == Step.AIM:
		down = sim.charging
	var lift: float = 0.0 if down else 18.0
	var hand: Texture2D = UIKit.icon("pointer-filled")
	var hs: float = 96.0
	if down and step != Step.AIM:
		var k: float = clampf((cycle - 0.3) / 1.3, 0.0, 1.0)
		draw_arc(core, 30.0 + 140.0 * k, 0.0, TAU, 64, Color(Style.AMBER, 0.6 * (1.0 - k * 0.5)), 5.0, true)
	draw_circle(c, 26.0 if down else 18.0, Color(Style.AMBER, 0.25 if down else 0.12))
	if hand != null:
		draw_texture_rect(hand, Rect2(c + Vector2(-hs * 0.3, -hs * 0.05 + lift), Vector2(hs, hs)), false, Color(1, 1, 1, 0.95))
