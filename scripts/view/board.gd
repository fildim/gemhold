extends Node2D
## Draws everything that moves: the gem pile, towers, heroes, shots and effects.
## Redrawn every frame by main.gd.

const T := 64.0
const OUTLINE := Color("1a120c")
const HIGH_LIFT := 0.18   # towers on raised tiles stand this much higher, on the rock top

var level: Level
var sim: GameSim
var font: Font
var selected := Vector2i(-1, -1)
var armed := false


var _fog: ImageTexture


func setup(lv: Level, s: GameSim, f: Font) -> void:
	level = lv
	sim = s
	font = f
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sim.light_changed.connect(_build_fog)
	_build_fog()


## Night darkness: one pixel per tile, stretched with smoothing so the light has soft edges.
func _build_fog() -> void:
	_fog = null
	if not level.night:
		return
	var img := Image.create(level.cols + 2, level.rows + 2, false, Image.FORMAT_RGBA8)
	for c in range(-1, level.cols + 1):
		for r in range(-1, level.rows + 1):
			var cell := Vector2i(clampi(c, 0, level.cols - 1), clampi(r, 0, level.rows - 1))
			img.set_pixel(c + 1, r + 1, Color(0.02, 0.02, 0.06, 0.0 if sim.is_lit(cell) else 0.8))
	_fog = ImageTexture.create_from_image(img)


func _draw() -> void:
	if sim == null:
		return
	var tm := sim.time
	# The hoard: one place per gem on a ring in the cave mouth, so taken gems leave a gap.
	var slots := maxi(1, level.gems)
	var ring := []
	for i in slots:
		var a := TAU * i / slots - PI / 2.0
		ring.append(level.lair_center + Vector2(0, 0.38) + Vector2(cos(a) * 0.32, sin(a) * 0.16))
	ring.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	for i in slots:
		if i < sim.home:
			Paint.gem(self, ring[i] * T, T * 0.1)
	for pl: GameSim.Pool in sim.pools:
		_draw_pool(pl, tm)
	for c: Vector2i in level.high:
		_draw_high_shine(c, tm)
	_draw_selection()
	_draw_den_charges(tm)
	for s: GameSim.Site in sim.sites.values():
		_draw_site(s, tm)
	var tws: Array = sim.towers.values()
	tws.sort_custom(func(a: GameSim.Tower, b: GameSim.Tower) -> bool: return a.pos.y < b.pos.y)
	for tw: GameSim.Tower in tws:
		_draw_tower(tw, tm)
	for g: GameSim.Drop in sim.drops:
		_draw_gems(g.pos * T + Vector2(0, (-0.1 + sin(tm * 5.0) * 0.05) * T), g.n, 0.3)
	var es: Array = sim.enemies.duplicate()
	es.sort_custom(func(a: GameSim.Enemy, b: GameSim.Enemy) -> bool: return a.pos.y < b.pos.y)
	for e: GameSim.Enemy in es:
		_draw_enemy(e, tm)
	for s: GameSim.Shot in sim.shots:
		_draw_shot(s)
	for tw: GameSim.Tower in tws:
		if tw.beam != null:
			_draw_beam(tw, tm)
	var full := Rect2(0, 0, level.cols * T, level.rows * T)
	if _fog != null:
		draw_rect(full, Color(0.05, 0.07, 0.2, 0.22))
		draw_texture_rect_region(_fog, full, Rect2(1, 1, level.cols, level.rows))
	for l: GameSim.Loot in sim.loot:
		_draw_loot(l, tm)
	for f: GameSim.Fx in sim.fx:
		_draw_fx(f)
	if armed:
		draw_rect(full, Color(1, 0.42, 0.13, 0.09))


