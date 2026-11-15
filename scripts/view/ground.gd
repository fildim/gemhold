extends Node2D
## Draws everything on the map that rarely changes: terrain, roads, woods and the lair.
## Redraws only when woods are cleared.

const T := 64.0
const GROUND_SHADER := preload("res://scripts/view/ground.gdshader")
## Which channel of the ground texture each terrain fills (lair: none). Alpha marks raised tiles;
## see ground.gdshader.
const TERRAIN_MASK := {
	"moss": Color(1, 0, 0, 0), "frost": Color(0, 1, 0, 0), "ash": Color(0, 0, 1, 0),
	"lair": Color(0, 0, 0, 0), "water": Color(1, 0, 0, 0), "shallows": Color(1, 0, 0, 0),   # water: its own mask (below), moss under it
}

## The ground shader is costly, so it is rendered once per level into a texture at this many
## pixels per map unit, and that picture is what gets drawn each frame.
const BAKE_SCALE := 2.0

var level: Level
var sim: GameSim
var _bake: SubViewport   # renders the ground shader once
var _shaded: Sprite2D    # inside _bake: the terrain texture run through ground.gdshader
var _base: Sprite2D      # the baked ground, drawn behind everything else here
var biome := 0             # chapter look for the shader: 0 lowland, 1 crusade, 2 marsh, 3 siege mud (set by main)
var _ripples: Sprite2D   # animated highlights over water (water_fx.gdshader), above the baked ground


func setup(lv: Level, s: GameSim) -> void:
	level = lv
	sim = s
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_build_base()
	sim.ground_changed.connect(queue_redraw)
	queue_redraw()


## One pixel per tile (plus a border) saying which terrain it is; the shader turns it into ground.
func _build_base() -> void:
	var img := Image.create(level.cols + 2, level.rows + 2, false, Image.FORMAT_RGBA8)
	var wimg := Image.create(level.cols + 2, level.rows + 2, false, Image.FORMAT_RGBA8)
	for c in range(-1, level.cols + 1):
		for r in range(-1, level.rows + 1):
			var cc := clampi(c, 0, level.cols - 1)
			var rr := clampi(r, 0, level.rows - 1)
			var px: Color = TERRAIN_MASK[level.terrain_at(Vector2i(cc, rr))]
			px.a = 1.0 if level.high.has(Vector2i(c, r)) else 0.0
			img.set_pixel(c + 1, r + 1, px)
			var wt := level.terrain_at(Vector2i(cc, rr))
			wimg.set_pixel(c + 1, r + 1, Color(1.0 if wt == "water" else 0.0, 1.0 if wt == "shallows" else 0.0, 0, 1))
	if _bake == null:
		_bake = SubViewport.new()
		_bake.disable_3d = true
		_shaded = Sprite2D.new()
		_shaded.centered = false
		_shaded.region_enabled = true
		_shaded.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_shaded.material = ShaderMaterial.new()
		_shaded.material.shader = GROUND_SHADER
		_bake.add_child(_shaded)
		add_child(_bake)
		_base = Sprite2D.new()
		_base.centered = false
		_base.show_behind_parent = true
		_base.texture = _bake.get_texture()
		_base.scale = Vector2.ONE / BAKE_SCALE
		add_child(_base)
	_bake.size = Vector2i(Vector2(level.cols, level.rows) * T * BAKE_SCALE)
	var tex := ImageTexture.create_from_image(img)
	var wtex := ImageTexture.create_from_image(wimg)
	_shaded.texture = tex
	_shaded.material.set_shader_parameter("terrain_mask", tex)
	_shaded.material.set_shader_parameter("water_mask", wtex)
	_shaded.material.set_shader_parameter("biome", biome)
	_build_ripples(wtex)
	_shaded.region_rect = Rect2(1, 1, level.cols, level.rows)
	_shaded.scale = Vector2(T, T) * BAKE_SCALE
	_shaded.material.set_shader_parameter("grid", Vector2(level.cols, level.rows))
	_bake.render_target_update_mode = SubViewport.UPDATE_ONCE


func _draw() -> void:
	if level == null:
		return
	var W := level.cols * T
	var H := level.rows * T
	_draw_details()
	_draw_roads()
	_draw_crossings()
	_draw_reeds()
	var cells: Array = sim.trees.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
	for c: Vector2i in cells:
		var tt := level.terrain_at(c)
		_draw_tree(c, tt)
	_draw_lair()
	_draw_vignette(W, H)


