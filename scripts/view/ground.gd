extends Node2D
## Draws everything on the map that rarely changes: terrain, roads, woods and the lair.
## Redraws only when woods are cleared.

const T := 64.0
const TERRAIN_COL := {
	"moss": Color8(78, 108, 50), "frost": Color8(184, 204, 214),
	"ash": Color8(86, 60, 52), "lair": Color8(72, 60, 52), "high": Color8(118, 106, 92),
}

var level: Level
var sim: GameSim
var _blend: ImageTexture


func setup(lv: Level, s: GameSim) -> void:
	level = lv
	sim = s
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_build_blend()
	sim.ground_changed.connect(queue_redraw)
	queue_redraw()


## One pixel per tile (plus a border), stretched with smoothing so terrain zones melt into each other.
func _build_blend() -> void:
	var img := Image.create(level.cols + 2, level.rows + 2, false, Image.FORMAT_RGBA8)
	for c in range(-1, level.cols + 1):
		for r in range(-1, level.rows + 1):
			var cc := clampi(c, 0, level.cols - 1)
			var rr := clampi(r, 0, level.rows - 1)
			var base: Color = TERRAIN_COL[level.terrain_at(Vector2i(cc, rr))]
			var k := 0.9 + Paint.hash01(cc, rr, 1) * 0.18
			img.set_pixel(c + 1, r + 1, Color(base.r * k, base.g * k, base.b * k))
	_blend = ImageTexture.create_from_image(img)


func _draw() -> void:
	if level == null:
		return
	var W := level.cols * T
	var H := level.rows * T
	draw_texture_rect_region(_blend, Rect2(0, 0, W, H), Rect2(1, 1, level.cols, level.rows))
	_draw_details()
	_draw_cliffs()
	_draw_roads()
	var cells: Array = sim.trees.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
	for c: Vector2i in cells:
		var tt := level.terrain_at(c)
		_draw_tree(c, "moss" if tt == "high" else tt)
	_draw_lair()
	_draw_vignette(W, H)


func _draw_details() -> void:
	for c in level.cols:
		for r in level.rows:
			var t := level.terrain_at(Vector2i(c, r))
			if t == "lair":
				continue
			var o := Vector2(c, r) * T
			for i in 7:
				var p := o + Vector2(Paint.hash01(c, r, i + 50), Paint.hash01(c, r, i + 70)) * T
				var v := Paint.hash01(c, r, i + 90)
				match t:
					"moss":
						var col := Color("2f4a1f") if v < 0.5 else Color("8fb35a")
						draw_line(p, p + Vector2(-0.04, -0.09) * T, col, 2.0, true)
						draw_line(p, p + Vector2(0.03, -0.1) * T, col, 2.0, true)
						if v > 0.9:
							draw_circle(p + Vector2(0, -0.05) * T, T * 0.035, Color("f2e27a") if i % 2 else Color("f4f0e6"))
					"frost":
						if i < 3:
							Paint.ellipse(self, p, T * (0.12 + v * 0.12), T * (0.05 + v * 0.04), Color(1, 1, 1, 0.33))
						elif v > 0.6:
							draw_rect(Rect2(p, Vector2(2, 2)), Color.WHITE)
						if i == 6 and v > 0.5:
							draw_polyline(PackedVector2Array([p, p + Vector2(0.15, 0.05) * T, p + Vector2(0.22, 0.14) * T]), Color(0.5, 0.66, 0.74, 0.55), 1.5, true)
					"high":
						if i < 3:
							Paint.ellipse(self, p, T * (0.06 + v * 0.06), T * (0.04 + v * 0.03), Color("8e8272"))
							Paint.ellipse(self, p + Vector2(-0.01, -0.012) * T, T * (0.04 + v * 0.04), T * (0.025 + v * 0.02), Color("b0a490"))
						elif v > 0.7:
							draw_line(p, p + Vector2(0.1, 0.03) * T, Color("4e443a"), 1.5, true)
					"ash":
						if i < 2:
							var crack := PackedVector2Array([p, p + Vector2(0.12, 0.06) * T, p + Vector2(0.18, 0.16) * T])
							draw_polyline(crack, Color("2a1a16"), 2.0, true)
							if v > 0.5:
								draw_polyline(crack, Color(1, 0.42, 0.16, 0.4), 1.0, true)
						elif v > 0.75:
							draw_circle(p, T * 0.022, Color("ff8a3a"))
						elif v < 0.3:
							Paint.ellipse(self, p, T * 0.05, T * 0.035, Color("6e5a52"))


