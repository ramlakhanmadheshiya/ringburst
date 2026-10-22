class_name ArenaView
extends Control
## Plays a RunSim on screen. Steps it at a fixed 60 Hz (with slow motion and
## hit-stop applied to how many steps run, never to the steps themselves, so
## the run stays deterministic), turns touches into hold/release, draws the
## arena with neon glow, and turns the sim's events into juice: particles,
## trauma shake, flashes, floating text, sound and haptics.
##
## In demo mode a Bot plays, silently, in whatever rect it is given (the home
## screen's live preview).

signal finished(won: bool)
signal sim_event(ev: Dictionary)

const ARENA: Vector2 = Vector2(720.0, 1120.0)
const MAX_PARTICLES: int = 360
const MAX_STEPS_PER_FRAME: int = 4

var sim: RunSim
var world: int = 0
var demo: bool = false
var bot: Bot
var paused: bool = false
var input_enabled: bool = true
var pal: Dictionary = {}
var ring_style: String = "classic"
## Extra zoom for small previews (1 = fit the arena to the rect).
var zoom: float = 1.0
## Space kept clear at the top (for the HUD); the arena centres below it.
var inset_top: float = 0.0

var _acc: float = 0.0
var _slowmo_t: float = 0.0
var _hitstop_t: float = 0.0
var _trauma: float = 0.0
var _flash: Color = Color(0, 0, 0, 0)
var _pulse: float = 0.0
var _t: float = 0.0
var _particles: Array[Dictionary] = []
var _texts: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _edge_cue: bool = false
var _tick_step: int = 0
var _gate: Dictionary = {}
var _over: bool = false
var _scale: float = 1.0
var _origin: Vector2 = Vector2.ZERO
var _shake: Vector2 = Vector2.ZERO
var _noise: Rng = Rng.new(99)
var _glow: GlowLayer
var _top: TopLayer
var _light: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	_glow = GlowLayer.new()
	_glow.arena = self
	add_child(_glow)
	_top = TopLayer.new()
	_top.arena = self
	add_child(_top)
	if pal.is_empty():
		set_world(world)
	if demo:
		mouse_filter = Control.MOUSE_FILTER_IGNORE


## Uses world w's palette (in the player's chosen theme) and ring style.
func set_world(w: int) -> void:
	world = w
	pal = Look.arena(w)
	ring_style = Look.style_id()
	_light = bool(pal.get("light", false))
	if _glow != null:
		_glow.material = null if _light else _add_material()


static var _add_mat: CanvasItemMaterial


static func _add_material() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat


func start(run: RunSim) -> void:
	sim = run
	_over = false
	_acc = 0.0
	_particles.clear()
	_texts.clear()
	_sparks.clear()
	_rings.clear()
	if demo:
		bot = Bot.new("perfect", 11)


# --- Input ----------------------------------------------------------------------

func _gui_input(e: InputEvent) -> void:
	if demo or not input_enabled or sim == null:
		return
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			press()
		else:
			lift()
		accept_event()


func press() -> void:
	if sim != null and not paused and sim.state == RunSim.State.RUNNING:
		sim.input_down()


func lift() -> void:
	if sim != null:
		sim.input_up()


# --- Stepping -------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_layout()
	if sim != null and not paused:
		_advance(delta)
	_update_fx(delta)
	queue_redraw()
	_glow.queue_redraw()
	_top.queue_redraw()


func _advance(delta: float) -> void:
	var scale: float = 1.0
	if _hitstop_t > 0.0:
		_hitstop_t -= delta
		scale = 0.0
	elif _slowmo_t > 0.0:
		_slowmo_t -= delta
		scale = 0.35
	_acc += delta * scale
	var steps: int = 0
	while _acc >= RunSim.TICK and steps < MAX_STEPS_PER_FRAME:
		_acc -= RunSim.TICK
		steps += 1
		if demo and bot != null:
			bot.act(sim)
		sim.step()
		_on_events(sim.events)
		if sim.is_over():
			break
	if _acc > RunSim.TICK * 4.0:
		_acc = 0.0
	if sim.is_over() and not _over:
		_over = true
		finished.emit(sim.state == RunSim.State.WON)
	_charge_cues()


