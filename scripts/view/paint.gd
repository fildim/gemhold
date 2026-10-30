class_name Paint
extends RefCounted
## Small drawing helpers used by the map views. Call them only from inside a CanvasItem's _draw().

static var _glow_tex: GradientTexture2D


## Stable pseudo-random value in [0, 1) for a tile, so detail does not flicker between redraws.
static func hash01(c: int, r: int, s: int = 0) -> float:
	var x := (c * 374761393 + r * 668265263 + s * 982451653) & 0xFFFFFFFF
	x = ((x ^ (x >> 13)) * 1274126177) & 0xFFFFFFFF
	x = x ^ (x >> 16)
	return float(x & 0xFFFFFFFF) / 4294967296.0


static func ellipse_pts(c: Vector2, rx: float, ry: float, n: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	ci.draw_colored_polygon(ellipse_pts(c, rx, ry), col)


static func ellipse_outline(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var pts := ellipse_pts(c, rx, ry, 28)
	pts.append(pts[0])
	ci.draw_polyline(pts, col, w, true)


## Quadratic bezier from a to b bending toward ctrl, as points (excluding a).
static func quad(a: Vector2, ctrl: Vector2, b: Vector2, n: int = 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(1, n + 1):
		var t := float(i) / n
		pts.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
	return pts


## Filled polygon with colors fading from top_col at its highest point to bottom_col at its lowest.
static func vgrad_poly(ci: CanvasItem, pts: PackedVector2Array, top_col: Color, bottom_col: Color) -> void:
	var y0 := INF
	var y1 := -INF
	for p in pts:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top_col.lerp(bottom_col, 0.0 if y1 == y0 else (p.y - y0) / (y1 - y0)))
	ci.draw_polygon(pts, cols)


## Same, but fading left to right.
static func hgrad_poly(ci: CanvasItem, pts: PackedVector2Array, left_col: Color, right_col: Color) -> void:
	var x0 := INF
	var x1 := -INF
	for p in pts:
		x0 = minf(x0, p.x)
		x1 = maxf(x1, p.x)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(left_col.lerp(right_col, 0.0 if x1 == x0 else (p.x - x0) / (x1 - x0)))
	ci.draw_polygon(pts, cols)


static func rect_pts(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## Soft round glow, brightest at the center.
static func glow(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(0.5, 0.0)
		_glow_tex.width = 64
		_glow_tex.height = 64
	ci.draw_texture_rect(_glow_tex, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


static func gem(ci: CanvasItem, c: Vector2, s: float) -> void:
	var body := PackedVector2Array([c + Vector2(-0.5, -0.7) * s, c + Vector2(0.5, -0.7) * s, c + Vector2(0.9, -0.2) * s,
		c + Vector2(0, 1) * s, c + Vector2(-0.9, -0.2) * s])
	ci.draw_polygon(body, PackedColorArray([Color("ff8aa2"), Color("e0405e"), Color("e0405e"), Color("7a1430"), Color("c0304e")]))
	var outline := body.duplicate()
	outline.append(body[0])
	ci.draw_polyline(outline, Color("3d0816"), maxf(1.0, s * 0.08), true)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.5, -0.7) * s, c + Vector2(0, -0.7) * s,
		c + Vector2(-0.25, -0.2) * s, c + Vector2(-0.9, -0.2) * s]), Color("ffd6df"))
	ci.draw_rect(Rect2(c + Vector2(-0.2, -0.55) * s, Vector2(0.18, 0.18) * s), Color(1, 1, 1, 0.8))