func _draw_details() -> void:
	for c in level.cols:
		for r in level.rows:
			var t := level.terrain_at(Vector2i(c, r))
			if t == "lair" or t == "water" or t == "shallows" or level.high.has(Vector2i(c, r)):   # raised tiles are bare stone; water has no grass
				continue
			var o := Vector2(c, r) * T
			# Kept off the tile's rim, where the shader may already show the neighbouring ground.
			var span := Vector2(0.7, 0.7)
			for i in 7:
				var p := o + (Vector2(0.15, 0.15) + Vector2(Paint.hash01(c, r, i + 50), Paint.hash01(c, r, i + 70)) * span) * T
				var v := Paint.hash01(c, r, i + 90)
				match t:
					"moss":
						var col := Color("2f4a1f") if v < 0.5 else Color("8fb35a")
						draw_line(p, p + Vector2(-0.04, -0.09) * T, col, 2.0, true)
						draw_line(p, p + Vector2(0.03, -0.1) * T, col, 2.0, true)
						if v > 0.9:
							draw_circle(p + Vector2(0, -0.05) * T, T * 0.035, Color("f2e27a") if i % 2 else Color("f4f0e6"))
					"frost":
						if v > 0.6:
							draw_rect(Rect2(p, Vector2(2, 2)), Color.WHITE)
					"ash":
						if v > 0.8:
							draw_circle(p, T * 0.022, Color("ff8a3a"))
						elif v < 0.3:
							Paint.ellipse(self, p, T * 0.05, T * 0.035, Color("5e4a42"))


## Points every `step` tiles along road i, with the road's direction there.
func _road_samples(i: int, step: float) -> Array:
	var out := []
	var total: float = level.paths[i]["total"]
	var s := 0.0
	while s <= total:
		var a := level.path_pos(i, s)
		var b := level.path_pos(i, minf(total, s + 0.05))
		var d := (b - a).normalized() if b != a else Vector2.RIGHT
		out.append([s, a, d])
		s += step
	return out


## Roads are stamped as overlapping discs whose size and position drift a little, so the edges
## wander like a worn dirt track.
func _draw_roads() -> void:
	var layers := [[Color("4a3420"), 0.92], [Color("5c4128"), 0.84], [Color("a47e4e"), 0.72], [Color("b8925e"), 0.3]]
	for li in layers.size():
		for i in level.paths.size():
			if level.path_kind[i] == "air":
				continue   # flight lines are drawn by the board
			for smp in _road_samples(i, 0.08):
				var s: float = smp[0]
				if _wet(i, smp[1], s):
					continue
				var wob := (sin(s * 2.1 + i * 1.7) + sin(s * 5.3 + i * 3.1 + li)) * 0.5
				var side := sin(s * 3.7 + i * 2.3) * 0.025
				var c: Vector2 = (smp[1] + smp[2].orthogonal() * side) * T
				draw_circle(c, T * layers[li][1] * 0.5 * (1.0 + 0.07 * wob), layers[li][0])
	for i in level.paths.size():
		if level.path_kind[i] == "air":
			continue
		for smp in _road_samples(i, 0.3):
			var s: float = smp[0]
			if _wet(i, smp[1], s):
				continue
			var k := int(s * 10.0) + i * 1000
			for j in 2:
				var off := (Paint.hash01(k, j, 20) - 0.5) * 0.55
				var along := (Paint.hash01(k, j, 30) - 0.5) * 0.3
				var p: Vector2 = (smp[1] + smp[2].orthogonal() * off + smp[2] * along) * T
				var col := Color(0.48, 0.35, 0.2, 0.4) if (k + j) % 3 else Color(0.85, 0.73, 0.54, 0.53)
				draw_circle(p, T * (0.025 + Paint.hash01(k, j, 40) * 0.03), col)


## True where road i is over water at p (distance s): a river before its landing, or a crossing.
func _wet(i: int, p: Vector2, s: float) -> bool:
	if level.path_kind[i] == "river":
		return s < float(level.landings[i])
	return level.is_water(Vector2i(floori(p.x), floori(p.y)))