## n gems side by side, far enough apart that each one shows; glow 0 is the small halo
## of a carried gem, more for gems lying on the road.
func _draw_gems(c: Vector2, n: int, glow: float) -> void:
	var gap := T * 0.3
	for i in n:
		var gp := c + Vector2((i - (n - 1) / 2.0) * gap, absf(i - (n - 1) / 2.0) * T * 0.06)
		Paint.glow(self, gp, T * (0.2 + glow * 0.3), Color(1, 0.38, 0.5, 0.65 - glow * 0.5))
		Paint.gem(self, gp, T * 0.12)
	if n > 1:
		var lbl := "%d" % n
		var at := c + Vector2(n * gap * 0.5 + 2.0, -T * 0.06)
		draw_string_outline(font, at, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, OUTLINE)
		draw_string(font, at, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ff9aae"))


func _draw_selection() -> void:
	if selected.x < 0:
		return
	var r := Rect2(Vector2(selected) * T, Vector2(T, T))
	draw_rect(r.grow(-1), Color.WHITE, false, 2.0)
	var rg := sim.preview_range(selected)
	if rg > 0.0:
		var c := r.get_center()
		draw_circle(c, rg * T, Color(1, 1, 1, 0.08))
		draw_arc(c, rg * T, 0, TAU, 64, Color(1, 1, 1, 0.45), 1.5, true)


# ---------------------------------------------------------------- towers

func _draw_tower(tw: GameSim.Tower, tm: float) -> void:
	var x := tw.pos.x * T
	var y := tw.pos.y * T - (HIGH_LIFT * T if level.high.has(tw.cell) else 0.0)
	var s := T
	var lv := tw.lvl
	var flash := tw.flash > 0.0
	# stone platform
	Paint.ellipse(self, Vector2(x + s * 0.05, y + s * 0.34), s * 0.42, s * 0.14, Color(0, 0, 0, 0.33))
	Paint.vgrad_poly(self, Paint.ellipse_pts(Vector2(x, y + s * 0.3), s * 0.4, s * 0.13), Color("8d8478"), Color("4a443c"))
	Paint.ellipse(self, Vector2(x, y + s * 0.27), s * 0.36, s * 0.1, Color("a69c8e"))
	if lv >= 2:
		Paint.ellipse_outline(self, Vector2(x, y + s * 0.3), s * 0.4, s * 0.13, Color("e8b84a"), 2.0)
	match tw.type:
		"moss":
			_draw_hut(x, y, s, lv, flash, tm, tw.pos.x)
		"frost":
			_draw_crypt(x, y, s, lv, flash, tm)
		_:
			_draw_shrine(x, y, s, lv, flash, tm, tw.pos)
	# veteran chevrons, and a violet halo once the ability is learned
	if tw.has_ability():
		Paint.ellipse_outline(self, Vector2(x, y + s * 0.3), s * 0.46, s * 0.17, Color(0.79, 0.75, 1, 0.5 + 0.3 * sin(tm * 3.0)), 2.0)
	for i in tw.rank:
		var cy := y - s * 0.05 - i * s * 0.09
		var cx := x - s * 0.42
		draw_polyline(PackedVector2Array([Vector2(cx - s * 0.07, cy), Vector2(cx, cy - s * 0.05), Vector2(cx + s * 0.07, cy)]), OUTLINE, 5.0, true)
		draw_polyline(PackedVector2Array([Vector2(cx - s * 0.07, cy), Vector2(cx, cy - s * 0.05), Vector2(cx + s * 0.07, cy)]), Color("c9c0ff"), 2.5, true)
	for i in lv:
		var px := x - (lv - 1) * s * 0.07 + i * s * 0.14
		var py := y + s * 0.42
		var pip := PackedVector2Array([Vector2(px, py - s * 0.05), Vector2(px + s * 0.04, py), Vector2(px, py + s * 0.05), Vector2(px - s * 0.04, py)])
		draw_colored_polygon(pip, Color("e8b84a"))
		pip.append(pip[0])
		draw_polyline(pip, Color("5a3a10"), 1.0, true)


func _draw_hut(x: float, y: float, s: float, lv: int, flash: bool, tm: float, seed_x: float) -> void:
	var top := y - s * (0.44 + lv * 0.05)
	# banner
	draw_line(Vector2(x + s * 0.3, y + s * 0.24), Vector2(x + s * 0.3, top - s * 0.12), Color("3a2414"), maxf(2.0, s * 0.035))
	var wv := sin(tm * 5.0 + seed_x) * s * 0.04
	var flag := PackedVector2Array([Vector2(x + s * 0.3, top - s * 0.12)])
	flag.append_array(Paint.quad(Vector2(x + s * 0.3, top - s * 0.12), Vector2(x + s * 0.42, top - s * 0.06 + wv), Vector2(x + s * 0.52, top - s * 0.04), 5))
	flag.append(Vector2(x + s * 0.3, top + s * 0.08))
	draw_colored_polygon(flag, Color("c0283a") if lv == 3 else Color("9a2a2a"))
	# log walls
	Paint.hgrad_poly(self, Paint.rect_pts(Rect2(x - s * 0.26, y - s * 0.08, s * 0.52, s * 0.36)), Color("8a5a32"), Color("4a2e18"))
	for i in range(1, 4):
		draw_line(Vector2(x - s * 0.26 + i * s * 0.13, y - s * 0.08), Vector2(x - s * 0.26 + i * s * 0.13, y + s * 0.28), Color(0.18, 0.11, 0.05, 0.55), 1.0)
	var door := PackedVector2Array([Vector2(x - s * 0.08, y + s * 0.28), Vector2(x - s * 0.08, y + s * 0.1)])
	door.append_array(Paint.quad(Vector2(x - s * 0.08, y + s * 0.1), Vector2(x, y + s * 0.0), Vector2(x + s * 0.08, y + s * 0.1), 6))
	door.append(Vector2(x + s * 0.08, y + s * 0.28))
	draw_colored_polygon(door, Color("120a05"))
	# hide roof
	var roof := PackedVector2Array([Vector2(x - s * 0.38, y - s * 0.02), Vector2(x, top), Vector2(x + s * 0.38, y - s * 0.02)])
	Paint.vgrad_poly(self, roof, Color("f0c070") if flash else Color("c09a64"), Color("7a5432"))
	for i in range(1, 3):
		var k := i / 3.0
		var ry := y - s * 0.02 - (y - s * 0.02 - top) * k
		draw_line(Vector2(x - s * 0.38 * (1 - k), ry), Vector2(x + s * 0.38 * (1 - k), ry), Color("5a3a1e"), 1.5)
	# bone horns
	for d in [-1.0, 1.0]:
		var horn := PackedVector2Array([Vector2(x + d * s * 0.06, top + s * 0.06)])
		horn.append_array(Paint.quad(Vector2(x + d * s * 0.06, top + s * 0.06), Vector2(x + d * s * 0.24, top - s * 0.02), Vector2(x + d * s * 0.2, top - s * 0.18), 6))
		draw_polyline(horn, Color("f1e6cc"), maxf(2.0, s * 0.045), true)


func _draw_crypt(x: float, y: float, s: float, lv: int, flash: bool, tm: float) -> void:
	var top := y - s * (0.48 + lv * 0.05)
	if lv >= 2:
		for px in [x - s * 0.36, x + s * 0.26]:
			Paint.vgrad_poly(self, Paint.rect_pts(Rect2(px, y - s * 0.2, s * 0.1, s * 0.48)), Color("c3ccd2"), Color("6b767e"))
			draw_rect(Rect2(px - s * 0.02, y - s * 0.24, s * 0.14, s * 0.05), Color("dfe8ee"))
	Paint.hgrad_poly(self, Paint.rect_pts(Rect2(x - s * 0.25, y - s * 0.16, s * 0.5, s * 0.44)), Color("b8c3ca"), Color("5d6870"))
	for i in 3:
		var yy := y - s * 0.16 + i * s * 0.15
		draw_line(Vector2(x - s * 0.25, yy), Vector2(x + s * 0.25, yy), Color(0.29, 0.33, 0.36, 0.55), 1.0)
		var bx := x - s * 0.25 + (s * 0.12 if i % 2 else s * 0.25)
		draw_line(Vector2(bx, yy), Vector2(bx, yy + s * 0.15), Color(0.29, 0.33, 0.36, 0.55), 1.0)
	Paint.vgrad_poly(self, PackedVector2Array([Vector2(x - s * 0.31, y - s * 0.14), Vector2(x, top), Vector2(x + s * 0.31, y - s * 0.14)]), Color("56636e"), Color("2c353d"))
	draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + s * 0.12, top + s * 0.14), Vector2(x - s * 0.12, top + s * 0.14)]), Color("eef6fa"))
	Paint.glow(self, Vector2(x, y + s * 0.05), s * (0.4 if flash else 0.26), Color(0.56, 0.88, 1, 0.65))
	# skull
	draw_circle(Vector2(x, y + s * 0.03), s * 0.1, Color("e9f1f4"))
	draw_rect(Rect2(x - s * 0.06, y + s * 0.08, s * 0.12, s * 0.06), Color("e9f1f4"))
	var eye := Color.WHITE if flash else Color("4fd0ff")
	draw_rect(Rect2(x - s * 0.055, y + s * 0.01, s * 0.04, s * 0.04), eye)
	draw_rect(Rect2(x + s * 0.015, y + s * 0.01, s * 0.04, s * 0.04), eye)
	if lv == 3:
		var cy := top - s * 0.14 + sin(tm * 3.0) * s * 0.03
		Paint.glow(self, Vector2(x, cy), s * 0.16, Color(0.75, 0.94, 1, 0.8))
		draw_colored_polygon(PackedVector2Array([Vector2(x, cy - s * 0.1), Vector2(x + s * 0.05, cy), Vector2(x, cy + s * 0.1), Vector2(x - s * 0.05, cy)]), Color("d8f6ff"))