## Sound and haptic cues while the ring grows: soft ticks that rise in pitch,
## and a blip the moment a shape sits on the edge.
func _charge_cues() -> void:
	if demo or not sim.charging:
		_tick_step = 0
		_edge_cue = false
		return
	var step: int = int(sim.ring_r / 34.0)
	if step > _tick_step:
		_tick_step = step
		Audio.play("tick", 0.7 + 0.9 * sim.ring_r / maxf(1.0, sim.stats.max_r), -16.0)
	var on: bool = not sim.perfect_targets(sim.ring_r).is_empty()
	if on and not _edge_cue:
		Audio.play("edge", 1.0, -10.0)
		Haptics.tick()
	_edge_cue = on


func _sound(name: String, pitch: float = 1.0, db: float = 0.0, gap_ms: int = 40) -> void:
	if demo:
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_gate.get(name, -100000)) < gap_ms:
		return
	_gate[name] = now
	Audio.play(name, pitch, db)


func _shake_on() -> bool:
	return bool(Profile.setting("shake", true)) and not demo


func add_trauma(v: float) -> void:
	if _shake_on():
		_trauma = minf(1.0, _trauma + v)


func _on_events(events: Array[Dictionary]) -> void:
	for ev: Dictionary in events:
		sim_event.emit(ev)
		match str(ev["t"]):
			"release":
				var r: float = float(ev["r"])
				_pulse = maxf(_pulse, 0.35 + 0.5 * r / 500.0)
				_sound("release", 1.25 - 0.5 * clampf(r / 450.0, 0.0, 1.0), -4.0, 30)
				if not demo:
					Haptics.tick()
			"perfect":
				var combo: int = int(ev["combo"])
				_slowmo_t = 0.16 if not demo else 0.0
				_flash = Color(1, 1, 1, 0.10 if not _light else 0.06)
				if not demo:
					Audio.note("perfect", combo - 1, -2.0)
					Haptics.success()
				add_trauma(0.12)
				for p: Variant in ev["points"]:
					_burst(p, Color.WHITE, 10, 160.0, 4.0)
					_ring_fx(p, 10.0, 60.0, Color(1, 1, 1, 0.9), 0.3)
				var label: String = "PERFECT" if combo < 3 else "PERFECT  x%d" % combo
				_text(Vector2(0, -float(ev["r"]) - 34.0), label, Color.WHITE if not _light else pal["accent"], 34 if combo < 10 else 40)
			"hit":
				if bool(ev.get("boss", false)):
					_sound("hit_boss", 1.0, -6.0, 60)
					add_trauma(0.08)
					if bool(ev.get("crit", false)):
						_hitstop_t = maxf(_hitstop_t, 0.045)
				else:
					_sound("hit", 0.9 + _noise.next_float() * 0.3, -14.0, 45)
			"kill":
				var col: Color = _enemy_color(int(ev.get("color", 0)))
				var big: bool = bool(ev.get("boss", false))
				_burst(ev["pos"], col, 26 if big else 9, 380.0 if big else 220.0, 6.0 if big else 4.0)
				_ring_fx(ev["pos"], float(ev.get("radius", 16.0)), float(ev.get("radius", 16.0)) * 2.4, col, 0.35)
				if big:
					_sound("boom", 1.0, 0.0, 100)
					_hitstop_t = 0.12
					add_trauma(0.6)
					_flash = Color(1, 1, 1, 0.25)
					if not demo:
						Haptics.heavy()
				else:
					_sound("pop", 0.85 + _noise.next_float() * 0.45, -8.0, 35)
			"shield_break":
				_sound("shatter", 1.0, -4.0, 60)
				_burst(ev["pos"], Color("9FE8FF"), 12, 240.0, 3.0)
			"blocked":
				_sound("clink", 1.0, -10.0, 80)
				_text(ev["pos"] - Vector2(0, 30), "BLOCKED", Color("9FE8FF"), 22)
			"damage":
				_sound("hurt", 1.0, 0.0, 100)
				_flash = Color(1, 0.15, 0.25, 0.32)
				add_trauma(0.7)
				_ring_fx(Vector2.ZERO, RunSim.CORE_R, 180.0, Color("FF4F6E"), 0.45)
				if not demo:
					Haptics.error()
			"blast", "revive":
				_ring_fx(Vector2.ZERO, RunSim.CORE_R, 320.0, pal["accent"], 0.5)
				if str(ev["t"]) != "blast":
					_sound("shield", 1.2, -2.0, 100)
			"boss":
				_sound("boss", 1.0, 0.0, 500)
				add_trauma(0.5)
				_text(Vector2(0, -170), str(ev["name"]).to_upper(), Color("FF5C7A"), 46)
				if not demo:
					Audio.music("boss")
					Haptics.heavy()
			"dash_warn":
				_sound("warn", 1.3 if not bool(ev.get("boss", false)) else 0.8, -12.0, 120)
			"spark":
				_sparks.append({"a": ev["from"], "b": ev["to"], "life": 0.18})
				_sound("zap", 1.0 + _noise.next_float() * 0.3, -10.0, 50)
			"combo_lost":
				_sound("fizzle", 1.0, -6.0, 200)
			"won":
				_sound("win", 1.0, 0.0, 500)
			"lost":
				_sound("lose", 1.0, 0.0, 500)
				add_trauma(1.0)


