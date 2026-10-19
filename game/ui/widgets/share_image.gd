class_name ShareImage
extends Control
## The picture players share after a run, like Single Shot's: a burst frozen
## in the world's colours, the score and best combo, the stars (campaign),
## the upgrades that made the run, and a QR code and link to the game.
## Rendered off-screen at 1080 x 1350 (4:5, the shape chat apps show best).

const SIZE: Vector2i = Vector2i(1080, 1350)
const SITE: String = "theramlakhan.com/ringburst"

var info: Dictionary = {}


## Renders the picture for `data` and calls back with an Image (null where
## nothing can be rendered, e.g. headless).
static func render(host: Node, data: Dictionary, done: Callable) -> void:
	if DisplayServer.get_name() == "headless":
		done.call(null)
		return
	var vp: SubViewport = SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	var card: ShareImage = ShareImage.new()
	card.info = data
	card.size = Vector2(SIZE)
	vp.add_child(card)
	host.add_child(vp)
	for i: int in 6:
		await RenderingServer.frame_post_draw
	if not is_instance_valid(vp):
		return
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	done.call(img)


func _pal() -> Dictionary:
	return Look.arena(int(info.get("world", 0)))


func _ready() -> void:
	var pal: Dictionary = _pal()
	var light: bool = bool(pal["light"])
	var ink: Color = Color("141A3C") if light else Color("F2F4FF")
	var muted: Color = Color(ink, 0.65)
	var accent: Color = pal["accent"]
	var icon: TextureRect = TextureRect.new()
	icon.texture = load("res://assets/icon.svg")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	icon.position = Vector2(72, 60)
	icon.size = Vector2(104, 104)
	add_child(icon)
	_label("Ringburst", 60, ink, 800, Vector2(196, 72), Vector2(480, 80))
	var mode: String = str(info.get("mode", "stage"))
	var head: String = "Daily Run" if mode == "daily" else ("Endless" if mode == "endless" else ("Stage clear" if bool(info.get("won", false)) else "Run"))
	_label(head, 36, accent, 800, Vector2(560, 66), Vector2(448, 50), HORIZONTAL_ALIGNMENT_RIGHT)
	var sub: String = str(info.get("date", "")) if mode == "daily" else (str(info.get("time_text", "")) if mode == "endless" else str(info.get("where", "")))
	_label(sub, 28, muted, 600, Vector2(460, 116), Vector2(548, 44), HORIZONTAL_ALIGNMENT_RIGHT)
	# Score block under the burst.
	_label(_thousands(int(info.get("score", 0))), 120, ink, 800, Vector2(0, 760), Vector2(1080, 140))
	_label("POINTS", 28, muted, 700, Vector2(0, 890), Vector2(1080, 40))
	var stats: String = "%d combo  ·  %d perfects  ·  %d shapes" % [int(info.get("combo", 0)), int(info.get("perfects", 0)), int(info.get("kills", 0))]
	_label(stats, 32, ink, 600, Vector2(0, 940), Vector2(1080, 50))
	if mode == "stage":
		var stars: StarRow = StarRow.new()
		stars.position = Vector2(0, 990)
		stars.size = Vector2(1080, 110)
		add_child(stars)
		stars.show_now(int(info.get("mask", 0)))
	elif mode == "daily":
		var mod: String = str(info.get("modifier", ""))
		if Worlds.MODIFIERS.has(mod):
			_label("Today: " + str(Worlds.MODIFIERS[mod]["name"]), 34, accent, 700, Vector2(0, 1010), Vector2(1080, 56))
	# The upgrades that made the run.
	var ups: Dictionary = info.get("upgrades", {})
	var ids: Array = ups.keys()
	var n: int = mini(ids.size(), 9)
	var x0: float = 540.0 - float(n) * 46.0
	for i: int in n:
		var id: String = ids[i]
		var ic: TextureRect = UIKit.icon_rect(str(Upgrades.def(id).get("icon", "zap")), 56, accent)
		ic.position = Vector2(x0 + float(i) * 92.0 + 18.0, 1112)
		ic.size = Vector2(56, 56)
		add_child(ic)
	_label("Can you beat it?", 36, ink, 700, Vector2(72, 1236), Vector2(760, 50), HORIZONTAL_ALIGNMENT_LEFT)
	_label(SITE, 30, accent, 700, Vector2(72, 1282), Vector2(760, 44), HORIZONTAL_ALIGNMENT_LEFT)
	var qr: TextureRect = TextureRect.new()
	qr.texture = load("res://assets/share/qr.png")
	qr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	qr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	qr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	qr.position = Vector2(880, 1206)
	qr.size = Vector2(128, 128)
	add_child(qr)


static func _thousands(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func _label(text: String, fs: int, col: Color, weight: int, pos: Vector2, sz: Vector2, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var l: Label = UIKit.label(text, fs, col, weight, align)
	l.position = pos
	l.size = sz
	l.clip_text = true
	add_child(l)


func _draw() -> void:
	var pal: Dictionary = _pal()
	var top: Color = pal["top"]
	var bottom: Color = pal["bottom"]
	var light: bool = bool(pal["light"])
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]), PackedColorArray([top, top, bottom, bottom]))
	# A burst frozen mid-flight: core, wave, shapes shattering on the edge.
	var c: Vector2 = Vector2(540, 470)
	var acc: Color = pal["accent"]
	var en: Array = pal["enemies"]
	var glow: Texture2D = Style.glow_texture()
	var rng: Rng = Rng.new(int(info.get("score", 7)) + 3)
	for k: int in range(1, 4):
		draw_arc(c, 90.0 * k, 0.0, TAU, 96, Color(Color.WHITE if not light else Color("141A3C"), 0.05), 2.0, true)
	if not light:
		draw_texture_rect(glow, Rect2(c - Vector2(330, 330), Vector2(660, 660)), false, Color(acc, 0.25))
	draw_circle(c, 220.0, Color(acc, 0.06))
	draw_arc(c, 220.0, 0.0, TAU, 160, Color(acc, 0.35), 34.0, true)
	draw_arc(c, 220.0, 0.0, TAU, 160, acc.lerp(Color.WHITE, 0.5), 12.0, true)
	for i: int in 9:
		var ang: float = TAU * float(i) / 9.0 + rng.range_f(-0.2, 0.2)
		var d: float = rng.range_f(200.0, 300.0)
		var p: Vector2 = c + Vector2.from_angle(ang) * d
		var col: Color = en[i % en.size()]
		var sides: int = [3, 4, 6, 0, 5][i % 5]
		if absf(d - 220.0) < 30.0:
			for k: int in 6:
				var a2: float = rng.next_float() * TAU
				var q: Vector2 = p + Vector2.from_angle(a2) * rng.range_f(14.0, 44.0)
				draw_line(q, q + Vector2.from_angle(a2) * 14.0, col, 5.0, true)
		else:
			Shapes.neon(self, p, 26.0, sides, ang, col, light)
	draw_circle(c, 56.0, Color(acc, 0.4))
	draw_circle(c, 44.0, pal["core"])
	draw_circle(c, 24.0, acc.lerp(pal["core"], 0.5))
	draw_line(Vector2(72, 1214), Vector2(840, 1214), Color(Color.WHITE if not light else Color("141A3C"), 0.14), 2.0, true)