func _road_pts(wp: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for v: Vector2i in wp:
		pts.append((Vector2(v) + Vector2(0.5, 0.5)) * T)
	pts.append(level.lair_center * T)
	return pts


## Thick line with round joints and ends.
func _stroke(pts: PackedVector2Array, col: Color, w: float) -> void:
	draw_polyline(pts, col, w)
	for p in pts:
		draw_circle(p, w * 0.5, col)


func _draw_roads() -> void:
	var layers := [[Color(0, 0, 0, 0.25), 0.98], [Color("5c4128"), 0.86], [Color("a47e4e"), 0.72], [Color("b8925e"), 0.3]]
	for layer in layers:
		for wp in level.waypoints:
			_stroke(_road_pts(wp), layer[0], T * layer[1])
	for cell: Vector2i in level.road:
		for i in 6:
			var p := (Vector2(cell) + Vector2(0.5, 0.5) + Vector2(Paint.hash01(cell.x, cell.y, i + 20) - 0.5, Paint.hash01(cell.x, cell.y, i + 30) - 0.5) * 0.6) * T
			var col := Color(0.48, 0.35, 0.2, 0.4) if i % 3 else Color(0.85, 0.73, 0.54, 0.53)
			draw_circle(p, T * (0.025 + Paint.hash01(cell.x, cell.y, i + 40) * 0.03), col)


func _draw_tree(cell: Vector2i, t: String) -> void:
	var n := 3 if Paint.hash01(cell.x, cell.y, 44) > 0.5 else 2
	var spots: Array[Vector2] = []
	for i in n:
		spots.append(Vector2(cell.x * T + T * (0.22 + float(i) / (n - 1) * 0.56) + (Paint.hash01(cell.x, cell.y, 40 + i) - 0.5) * T * 0.14,
			cell.y * T + T * (0.5 + Paint.hash01(cell.x, cell.y, 60 + i) * 0.3)))
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	for o in spots:
		Paint.ellipse(self, o + Vector2(0.04, 0.06) * T, T * 0.2, T * 0.07, Color(0, 0, 0, 0.27))
		match t:
			"moss":
				draw_rect(Rect2(o + Vector2(-0.035, -0.12) * T, Vector2(0.07, 0.18) * T), Color("4a2f1c"))
				draw_circle(o + Vector2(0, -0.24) * T, T * 0.2, Color("1d3816"))
				draw_circle(o + Vector2(-0.12, -0.16) * T, T * 0.13, Color("1d3816"))
				draw_circle(o + Vector2(0.12, -0.16) * T, T * 0.13, Color("1d3816"))
				draw_circle(o + Vector2(-0.03, -0.28) * T, T * 0.15, Color("2f5a22"))
				draw_circle(o + Vector2(-0.07, -0.33) * T, T * 0.07, Color("4f8236"))
			"frost":
				draw_rect(Rect2(o + Vector2(-0.03, -0.06) * T, Vector2(0.06, 0.1) * T), Color("4a3424"))
				for k in 3:
					var ty := o.y - T * (0.05 + k * 0.15)
					var w := T * (0.2 - k * 0.05)
					var tip := Vector2(o.x, ty - T * 0.24)
					draw_colored_polygon(PackedVector2Array([tip, Vector2(o.x + w, ty), Vector2(o.x - w, ty)]), Color("2c5450") if k % 2 else Color("244844"))
					var cap := PackedVector2Array([tip, Vector2(o.x + w * 0.55, ty - T * 0.1)])
					cap.append_array(Paint.quad(Vector2(o.x + w * 0.55, ty - T * 0.1), Vector2(o.x, ty - T * 0.06), Vector2(o.x - w * 0.55, ty - T * 0.1), 5))
					draw_colored_polygon(cap, Color("f4fafc"))
			_:
				var w := maxf(2.0, T * 0.055)
				var trunk := PackedVector2Array([o + Vector2(0, 0.04) * T])
				trunk.append_array(Paint.quad(o + Vector2(0, 0.04) * T, o + Vector2(-0.03, -0.2) * T, o + Vector2(0.02, -0.42) * T))
				draw_polyline(trunk, Color("1c1210"), w, true)
				var b1 := PackedVector2Array([o + Vector2(0, -0.16) * T])
				b1.append_array(Paint.quad(o + Vector2(0, -0.16) * T, o + Vector2(0.12, -0.22) * T, o + Vector2(0.18, -0.36) * T))
				draw_polyline(b1, Color("1c1210"), w * 0.8, true)
				var b2 := PackedVector2Array([o + Vector2(-0.01, -0.26) * T])
				b2.append_array(Paint.quad(o + Vector2(-0.01, -0.26) * T, o + Vector2(-0.12, -0.3) * T, o + Vector2(-0.16, -0.42) * T))
				draw_polyline(b2, Color("1c1210"), w * 0.8, true)
				draw_circle(o + Vector2(0.01, -0.08) * T, T * 0.018, Color("ff7a3a"))


func _draw_lair() -> void:
	var c := level.lair_center * T
	Paint.ellipse(self, c + Vector2(0, 0.75) * T, T * 1.1, T * 0.32, Color(0, 0, 0, 0.33))
	var hill := PackedVector2Array()
	for v in [Vector2(-1.05, 0.85), Vector2(-0.9, -0.2), Vector2(-0.45, -0.75), Vector2(-0.05, -0.95), Vector2(0.4, -0.7), Vector2(0.85, -0.35), Vector2(1.05, 0.85)]:
		hill.append(c + v * T)
	Paint.vgrad_poly(self, hill, Color("8a7a6c"), Color("3d322b"))
	draw_line(c + Vector2(-0.45, -0.75) * T, c + Vector2(-0.3, -0.3) * T, Color("2a221c"), 2.0, true)
	draw_line(c + Vector2(0.4, -0.7) * T, c + Vector2(0.55, -0.1) * T, Color("2a221c"), 2.0, true)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-0.45, -0.75) * T, c + Vector2(-0.05, -0.95) * T, c + Vector2(0.12, -0.82) * T, c + Vector2(-0.2, -0.7) * T]), Color(0.91, 0.93, 0.95, 0.4))
	var mouth := PackedVector2Array([c + Vector2(-0.6, 0.8) * T, c + Vector2(-0.6, 0.05) * T])
	mouth.append_array(Paint.quad(c + Vector2(-0.6, 0.05) * T, c + Vector2(0, -0.65) * T, c + Vector2(0.6, 0.05) * T, 12))
	mouth.append(c + Vector2(0.6, 0.8) * T)
	draw_colored_polygon(mouth, Color("0c0807"))
	Paint.glow(self, c + Vector2(0, 0.4) * T, T * 0.8, Color(0.88, 0.25, 0.37, 0.35))