# --- Effects ----------------------------------------------------------------------

func _burst(pos: Vector2, col: Color, n: int, speed: float, size: float) -> void:
	for i: int in n:
		if _particles.size() >= MAX_PARTICLES:
			_particles.pop_front()
		var a: float = _noise.next_float() * TAU
		var v: float = speed * (0.35 + 0.65 * _noise.next_float())
		_particles.append({"p": pos, "v": Vector2.from_angle(a) * v, "life": 0.0,
			"max": 0.35 + 0.35 * _noise.next_float(), "c": col, "s": size * (0.6 + 0.8 * _noise.next_float()), "rot": a})


func _ring_fx(pos: Vector2, r0: float, r1: float, col: Color, life: float) -> void:
	_rings.append({"p": pos, "r0": r0, "r1": r1, "c": col, "life": 0.0, "max": life})


func _text(pos: Vector2, text: String, col: Color, size: int) -> void:
	if _texts.size() > 6:
		_texts.pop_front()
	_texts.append({"p": pos, "text": text, "c": col, "s": size, "life": 0.0, "max": 0.9})


func _update_fx(delta: float) -> void:
	var d: float = delta * (0.35 if _slowmo_t > 0.0 else 1.0)
	for p: Dictionary in _particles:
		p["life"] = float(p["life"]) + d
		p["p"] = (p["p"] as Vector2) + (p["v"] as Vector2) * d
		p["v"] = (p["v"] as Vector2) * exp(-3.0 * d)
	_particles = _particles.filter(func(p: Dictionary) -> bool: return float(p["life"]) < float(p["max"]))
	for r: Dictionary in _rings:
		r["life"] = float(r["life"]) + d
	_rings = _rings.filter(func(r: Dictionary) -> bool: return float(r["life"]) < float(r["max"]))
	for tx: Dictionary in _texts:
		tx["life"] = float(tx["life"]) + delta
	_texts = _texts.filter(func(tx: Dictionary) -> bool: return float(tx["life"]) < float(tx["max"]))
	for sp: Dictionary in _sparks:
		sp["life"] = float(sp["life"]) - delta
	_sparks = _sparks.filter(func(sp: Dictionary) -> bool: return float(sp["life"]) > 0.0)
	_trauma = maxf(0.0, _trauma - delta * 1.6)
	var amt: float = _trauma * _trauma * 22.0
	_shake = Vector2(_noise.range_f(-1.0, 1.0), _noise.range_f(-1.0, 1.0)) * amt
	_flash.a = maxf(0.0, _flash.a - delta * 1.4)
	_pulse = maxf(0.0, _pulse - delta * 2.2)


# --- Drawing ----------------------------------------------------------------------

func _layout() -> void:
	var h: float = maxf(1.0, size.y - inset_top)
	_scale = minf(size.x / ARENA.x, h / ARENA.y) * zoom
	_origin = Vector2(size.x * 0.5, inset_top + h * 0.5)


func to_screen(p: Vector2) -> Vector2:
	return _origin + _shake + p * _scale


func _enemy_color(i: int) -> Color:
	var en: Array = pal.get("enemies", [Color.WHITE])
	return en[posmod(i, en.size())]


func _apply_view(ci: CanvasItem) -> void:
	ci.draw_set_transform(_origin + _shake, 0.0, Vector2(_scale, _scale))