## Bridges as plank decks with rails (broken stumps once collapsed), fords as stepping stones.
func _draw_crossings() -> void:
	for i in level.paths.size():
		if level.path_kind[i] != "land":
			continue
		for smp in _road_samples(i, 0.11):
			var p: Vector2 = smp[1]
			var cell := Vector2i(floori(p.x), floori(p.y))
			if not level.crossings.has(cell):
				continue
			var d: Vector2 = smp[2]
			var n := d.orthogonal()
			var c := p * T
			if level.crossing_kind[level.crossings[cell]] == "bridge":
				if sim.collapsed.has(cell):
					if Paint.hash01(int(smp[0] * 9.0), i, 3) < 0.18:   # a few broken stumps
						draw_line(c + n * T * 0.3, c + n * T * 0.3 + Vector2(0, -0.08) * T, Color("3a2414"), 4.0)
					continue
				draw_line(c - n * T * 0.36, c + n * T * 0.36, Color("6a4628") if int(smp[0] * 9.0) % 2 else Color("7a5432"), T * 0.1)
				draw_circle(c + n * T * 0.38, 2.5, Color("3a2414"))
				draw_circle(c - n * T * 0.38, 2.5, Color("3a2414"))
			elif int(smp[0] * 9.0) % 3 == 0:
				var j := (Paint.hash01(int(smp[0] * 9.0), i, 5) - 0.5) * 0.3
				Paint.ellipse(self, c + n * T * j, T * 0.13, T * 0.09, Color("8a8478"))
				Paint.ellipse(self, c + n * T * j + Vector2(0, -2), T * 0.1, T * 0.06, Color("aaa396"))


## Reeds along the water's edge.
func _draw_reeds() -> void:
	for c: Vector2i in level.terrain:
		if level.is_water(c) or level.road.has(c) or level.is_lair(c) or sim.trees.has(c) or level.high.has(c):
			continue
		var shore := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			shore = shore or level.is_water(c + d)
		if not shore:
			continue
		for k in 4:
			var q := (Vector2(c) + Vector2(0.15 + Paint.hash01(c.x, c.y, k + 7) * 0.7, 0.35 + Paint.hash01(c.x, c.y, k + 17) * 0.6)) * T
			var h := T * (0.16 + Paint.hash01(c.x, c.y, k + 27) * 0.14)
			draw_line(q, q + Vector2(-2, -h), Color("5a6a34"), 2.0, true)
			draw_line(q + Vector2(3, 0), q + Vector2(5, -h * 0.8), Color("6e7c3e"), 2.0, true)
			if k == 0:
				Paint.ellipse(self, q + Vector2(-2, -h), 2.5, 5.0, Color("6a4a26"))


## Two to four trees of varied size, scattered a little past their tile so woods read as forest
## rather than rows.
func _draw_tree(cell: Vector2i, t: String) -> void:
	var n := 2 + int(Paint.hash01(cell.x, cell.y, 44) * 3.0)
	var spots: Array[Vector2] = []
	for i in n:
		var fx := (float(i) + Paint.hash01(cell.x, cell.y, 40 + i)) / n
		spots.append(Vector2(cell.x * T + T * (0.05 + fx * 0.9), cell.y * T + T * (0.4 + Paint.hash01(cell.x, cell.y, 60 + i) * 0.5)))
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	for ti in spots.size():
		var o := spots[ti]
		var sc := 0.78 + Paint.hash01(cell.x, cell.y, 80 + ti) * 0.42
		draw_set_transform(o * (1.0 - sc), 0.0, Vector2(sc, sc))   # scale this tree about its foot
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
	draw_set_transform(Vector2.ZERO)


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



## Moving light on the water: one quad over the map with an animated shader, drawn only where
## the water mask says there is water. Cheap: no redraw of the ground.
func _build_ripples(wtex: Texture2D) -> void:
	var any := false
	for c: Vector2i in level.terrain:
		any = any or level.is_water(c)
	if not any:
		if _ripples:
			_ripples.visible = false
		return
	if _ripples == null:
		_ripples = Sprite2D.new()
		_ripples.centered = false
		_ripples.region_enabled = true
		_ripples.show_behind_parent = true   # over the ground picture, under roads and woods
		_ripples.material = ShaderMaterial.new()
		_ripples.material.shader = preload("res://scripts/view/water_fx.gdshader")
		add_child(_ripples)
	_ripples.visible = true
	_ripples.texture = wtex
	_ripples.region_rect = Rect2(1, 1, level.cols, level.rows)
	_ripples.scale = Vector2(T, T)
	_ripples.material.set_shader_parameter("water_mask", wtex)
	_ripples.material.set_shader_parameter("grid", Vector2(level.cols, level.rows))