func _draw_shrine(x: float, y: float, s: float, lv: int, flash: bool, tm: float, p: Vector2) -> void:
	var h := s * (0.5 + lv * 0.07)
	var top := y + s * 0.2 - h
	if lv >= 2:
		for d in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([Vector2(x + d * s * 0.2, y + s * 0.24), Vector2(x + d * s * 0.34, y - s * 0.08), Vector2(x + d * s * 0.27, y + s * 0.24)]), Color("24140f"))
	Paint.hgrad_poly(self, PackedVector2Array([Vector2(x - s * 0.2, y + s * 0.24), Vector2(x - s * 0.13, top + s * 0.08), Vector2(x + s * 0.13, top + s * 0.08), Vector2(x + s * 0.2, y + s * 0.24)]), Color("4a2c26"), Color("120a08"))
	var pulse := 0.55 + 0.45 * sin(tm * 4.0 + p.y)
	var rune := Color(1, (120 + pulse * 60) / 255.0, 40 / 255.0, 0.5 + pulse * 0.4)
	draw_line(Vector2(x, top + s * 0.18), Vector2(x, y + s * 0.1), rune, 2.0)
	draw_line(Vector2(x - s * 0.07, top + s * 0.3), Vector2(x + s * 0.07, top + s * 0.38), rune, 2.0)
	draw_line(Vector2(x + s * 0.07, top + s * 0.3), Vector2(x - s * 0.07, top + s * 0.38), rune, 2.0)
	# brazier and flame
	draw_colored_polygon(PackedVector2Array([Vector2(x - s * 0.19, top + s * 0.08), Vector2(x + s * 0.19, top + s * 0.08), Vector2(x + s * 0.13, top + s * 0.15), Vector2(x - s * 0.13, top + s * 0.15)]), Color("2a1a14"))
	Paint.glow(self, Vector2(x, top), s * (0.55 if flash else 0.38), Color(1, 0.48, 0.16, 0.55))
	var fl := sin(tm * 12.0 + p.x * 3.0) * s * 0.03
	var outer := PackedVector2Array([Vector2(x - s * 0.14, top + s * 0.08)])
	outer.append_array(Paint.quad(Vector2(x - s * 0.14, top + s * 0.08), Vector2(x - s * 0.12, top - s * 0.12), Vector2(x + fl, top - s * 0.26), 6))
	outer.append_array(Paint.quad(Vector2(x + fl, top - s * 0.26), Vector2(x + s * 0.12, top - s * 0.1), Vector2(x + s * 0.14, top + s * 0.08), 6))
	draw_colored_polygon(outer, Color("ff5a1a"))
	var inner := PackedVector2Array([Vector2(x - s * 0.07, top + s * 0.08)])
	inner.append_array(Paint.quad(Vector2(x - s * 0.07, top + s * 0.08), Vector2(x - s * 0.05, top - s * 0.04), Vector2(x - fl * 0.5, top - s * 0.14), 5))
	inner.append_array(Paint.quad(Vector2(x - fl * 0.5, top - s * 0.14), Vector2(x + s * 0.06, top - s * 0.03), Vector2(x + s * 0.07, top + s * 0.08), 5))
	draw_colored_polygon(inner, Color("ffd25a"))


# ---------------------------------------------------------------- heroes

const TUNIC := {"p": "9a7446", "f": "4e6584", "s": "4d7638", "c": "efe9da", "k": "c9a43c", "b": "6e7682", "t": "4a3a5a", "w": "5a4630"}
const TUNIC_DARK := {"p": "6a4a26", "f": "2e3e54", "s": "2e4a20", "c": "b8ae96", "k": "7a5e18", "b": "3e444c", "t": "2a2036", "w": "362818"}