func _draw() -> void:
	var top: Color = pal.get("top", Color.BLACK)
	var bottom: Color = pal.get("bottom", Color.BLACK)
	var lift: float = _pulse * (0.10 if not _light else 0.05)
	var t2: Color = top.lightened(lift)
	var b2: Color = bottom.lightened(lift)
	# The home demo sits on the screen's own sky, inside a soft rounded panel.
	if not demo:
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]), PackedColorArray([t2, t2, b2, b2]))
	if sim == null:
		return
	_apply_view(self)
	var acc: Color = pal["accent"]
	var ink: Color = Color.WHITE if not _light else Color("141A3C")
	# Range rings: faint guides every 100 units, and the ring's full reach.
	for k: int in range(1, 7):
		draw_arc(Vector2.ZERO, 100.0 * k, 0.0, TAU, 96, Color(ink, 0.035), 2.0, true)
	var reach_a: float = 0.16 if sim.charging else 0.07
	_dashed_circle(self, sim.stats.max_r, Color(acc, reach_a), 2.0, 64)
	# Danger: the core's edge warms up when shapes are close.
	var near: float = INF
	for e: RunSim.Enemy in sim.enemies:
		if e.alive:
			near = minf(near, e.pos.length() - e.radius)
	var danger: float = clampf(1.0 - (near - RunSim.CORE_R) / 140.0, 0.0, 1.0)
	if danger > 0.0:
		draw_arc(Vector2.ZERO, RunSim.CORE_R + 26.0, 0.0, TAU, 48, Color(1.0, 0.3, 0.35, 0.25 * danger * (0.6 + 0.4 * sin(_t * 12.0))), 6.0, true)
	_draw_waves()
	_draw_enemies()
	_draw_core()
	_draw_charge()
	for r: Dictionary in _rings:
		var k: float = float(r["life"]) / float(r["max"])
		var rr: float = lerpf(float(r["r0"]), float(r["r1"]), 1.0 - pow(1.0 - k, 2.0))
		draw_arc(r["p"], rr, 0.0, TAU, 48, Color(r["c"], (r["c"] as Color).a * (1.0 - k)), 4.0 * (1.0 - k) + 1.0, true)
	for p: Dictionary in _particles:
		var k2: float = float(p["life"]) / float(p["max"])
		var s: float = float(p["s"]) * (1.0 - k2 * 0.6)
		var c: Color = Color(p["c"], 1.0 - k2)
		var pos: Vector2 = p["p"]
		var dir: Vector2 = (p["v"] as Vector2).normalized() * s
		draw_line(pos - dir, pos + dir, c, maxf(1.5, s * 0.6), true)
	for sp: Dictionary in _sparks:
		_zigzag(self, sp["a"], sp["b"], Color(1, 1, 1, clampf(float(sp["life"]) / 0.18, 0.0, 1.0)), 3.0)
	draw_set_transform(Vector2.ZERO)


func _dashed_circle(ci: CanvasItem, r: float, col: Color, width: float, segs: int) -> void:
	var n: int = segs
	for i: int in n:
		if i % 2 == 0:
			var a0: float = TAU * float(i) / float(n)
			ci.draw_arc(Vector2.ZERO, r, a0, a0 + TAU / float(n), 4, col, width, true)


func _zigzag(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, width: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array([a])
	var n: int = 6
	var perp: Vector2 = (b - a).orthogonal().normalized()
	for i: int in range(1, n):
		var k: float = float(i) / float(n)
		pts.append(a.lerp(b, k) + perp * sin(float(i) * 2.7 + _t * 40.0) * 9.0)
	pts.append(b)
	ci.draw_polyline(pts, col, width, true)


func _draw_core() -> void:
	var core: Color = pal["core"]
	var acc: Color = pal["accent"]
	var r: float = RunSim.CORE_R
	var beat: float = 1.0 + 0.04 * sin(_t * 5.0) + (0.08 if sim.charging else 0.0)
	var inv: bool = sim.invuln_t > 0.0 and int(_t * 16.0) % 2 == 0
	draw_circle(Vector2.ZERO, r * beat + 6.0, Color(acc, 0.35))
	draw_circle(Vector2.ZERO, r * beat, Color(core, 0.55 if inv else 1.0))
	draw_circle(Vector2.ZERO, r * 0.55 * beat, Color(acc.lerp(core, 0.5), 0.9))
	# Shield pips around the core.
	var n: int = sim.stats.max_lives
	for i: int in n:
		var a: float = -PI / 2.0 + TAU * (float(i) - float(n - 1) / 2.0) / 14.0
		var p: Vector2 = Vector2.from_angle(a) * (r + 15.0)
		var on: bool = i < sim.lives
		draw_circle(p, 5.5, Color(acc, 1.0) if on else Color(acc, 0.18))


func _ring_col(ang: float, base: Color) -> Color:
	return Look.ring_color(ring_style, base, ang, _t)


func _draw_ring(ci: CanvasItem, r: float, base: Color, width: float, alpha: float) -> void:
	var w: float = width * Look.ring_width(ring_style)
	if ring_style == "classic":
		ci.draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(base, alpha), w, true)
		return
	var segs: int = 48
	var dashed: bool = Look.ring_dashed(ring_style)
	for i: int in segs:
		if dashed and i % 2 == 1:
			continue
		var a0: float = TAU * float(i) / float(segs)
		ci.draw_arc(Vector2.ZERO, r, a0, a0 + TAU / float(segs) + 0.01, 3, Color(_ring_col(a0, base), alpha), w, true)