func _draw_vignette(W: float, H: float) -> void:
	var dark := Color(0, 0, 0, 0.42)
	var clear := Color(0, 0, 0, 0)
	var e := T * 1.4
	Paint.vgrad_poly(self, Paint.rect_pts(Rect2(0, 0, W, e)), dark, clear)
	Paint.vgrad_poly(self, Paint.rect_pts(Rect2(0, H - e, W, e)), clear, dark)
	Paint.hgrad_poly(self, Paint.rect_pts(Rect2(0, 0, e, H)), dark, clear)
	Paint.hgrad_poly(self, Paint.rect_pts(Rect2(W - e, 0, e, H)), clear, dark)


## High ground: a lit top edge and a shadowed cliff face wherever it drops to lower land.
func _draw_cliffs() -> void:
	for cell: Vector2i in level.terrain:
		if level.terrain[cell] != "high":
			continue
		var o := Vector2(cell) * T
		var low := func(d: Vector2i) -> bool: return level.in_bounds(cell + d) and level.terrain_at(cell + d) != "high"
		if low.call(Vector2i(0, 1)):
			Paint.vgrad_poly(self, Paint.rect_pts(Rect2(o + Vector2(0, T * 0.82), Vector2(T, T * 0.18))), Color("4a4036"), Color("2a231c"))
		if low.call(Vector2i(0, -1)):
			draw_line(o, o + Vector2(T, 0), Color(1, 0.95, 0.85, 0.35), 2.0)
		if low.call(Vector2i(-1, 0)):
			draw_line(o, o + Vector2(0, T), Color(0, 0, 0, 0.3), 3.0)
		if low.call(Vector2i(1, 0)):
			draw_line(o + Vector2(T, 0), o + Vector2(T, T), Color(0, 0, 0, 0.3), 3.0)