func _draw_enemy(e: GameSim.Enemy, tm: float) -> void:
	var u: float = e.d["r"] * T
	var f := float(e.face)
	var cyc: float = tm * 10.0 * e.d["spd"] + e.bob
	var walk := sin(cyc)
	var bob := absf(cos(cyc)) * u * 0.08
	var x := e.pos.x * T
	var yb := e.pos.y * T
	var y := yb - bob
	var code := e.code
	var lw := maxf(1.0, u * 0.09)
	Paint.ellipse(self, Vector2(x, yb + u * 0.95), u * 0.75, u * 0.22, Color(0, 0, 0, 0.33))
	var tun := Color(TUNIC[code])
	var dark := Color(TUNIC_DARK[code])
	if code == "k":  # cape behind
		var cape := PackedVector2Array([Vector2(x - f * u * 0.2, y - u * 0.35)])
		cape.append_array(Paint.quad(Vector2(x - f * u * 0.2, y - u * 0.35), Vector2(x - f * u * (0.9 + walk * 0.1), y + u * 0.2), Vector2(x - f * u * 0.6, y + u * 0.75), 6))
		cape.append(Vector2(x - f * u * 0.05, y + u * 0.55))
		draw_colored_polygon(cape, Color("8a1e2c"))
	if code == "s":  # bow on the back
		var a0 := PI * 0.6 if f > 0 else -PI * 0.4
		draw_arc(Vector2(x - f * u * 0.3, y - u * 0.05), u * 0.5, a0, a0 + PI * 0.8, 12, Color("6a4a22"), maxf(1.5, u * 0.12), true)
	if code != "c":  # legs
		var lwid := maxf(2.0, u * 0.22)
		draw_line(Vector2(x - u * 0.15, y + u * 0.35), Vector2(x - u * 0.15 + walk * u * 0.28, yb + u * 0.85), dark, lwid)
		draw_line(Vector2(x + u * 0.15, y + u * 0.35), Vector2(x + u * 0.15 - walk * u * 0.28, yb + u * 0.85), dark, lwid)
	var body: PackedVector2Array
	if code == "c":
		body = PackedVector2Array([Vector2(x - u * 0.3, y - u * 0.35), Vector2(x + u * 0.3, y - u * 0.35), Vector2(x + u * 0.5, yb + u * 0.85), Vector2(x - u * 0.5, yb + u * 0.85)])
	else:
		body = PackedVector2Array([Vector2(x - u * 0.34, y - u * 0.35), Vector2(x + u * 0.34, y - u * 0.35), Vector2(x + u * 0.4, y + u * 0.45), Vector2(x - u * 0.4, y + u * 0.45)])
	Paint.vgrad_poly(self, body, tun, dark)
	var bo := body.duplicate()
	bo.append(body[0])
	draw_polyline(bo, OUTLINE, lw, true)
	if code == "c":
		draw_line(Vector2(x, y - u * 0.3), Vector2(x, yb + u * 0.8), Color("e8b84a"), maxf(1.0, u * 0.1))
		Paint.glow(self, Vector2(x, y - u * 0.7), u * 0.9, Color(1, 0.95, 0.7, 0.6))
	if code == "f":
		draw_rect(Rect2(x - u * 0.34, y - u * 0.35, u * 0.68, u * 0.22), Color("9aa8b5"))
	if code != "c":
		draw_rect(Rect2(x - u * 0.38, y + u * 0.12, u * 0.76, u * 0.09), Color("3a2414"))
	# head
	draw_circle(Vector2(x, y - u * 0.68), u * 0.38, Color("f0c9a0"))
	draw_arc(Vector2(x, y - u * 0.68), u * 0.38, 0, TAU, 20, OUTLINE, lw, true)
	draw_rect(Rect2(x + f * u * 0.1 - u * 0.04, y - u * 0.74, maxf(1.0, u * 0.09), maxf(1.0, u * 0.1)), OUTLINE)
	_draw_headgear(code, x, y, u, f, lw)
	_draw_held(code, x, y, yb, u, f)
	if e.slow > 0.0:
		Paint.ellipse(self, Vector2(x, y - u * 0.1), u * 0.75, u * 1.1, Color(0.62, 0.88, 1, 0.25))
		for i in 3:
			var a := sim.time * 2.0 + i * 2.1
			draw_rect(Rect2(x + cos(a) * u * 0.6, y - u * 0.2 + sin(a) * u * 0.7, 2, 2), Color("e6f8ff"))
	if e.fear > 0.0:
		var fy := y - u * 1.75 + sin(sim.time * 14.0) * 1.5
		draw_string_outline(font, Vector2(x - 10, fy), "!!", HORIZONTAL_ALIGNMENT_CENTER, 20, 18, 4, OUTLINE)
		draw_string(font, Vector2(x - 10, fy), "!!", HORIZONTAL_ALIGNMENT_CENTER, 20, 18, Color("c9c0ff"))
	_draw_gems(Vector2(e.pos.x, e.pos.y - e.d["r"] * 2.3 - 0.08) * T, e.carry, 0.0)
	if e.hp < e.max_hp:
		var w := maxf(16.0, u * 2.6)
		var hy := y - u * (1.8 if code == "k" else 1.65) - 6.0
		draw_rect(Rect2(x - w / 2 - 1, hy - 1, w + 2, 6), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(x - w / 2, hy, w * e.hp / e.max_hp, 4), Color("6fd36f") if e.hp / e.max_hp > 0.4 else Color("e0503a"))