func _draw_charge() -> void:
	if not sim.charging:
		return
	var acc: Color = pal["accent"]
	var r: float = sim.ring_r
	var hot: bool = not sim.perfect_targets(r).is_empty()
	var col: Color = acc.lerp(Color.WHITE, 0.55) if hot else acc
	var width: float = 9.0 if hot else 6.0
	draw_circle(Vector2.ZERO, r, Color(acc, 0.05 + (0.04 if hot else 0.0)))
	_draw_ring(self, r, col, width, 1.0)
	if hot:
		for e: RunSim.Enemy in sim.perfect_targets(r):
			draw_arc(e.pos, e.radius + 10.0, 0.0, TAU, 32, Color(1, 1, 1, 0.8), 3.0, true)


func _draw_waves() -> void:
	var acc: Color = pal["accent"]
	for w: RunSim.Wave in sim.waves:
		if w.done:
			continue
		var col: Color = Color("FFE98A") if w.crit else acc
		var fade: float = 1.0 - 0.5 * clampf((w.r - RunSim.RING_MIN) / maxf(1.0, w.max_r - RunSim.RING_MIN), 0.0, 1.0)
		draw_circle(Vector2.ZERO, w.r, Color(col, 0.05 * fade))
		_draw_ring(self, w.r, col, 12.0, fade)


func _draw_enemies() -> void:
	for e: RunSim.Enemy in sim.enemies:
		if not e.alive:
			continue
		var col: Color = Color("FF5C7A") if e.is_boss else _enemy_color(e.color)
		var alpha: float = 0.25 if e.phased else 1.0
		var fade_in: float = clampf(e.age / 0.3, 0.0, 1.0)
		alpha *= fade_in
		var rot: float = e.age * (0.6 if not e.is_boss else 0.25) * e.spin
		if e.type == EnemyTypes.DASHER:
			rot = e.pos.angle() + PI / 4.0
		var body: Color = Color(col.darkened(0.55), 0.85 * alpha) if not _light else Color(col, 0.22 * alpha)
		if e.hit_flash > 0.0:
			body = Color(1, 1, 1, alpha)
		var r: float = e.radius
		if e.type == EnemyTypes.DASHER and e.mode == 1:
			# Telegraph: a flashing rim and a line to the core.
			var blink: float = 0.5 + 0.5 * sin(_t * 30.0)
			draw_line(e.pos, e.pos.normalized() * (RunSim.CORE_R + 10.0), Color(col, 0.25 * blink), 3.0, true)
			col = col.lerp(Color.WHITE, blink * 0.6)
		if e.is_boss and e.mode == 1:
			var blink2: float = 0.5 + 0.5 * sin(_t * 24.0)
			draw_line(e.pos, e.pos.normalized() * (RunSim.CORE_R + e.radius + 46.0), Color(col, 0.3 * blink2), 6.0, true)
		Shapes.fill(self, e.pos, r, e.sides, rot, body)
		Shapes.outline(self, e.pos, r, e.sides, rot, Color(col, alpha), maxf(2.5, r * 0.15))
		if e.type == EnemyTypes.ORBITER:
			draw_circle(e.pos, r * 0.35, Color(col, alpha))
		if e.type == EnemyTypes.SPAWNER and not e.is_boss:
			draw_circle(e.pos, r * 0.4 * (0.8 + 0.2 * sin(_t * 6.0)), Color(col, 0.7 * alpha))
		if e.type == EnemyTypes.HEAVY:
			Shapes.outline(self, e.pos, r * 0.62, e.sides, rot, Color(col, 0.7 * alpha), 2.0)
		if e.shield:
			var sr: float = r + 9.0
			for k: int in 6:
				var a0: float = _t * 1.5 + TAU * float(k) / 6.0
				draw_arc(e.pos, sr, a0, a0 + 0.7, 6, Color("9FE8FF", 0.9 * alpha), 3.0, true)
		if e.is_boss or (e.max_hp >= 3.0 and e.hp < e.max_hp):
			var w: float = r * 1.6
			var y: float = e.pos.y - r - 14.0
			draw_rect(Rect2(e.pos.x - w / 2.0, y, w, 5.0), Color(0, 0, 0, 0.4 * alpha))
			draw_rect(Rect2(e.pos.x - w / 2.0, y, w * clampf(e.hp / e.max_hp, 0.0, 1.0), 5.0), Color(col, alpha))


