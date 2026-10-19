class_name Shapes
extends RefCounted
## Drawing helpers for the flat geometric shapes, shared by the arena, the
## backdrop, the cards and the share picture. sides 0 = circle.

static var _cache: Dictionary = {}


## Unit polygon (radius 1) for a number of sides, cached.
static func unit(sides: int) -> PackedVector2Array:
	if _cache.has(sides):
		return _cache[sides]
	var n: int = 24 if sides <= 0 else sides
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in n:
		var a: float = -PI / 2.0 + TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)))
	_cache[sides] = pts
	return pts


static func points(c: Vector2, r: float, sides: int, rot: float) -> PackedVector2Array:
	var out: PackedVector2Array = unit(sides).duplicate()
	var cs: float = cos(rot)
	var sn: float = sin(rot)
	for i: int in out.size():
		var v: Vector2 = out[i]
		out[i] = c + Vector2(v.x * cs - v.y * sn, v.x * sn + v.y * cs) * r
	return out


static func fill(ci: CanvasItem, c: Vector2, r: float, sides: int, rot: float, col: Color) -> void:
	if sides <= 0:
		ci.draw_circle(c, r, col)
	else:
		ci.draw_colored_polygon(points(c, r, sides, rot), col)


static func outline(ci: CanvasItem, c: Vector2, r: float, sides: int, rot: float, col: Color, width: float) -> void:
	if sides <= 0:
		ci.draw_arc(c, r, 0.0, TAU, 32, col, width, true)
		return
	var pts: PackedVector2Array = points(c, r, sides, rot)
	pts.append(pts[0])
	ci.draw_polyline(pts, col, width, true)


## A neon shape: soft glow, dark-ish body, bright rim (used everywhere a
## shape is shown outside the arena).
static func neon(ci: CanvasItem, c: Vector2, r: float, sides: int, rot: float, col: Color, light: bool = false) -> void:
	var glow: Texture2D = Style.glow_texture()
	if not light:
		ci.draw_texture_rect(glow, Rect2(c - Vector2(r, r) * 2.2, Vector2(r, r) * 4.4), false, Color(col, 0.35))
	fill(ci, c, r, sides, rot, Color(col.darkened(0.55), 0.9) if not light else Color(col, 0.22))
	outline(ci, c, r, sides, rot, col, maxf(2.0, r * 0.16))