func _draw_headgear(code: String, x: float, y: float, u: float, f: float, lw: float) -> void:
	match code:
		"p":  # straw hat
			Paint.ellipse(self, Vector2(x, y - u * 0.9), u * 0.6, u * 0.14, Color("d9b45a"))
			draw_circle(Vector2(x, y - u * 0.98), u * 0.24, Color("d9b45a"))
		"f", "b":  # helmet
			var helm := PackedVector2Array()
			for i in 11:
				var a := PI + PI * i / 10.0
				helm.append(Vector2(x, y - u * 0.74) + Vector2(cos(a), sin(a)) * u * 0.42)
			Paint.vgrad_poly(self, helm, Color("d6dee5"), Color("7b8894"))
			draw_rect(Rect2(x + f * u * 0.08 - u * 0.03, y - u * 0.76, u * 0.07, u * 0.24), Color("7b8894"))
		"s", "t":  # hood
			var hood := PackedVector2Array([Vector2(x - u * 0.42, y - u * 0.55)])
			hood.append_array(Paint.quad(Vector2(x - u * 0.42, y - u * 0.55), Vector2(x - u * 0.4, y - u * 1.15), Vector2(x - f * u * 0.2, y - u * 1.35), 6))
			hood.append_array(Paint.quad(Vector2(x - f * u * 0.2, y - u * 1.35), Vector2(x + u * 0.45, y - u * 1.1), Vector2(x + u * 0.42, y - u * 0.55), 6))
			hood.append_array(Paint.quad(Vector2(x + u * 0.42, y - u * 0.55), Vector2(x, y - u * 0.85), Vector2(x - u * 0.38, y - u * 0.57), 4))
			draw_colored_polygon(hood, Color("3d6a2c") if code == "s" else Color("2e2240"))
		"w":  # wide-brimmed hat
			Paint.ellipse(self, Vector2(x, y - u * 0.92), u * 0.7, u * 0.15, Color("2a1e14"))
			draw_rect(Rect2(x - u * 0.28, y - u * 1.3, u * 0.56, u * 0.4), Color("2a1e14"))
			draw_rect(Rect2(x - u * 0.28, y - u * 1.02, u * 0.56, u * 0.07), Color("8a6420"))
		"c":  # cowl
			var cowl := PackedVector2Array()
			for i in 11:
				var a := PI * 1.05 + PI * 0.9 * i / 10.0
				cowl.append(Vector2(x, y - u * 0.78) + Vector2(cos(a), sin(a)) * u * 0.4)
			draw_colored_polygon(cowl, Color("efe9da"))
		"k":  # gold helm and plume
			var helm := PackedVector2Array()
			for i in 13:
				var a := PI * 0.9 + PI * 1.2 * i / 12.0
				helm.append(Vector2(x, y - u * 0.7) + Vector2(cos(a), sin(a)) * u * 0.42)
			Paint.vgrad_poly(self, helm, Color("ffe08a"), Color("9a7420"))
			draw_rect(Rect2(x - u * 0.25, y - u * 0.72, u * 0.5, u * 0.06), OUTLINE)
			var plume := PackedVector2Array([Vector2(x, y - u * 1.1)])
			plume.append_array(Paint.quad(Vector2(x, y - u * 1.1), Vector2(x - f * u * 0.5, y - u * 1.6), Vector2(x - f * u * 0.75, y - u * 1.05), 6))
			plume.append_array(Paint.quad(Vector2(x - f * u * 0.75, y - u * 1.05), Vector2(x - f * u * 0.3, y - u * 1.25), Vector2(x - f * u * 0.05, y - u * 1.12), 4))
			draw_colored_polygon(plume, Color("c0283a"))


func _draw_held(code: String, x: float, y: float, yb: float, u: float, f: float) -> void:
	var hx := x + f * u * 0.5
	var w := maxf(1.5, u * 0.11)
	match code:
		"p":  # pitchfork
			var tip := Vector2(hx + f * u * 0.15, y - u * 1.3)
			draw_line(Vector2(hx, y + u * 0.5), tip, Color("6a4422"), w)
			for d in [-1.0, 0.0, 1.0]:
				draw_line(tip + Vector2(d * u * 0.12, 0), tip + Vector2(d * u * 0.12, -u * 0.3), Color("8a8a8a"), maxf(1.0, u * 0.07))
			draw_line(tip + Vector2(-u * 0.12, 0), tip + Vector2(u * 0.12, 0), Color("8a8a8a"), maxf(1.0, u * 0.07))
		"b":  # tall tower shield held in front
			var sc := Vector2(x + f * u * 0.35, y + u * 0.1)
			var tall := Paint.rect_pts(Rect2(sc - Vector2(0.32, 0.6) * u, Vector2(0.64, 1.2) * u))
			Paint.vgrad_poly(self, tall, Color("9aa8b5"), Color("5a6672"))
			tall.append(tall[0])
			draw_polyline(tall, Color("c9d2da"), maxf(1.0, u * 0.1), true)
			draw_line(sc + Vector2(0, -0.5) * u, sc + Vector2(0, 0.5) * u, Color("c9d2da"), maxf(1.0, u * 0.08))
		"t":  # dagger and a sack for stolen gems
			draw_line(Vector2(hx, y + u * 0.2), Vector2(hx + f * u * 0.35, y - u * 0.25), Color("dfe6ec"), maxf(1.5, u * 0.09))
			Paint.ellipse(self, Vector2(x - f * u * 0.45, y + u * 0.35), u * 0.28, u * 0.24, Color("7a5a32"))
			draw_line(Vector2(x - f * u * 0.45, y + u * 0.1), Vector2(x - f * u * 0.2, y - u * 0.3), Color("5a3e20"), maxf(1.0, u * 0.07))
		"w":  # lantern on a pole
			var top := Vector2(hx + f * u * 0.1, y - u * 1.1)
			draw_line(Vector2(hx, yb + u * 0.8), top, Color("4a3220"), w)
			Paint.glow(self, top + Vector2(0, u * 0.25), u * (1.0 + 0.1 * sin(sim.time * 6.0)), Color(1, 0.85, 0.45, 0.55))
			draw_rect(Rect2(top + Vector2(-0.14, 0.1) * u, Vector2(0.28, 0.32) * u), Color("ffd27a"))
			draw_rect(Rect2(top + Vector2(-0.14, 0.1) * u, Vector2(0.28, 0.32) * u), Color("3a2a18"), false, maxf(1.0, u * 0.06))
		"c":  # holy staff
			draw_line(Vector2(hx, yb + u * 0.8), Vector2(hx, y - u * 1.2), Color("8a6420"), w)
			draw_line(Vector2(hx - u * 0.18, y - u * 1.0), Vector2(hx + u * 0.18, y - u * 1.0), Color("8a6420"), w)
		"f", "k":
			var knight := code == "k"
			var tip := Vector2(hx + f * u * 0.05, y - u * (0.9 if knight else 1.4))
			draw_line(Vector2(hx - f * u * 0.1, y + u * 0.3), tip, Color("dfe6ec") if knight else Color("6a4422"), w)
			if not knight:
				draw_colored_polygon(PackedVector2Array([tip, Vector2(hx + f * u * 0.1, y - u * 1.15), Vector2(hx, y - u * 1.15)]), Color("cfd6dc"))
			var sc := Vector2(x + f * u * 0.32, y + u * 0.02)
			var shield := PackedVector2Array([sc + Vector2(-0.28, -0.32) * u, sc + Vector2(0.28, -0.32) * u, sc + Vector2(0.26, 0.1) * u])
			shield.append_array(Paint.quad(sc + Vector2(0.26, 0.1) * u, sc + Vector2(0, 0.45) * u, sc + Vector2(-0.26, 0.1) * u, 6))
			draw_colored_polygon(shield, Color("a01e2e") if knight else Color("2f4f8a"))
			var rim := Color("e8b84a") if knight else Color("c9d2da")
			var so := shield.duplicate()
			so.append(shield[0])
			draw_polyline(so, rim, maxf(1.0, u * 0.09), true)
			draw_line(sc + Vector2(0, -0.28) * u, sc + Vector2(0, 0.3) * u, rim, maxf(1.0, u * 0.09))
			draw_line(sc + Vector2(-0.2, -0.1) * u, sc + Vector2(0.2, -0.1) * u, rim, maxf(1.0, u * 0.09))