## Additive glow pass (skipped on light palettes).
func _draw_glow(ci: CanvasItem) -> void:
	if sim == null or _light:
		return
	_apply_view(ci)
	var tex: Texture2D = Style.glow_texture()
	var acc: Color = pal["accent"]
	var g: float = Look.ring_glow(ring_style)
	ci.draw_texture_rect(tex, Rect2(Vector2(-90, -90), Vector2(180, 180)), false, Color(acc, 0.35))
	if sim.charging:
		var hot: bool = not sim.perfect_targets(sim.ring_r).is_empty()
		_draw_ring(ci, sim.ring_r, acc, 26.0 * g, 0.18 if not hot else 0.32)
	for w: RunSim.Wave in sim.waves:
		if w.done:
			continue
		var col: Color = Color("FFE98A") if w.crit else acc
		_draw_ring(ci, w.r, col, 34.0 * g, 0.16)
	for e: RunSim.Enemy in sim.enemies:
		if e.alive and not e.phased:
			var col2: Color = Color("FF5C7A") if e.is_boss else _enemy_color(e.color)
			var rr: float = e.radius * 2.6
			ci.draw_texture_rect(tex, Rect2(e.pos - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false, Color(col2, 0.22))
	for p: Dictionary in _particles:
		var k: float = float(p["life"]) / float(p["max"])
		var s: float = float(p["s"]) * 3.0
		ci.draw_texture_rect(tex, Rect2((p["p"] as Vector2) - Vector2(s, s), Vector2(s, s) * 2.0), false, Color(p["c"], 0.4 * (1.0 - k)))
	ci.draw_set_transform(Vector2.ZERO)


## Text and flashes on top of everything.
func _draw_top(ci: CanvasItem) -> void:
	if _flash.a > 0.0 and not demo:
		ci.draw_rect(Rect2(Vector2.ZERO, size), _flash)
	if sim == null:
		return
	_apply_view(ci)
	var f: Font = UIKit.font(800)
	# Keep floating text clear of the HUD at the top.
	var min_y: float = (inset_top + 46.0 - _origin.y) / maxf(0.01, _scale)
	for tx: Dictionary in _texts:
		var k: float = float(tx["life"]) / float(tx["max"])
		var fs: int = int(tx["s"])
		var pop: float = 1.0 + 0.25 * maxf(0.0, 1.0 - k * 6.0)
		var text: String = tx["text"]
		var w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * pop)).x
		var pos: Vector2 = (tx["p"] as Vector2) + Vector2(-w / 2.0, -k * 40.0)
		pos.y = maxf(pos.y, min_y)
		pos.x = clampf(pos.x, -ARENA.x * 0.5 + 10.0, ARENA.x * 0.5 - 10.0 - w)
		var col: Color = Color(tx["c"], 1.0 - maxf(0.0, k - 0.6) / 0.4)
		ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * pop), 8, Color(0, 0, 0, 0.45 * col.a))
		ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * pop), col)
	ci.draw_set_transform(Vector2.ZERO)


class GlowLayer:
	extends Node2D
	var arena: ArenaView

	func _draw() -> void:
		arena._draw_glow(self)


class TopLayer:
	extends Node2D
	var arena: ArenaView

	func _draw() -> void:
		arena._draw_top(self)
