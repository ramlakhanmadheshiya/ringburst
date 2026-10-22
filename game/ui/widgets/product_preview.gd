class_name ProductPreview
extends Control
## A small live picture of what a shop item gives: themes as sky swatches,
## ring styles as a spinning styled ring, the Supporter heart, the tip jar,
## and the Complete pack as a little of everything.

var product: String = ""
var _t: float = 0.0


func _init(id: String = "", px: float = 96.0) -> void:
	product = id
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var o: Vector2 = (size - Vector2(s, s)) / 2.0
	var box: Rect2 = Rect2(o, Vector2(s, s))
	draw_style_box(UIKit.box(Color(0, 0, 0, 0.28), int(s * 0.26)), box)
	var c: Vector2 = box.get_center()
	if product == "tips":
		_art("heart", c, s * 0.6)
	elif product == "theme_pack":
		_art("theme", c, s * 0.7)
	elif product == "style_pack":
		var ids: Array = ["neon", "plasma", "prism", "aurora"]
		var id: String = ids[int(_t * 0.8) % ids.size()]
		var r: float = s * 0.28
		draw_circle(c, s * 0.08, Color("E9FDFF"))
		var segs: int = 40
		for i: int in segs:
			var a0: float = TAU * float(i) / float(segs) + _t
			draw_arc(c, r, a0, a0 + TAU / float(segs) + 0.02, 3, Look.ring_color(id, Style.AMBER, a0, _t), s * 0.07, true)
	elif product == "supporter_pack":
		_art("ring", c + Vector2(-s * 0.06, -s * 0.04), s * 0.66)
		_art("heart", c + Vector2(s * 0.24, s * 0.24), s * 0.32)
	else:
		_art("ring", c + Vector2(-s * 0.12, -s * 0.06), s * 0.6)
		_art("theme", c + Vector2(s * 0.2, s * 0.2), s * 0.4)
		_art("star", c + Vector2(s * 0.24, -s * 0.24), s * 0.3)


func _art(name: String, c: Vector2, px: float) -> void:
	draw_texture_rect(UIKit.art(name), Rect2(c - Vector2(px, px) / 2.0, Vector2(px, px)), false)