# ---------------------------------------------------------------- shots & effects

func _draw_shot(s: GameSim.Shot) -> void:
	var p := s.pos * T
	var dirv := (s.tpos - s.pos).normalized()
	if dirv == Vector2.ZERO:
		dirv = Vector2.RIGHT
	var n := dirv.orthogonal()
	match s.kind:
		"arrow":
			var tail := p - dirv * T * 0.24
			draw_line(tail, p, Color("5a3a1e"), maxf(2.0, T * 0.035))
			draw_colored_polygon(PackedVector2Array([p + dirv * T * 0.06, p + n * T * 0.035, p - n * T * 0.035]), Color("d8dde2"))
			draw_line(tail, tail + dirv * T * 0.06 + n * T * 0.04, Color("f2f2f2"), 1.5)
			draw_line(tail, tail + dirv * T * 0.06 - n * T * 0.04, Color("f2f2f2"), 1.5)
		"frost":
			for i in range(3, 0, -1):
				draw_circle(p - dirv * T * 0.08 * i, T * 0.06, Color(0.75, 0.92, 1, 0.15 * (4 - i)))
			Paint.glow(self, p, T * 0.18, Color(0.66, 0.9, 1, 0.75))
			draw_circle(p, T * 0.055, Color.WHITE)
		"den":
			for i in range(4, 0, -1):
				draw_circle(p - dirv * T * 0.07 * i, T * (0.03 + 0.01 * i), Color(0.6, 0.7, 1, 0.12 * (5 - i)))
			_draw_orb(p, T * 0.1, sim.time, 7)
		_:
			for i in range(4, 0, -1):
				draw_circle(p - dirv * T * 0.1 * i, T * (0.05 + 0.02 * i), Color(0.35, 0.24, 0.2, 0.12 * (5 - i)))
			Paint.glow(self, p, T * 0.3, Color(1, 0.48, 0.16, 0.8))
			draw_circle(p, T * 0.11, Color("ff6a20"))
			draw_circle(p, T * 0.055, Color("ffe08a"))


## Cinder Shrine beam: from the brazier to the hero, orange when cool, white-hot at full heat.
func _draw_beam(tw: GameSim.Tower, tm: float) -> void:
	var h := tw.heat
	var lift := HIGH_LIFT if level.high.has(tw.cell) else 0.0
	var a := (tw.pos + Vector2(0, 0.2 - (0.5 + tw.lvl * 0.07) - 0.1 - lift)) * T   # the flame atop _draw_shrine
	var b := tw.beam.pos * T + Vector2(0, -T * 0.15)
	var flick := 0.85 + 0.15 * sin(tm * 40.0 + tw.pos.x * 7.0)
	var outer := Color(1, 0.35 + 0.25 * h, 0.08, 0.35 * flick)
	var core := Color(1, 0.7 + 0.3 * h, 0.35 + 0.6 * h, 0.95)
	draw_line(a, b, outer, T * (0.1 + 0.08 * h), true)
	draw_line(a, b, core, T * (0.03 + 0.03 * h) * flick, true)
	Paint.glow(self, b, T * (0.22 + 0.15 * h), Color(1, 0.5 + 0.3 * h, 0.15, 0.7))
	Paint.glow(self, a, T * 0.18, Color(1, 0.6, 0.2, 0.6))


func _draw_fx(f: GameSim.Fx) -> void:
	var k := f.t / f.dur
	var p := f.pos * T
	match f.kind:
		"boom":
			var rr := f.r * T * (0.4 + 0.6 * k)
			Paint.glow(self, p, rr * 1.15, Color(1, 0.47, 0.16, (1 - k) * 0.9))
			draw_circle(p, rr * 0.45, Color(1, 0.94, 0.67, (1 - k) * 0.8))
		"meteor":
			if not f.hit:
				var q := f.t / Defs.METEOR["delay"]
				draw_arc(p, Defs.METEOR["radius"] * T, 0, TAU, 48, Color(1, 0.69, 0.25, 0.55), 2.0, true)
				var m := Vector2((f.pos.x + 2.0 * (1 - q)) * T, (f.pos.y - 4.0 * (1 - q)) * T)
				Paint.glow(self, m, T * 0.6, Color(1, 0.42, 0.13, 0.7))
				draw_circle(m, T * 0.28, Color("ff6a20"))
				draw_circle(m, T * 0.14, Color("ffe08a"))
		"text":
			var fs := 28
			var pos := Vector2(p.x - 80, (f.pos.y - k * 0.6) * T)
			var col := f.color
			col.a = 1.0 - k
			draw_string_outline(font, pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, 160, fs, 4, Color(0, 0, 0, col.a * 0.7))
			draw_string(font, pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, 160, fs, col)


# ---------------------------------------------------------------- lava, map buildings, loot

func _draw_pool(pl: GameSim.Pool, tm: float) -> void:
	var p := pl.pos * T
	var fade := clampf((pl.dur - pl.t) / 0.6, 0.0, 1.0)
	Paint.ellipse(self, p, pl.r * T, pl.r * T * 0.55, Color(0.3, 0.06, 0.02, 0.6 * fade))
	Paint.glow(self, p, pl.r * T * 1.1, Color(1, 0.35, 0.05, 0.55 * fade))
	for i in 5:
		var a := i * 1.26 + tm * 0.7
		var q := p + Vector2(cos(a) * pl.r * 0.55, sin(a) * pl.r * 0.3) * T
		draw_circle(q, T * (0.03 + 0.02 * sin(tm * 6.0 + i)), Color(1, 0.8, 0.3, 0.8 * fade))


func _draw_site(s: GameSim.Site, tm: float) -> void:
	var c := s.pos * T
	Paint.ellipse(self, c + Vector2(0.03, 0.3) * T, T * 0.44, T * 0.14, Color(0, 0, 0, 0.35))
	match s.kind:
		"mine":
			var hill := PackedVector2Array([c + Vector2(-0.45, 0.3) * T])
			hill.append_array(Paint.quad(c + Vector2(-0.45, 0.3) * T, c + Vector2(0, -0.6) * T, c + Vector2(0.45, 0.3) * T, 10))
			Paint.vgrad_poly(self, hill, Color("8a7a66"), Color("3e342a"))
			var mouth := PackedVector2Array([c + Vector2(-0.16, 0.3) * T, c + Vector2(-0.16, 0.02) * T, c + Vector2(0.16, 0.02) * T, c + Vector2(0.16, 0.3) * T])
			draw_colored_polygon(mouth, Color("0c0807"))
			draw_line(c + Vector2(-0.19, 0.3) * T, c + Vector2(-0.19, -0.02) * T, Color("6a4422"), 3.0)
			draw_line(c + Vector2(0.19, 0.3) * T, c + Vector2(0.19, -0.02) * T, Color("6a4422"), 3.0)
			draw_line(c + Vector2(-0.23, -0.02) * T, c + Vector2(0.23, -0.02) * T, Color("6a4422"), 3.0)
			if s.owned:
				Paint.glow(self, c + Vector2(0, 0.18) * T, T * 0.3, Color(1, 0.8, 0.3, 0.6))
				for i in 3:
					var k := fmod(tm * 0.8 + i * 0.33, 1.0)
					draw_circle(c + Vector2(-0.1 + i * 0.1, 0.1 - k * 0.5) * T, T * 0.03, Color(1, 0.85, 0.35, 1.0 - k))
		"well":
			Paint.ellipse(self, c + Vector2(0, 0.12) * T, T * 0.34, T * 0.2, Color("6e665c"))
			Paint.ellipse(self, c + Vector2(0, 0.08) * T, T * 0.26, T * 0.14, Color("2a2440") if not s.owned else Color("5a48d0"))
			Paint.ellipse_outline(self, c + Vector2(0, 0.12) * T, T * 0.34, T * 0.2, Color("a69c8e"), 2.0)
			if s.owned:
				Paint.glow(self, c, T * (0.45 + 0.05 * sin(tm * 3.0)), Color(0.5, 0.42, 0.95, 0.55))
				for i in 3:
					var k := fmod(tm * 0.6 + i * 0.33, 1.0)
					draw_circle(c + Vector2(-0.12 + i * 0.12, 0.05 - k * 0.55) * T, T * 0.025, Color(0.8, 0.75, 1, 1.0 - k))
		"camp":
			if s.owned:
				for i in 5:
					var q := c + Vector2(Paint.hash01(s.cell.x, s.cell.y, i) - 0.5, Paint.hash01(s.cell.x, s.cell.y, i + 9) * 0.4) * T * 0.8
					draw_line(q, q + Vector2(0.18, -0.05) * T, Color("1c1210"), 4.0)
				Paint.glow(self, c + Vector2(0, 0.15) * T, T * 0.25, Color(1, 0.4, 0.1, 0.3 + 0.1 * sin(tm * 5.0)))
				return
			# palisade, tent and the heroes' banner
			for i in 7:
				var px := c.x + (i - 3) * T * 0.13
				draw_colored_polygon(PackedVector2Array([Vector2(px - T * 0.05, c.y + T * 0.32), Vector2(px - T * 0.05, c.y + T * 0.02), Vector2(px, c.y - T * 0.06), Vector2(px + T * 0.05, c.y + T * 0.02), Vector2(px + T * 0.05, c.y + T * 0.32)]), Color("7a5432") if i % 2 else Color("6a4628"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.24, 0.05) * T, c + Vector2(0, -0.4) * T, c + Vector2(0.24, 0.05) * T]), Color("d8d0bc"))
			draw_line(c + Vector2(0, -0.4) * T, c + Vector2(0, 0.05) * T, Color("9a9280"), 1.5)
			var pole := c + Vector2(0.3, -0.05) * T
			draw_line(pole, pole + Vector2(0, -0.55) * T, Color("3a2414"), 2.5)
			var wv := sin(tm * 5.0) * T * 0.03
			draw_colored_polygon(PackedVector2Array([pole + Vector2(0, -0.55) * T, pole + Vector2(0.26, -0.48) * T + Vector2(0, wv), pole + Vector2(0, -0.38) * T]), Color("2f4f8a"))
			if sim.wave >= 1 and sim.wave < level.waves.size():
				var k := 1.0 - s.t / s.every
				draw_arc(c + Vector2(0, -0.1) * T, T * 0.5, -PI / 2, -PI / 2 + TAU * k, 32, Color(0.6, 0.75, 1, 0.6), 2.5, true)


func _draw_loot(l: GameSim.Loot, tm: float) -> void:
	var p := l.pos * T + Vector2(0, sin(tm * 4.0 + l.pos.x * 3.0) * 3.0)
	Paint.ellipse(self, l.pos * T + Vector2(0, T * 0.12), T * 0.13, T * 0.05, Color(0, 0, 0, 0.35))
	if l.kind == "coin":
		Paint.glow(self, p, T * 0.32, Color(1, 0.8, 0.3, 0.55))
		draw_circle(p, T * 0.11, Color("e8b84a"))
		draw_arc(p, T * 0.11, 0, TAU, 20, Color("8a6420"), 1.5, true)
		draw_circle(p, T * 0.05, Color("c9952e"))
	else:
		Paint.glow(self, p, T * 0.32, Color(0.5, 0.42, 0.95, 0.6))
		draw_circle(p + Vector2(0, T * 0.03), T * 0.1, Color("7e6cf0"))
		draw_rect(Rect2(p + Vector2(-0.035, -0.15) * T, Vector2(0.07, 0.1) * T), Color("b8b0e8"))
		draw_rect(Rect2(p + Vector2(-0.045, -0.18) * T, Vector2(0.09, 0.04) * T), Color("6a4422"))
		draw_circle(p + Vector2(-0.03, 0.0) * T, T * 0.025, Color(1, 1, 1, 0.7))


## Den charges as gem sparks circling above the cave: lit when ready, dark while refilling,
## with a ring on the next one showing its progress. Sparks on the far side of the ring
## are drawn first and smaller, so the circle reads as a tilted loop.
func _draw_den_charges(tm: float) -> void:
	var n := sim.den_max
	var center := (level.lair_center + Vector2(0, -1.25)) * T
	var rx := T * (0.32 + 0.04 * n)
	var ry := T * 0.12
	var sparks := []
	for i in n:
		var a := tm * 1.4 + TAU * i / float(n)
		sparks.append([sin(a), i, center + Vector2(cos(a) * rx, sin(a) * ry)])
	sparks.sort_custom(func(s1: Array, s2: Array) -> bool: return s1[0] < s2[0])
	for s in sparks:
		var depth: float = 0.8 + 0.2 * s[0]   # 0.6 at the back of the loop, 1.0 at the front
		var i: int = s[1]
		var p: Vector2 = s[2]
		if i < sim.den_charges:
			_draw_orb(p, T * 0.11 * depth, tm, i)
		else:
			draw_circle(p, T * 0.05 * depth, Color(0, 0, 0, 0.55))
			if i == sim.den_charges:
				var k: float = sim.den_refill / Defs.DEN["refill"]
				draw_arc(p, T * 0.075 * depth, -PI / 2, -PI / 2 + TAU * k, 16, Color("a0b4ff"), 2.0, true)


## Raised tiles shimmer: a slow golden glow on the rock top and a few twinkling glints, so they
## stand out as the tiles any tower can use.
func _draw_high_shine(c: Vector2i, tm: float) -> void:
	var top := (Vector2(c) + Vector2(0.5, 0.36)) * T
	var k := float(c.x * 7 + c.y * 13)
	var pulse := 0.5 + 0.5 * sin(tm * 2.0 + k)
	Paint.glow(self, top, T * (0.42 + 0.06 * pulse), Color(1, 0.85, 0.45, 0.16 + 0.14 * pulse))
	for i in 3:
		var t := fmod(tm * 0.7 + i / 3.0 + Paint.hash01(c.x, c.y, i), 1.0)
		var a := sin(t * PI)   # fades in and out over its cycle
		var p := top + Vector2(Paint.hash01(c.x, c.y, i + 10) - 0.5, (Paint.hash01(c.x, c.y, i + 20) - 0.5) * 0.6) * T * 0.6
		var s := T * 0.06 * a
		var col := Color(1, 0.95, 0.75, 0.9 * a)
		draw_line(p - Vector2(s, 0), p + Vector2(s, 0), col, 1.5, true)
		draw_line(p - Vector2(0, s), p + Vector2(0, s), col, 1.5, true)


## A ball of crackling energy that swells and shrinks: a den charge, or a bolt in flight.
func _draw_orb(p: Vector2, r: float, tm: float, id: int) -> void:
	var pulse := 0.7 + 0.45 * (0.5 + 0.5 * sin(tm * 7.0 + id * 1.9))
	var rr := r * pulse
	Paint.glow(self, p, rr * 3.4, Color(0.35, 0.5, 1, 0.8))
	draw_circle(p, rr * 1.15, Color(0.15, 0.25, 0.75, 0.55))
	draw_circle(p, rr, Color(0.45, 0.62, 1))
	draw_circle(p, rr * 0.55, Color(0.95, 0.97, 1))
	# Three short forks of lightning, re-rolled about 20 times a second.
	var tick := int(tm * 20.0)
	for k in 3:
		var a := Paint.hash01(tick, id, k) * TAU
		var pts := PackedVector2Array([p])
		var q := p
		for j in 3:
			a += (Paint.hash01(tick, id, k * 7 + j) - 0.5) * 1.6
			q += Vector2(cos(a), sin(a)) * rr * (0.6 + Paint.hash01(tick, id, k * 11 + j) * 0.5)
			pts.append(q)
		draw_polyline(pts, Color(0.85, 0.9, 1, 0.85), maxf(1.0, rr * 0.18), true)
