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
var _bursts: Node2D      # particle bursts (bursts.gd), drawn over the board
var _plates: Array = []   # level badge backgrounds: levels I-II, level III
## Heroes as baked pictures (HeroSprites): drawn behind the board's own drawing (so their health
## bars, chill and carried gems go on top), with premultiplied blending to match the atlas.
var _layer: Node2D
const HERO_SCALE := 1.2   # heroes are drawn this much larger than their body radius
const FOG_PX := 4         # night fog pixels per tile


func setup(lv: Level, s: GameSim, f: Font) -> void:
	level = lv
	sim = s
	font = f
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sim.light_changed.connect(_build_fog)
	_build_fog()
	if _bursts == null:
		_bursts = preload("res://scripts/view/bursts.gd").new()
		add_child(_bursts)
	if _layer == null:
		_layer = Node2D.new()
		_layer.show_behind_parent = true
		_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
		_layer.material = m
		_layer.draw.connect(_draw_layer)
		add_child(_layer)
		HeroSprites.bake(self)
	var tunic := {}
	for k: String in Art.TUNIC:
		tunic[k] = Color(Art.TUNIC[k])
	_bursts.setup(sim, tunic)


## Night darkness: FOG_PX pixels per tile, stretched with smoothing. Each light (GameSim.lights)
## clears a soft-edged circle, so the light pools read as lamplight; a tile whose centre is inside a
## light is lit for building (GameSim.is_lit), which is where the pool is brightest.
func _build_fog() -> void:
	_fog = null
	if not sim.can_dark():
		return
	var w := (level.cols + 2) * FOG_PX
	var h := (level.rows + 2) * FOG_PX
	var light := PackedFloat32Array()
	light.resize(w * h)
	for l: Array in sim.lights:
		var at: Vector2 = l[0]
		var rr: float = l[1]
		var x0 := maxi(0, floori((at.x - rr) * FOG_PX))
		var x1 := mini(w - 1, ceili((at.x + rr + 2.0) * FOG_PX))
		var y0 := maxi(0, floori((at.y - rr) * FOG_PX))
		var y1 := mini(h - 1, ceili((at.y + rr + 2.0) * FOG_PX))
		for py in range(y0, y1 + 1):
			for px in range(x0, x1 + 1):
				var p := Vector2((px + 0.5) / FOG_PX - 1.0, (py + 0.5) / FOG_PX - 1.0)
				var v := clampf((rr + 0.45 - p.distance_to(at)) / 0.6, 0.0, 1.0)
				var i := py * w + px
				if v > light[i]:
					light[i] = v
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for py in h:
		for px in w:
			img.set_pixel(px, py, Color(0.02, 0.02, 0.07, 0.82 * (1.0 - light[py * w + px])))
	_fog = ImageTexture.create_from_image(img)


## How far night has come in: 1 on a night mission, fading over a few seconds as Dusk or an Eclipse comes and goes.
func _night_k() -> float:
	return sim.dark_k()


func _draw() -> void:
	if sim == null:
		return
	var tm := sim.time
	if _layer != null:
		_layer.queue_redraw()
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
	for f: GameSim.Fx in sim.fx:
		if f.kind == "scorch":
			_draw_scorch(f)
	for pl: GameSim.Pool in sim.pools:
		_draw_pool(pl, tm)
	_draw_paving()
	for c: Vector2i in level.high:
		_draw_high_shine(c, tm)
	_draw_routes(tm)
	_draw_sky(tm)
	_draw_selection()
	_draw_den_charges(tm)
	for s: GameSim.Site in sim.sites.values():
		_draw_site(s, tm)
	var tws: Array = sim.towers.values()
	tws.sort_custom(func(a: GameSim.Tower, b: GameSim.Tower) -> bool: return a.pos.y < b.pos.y)
	for tw: GameSim.Tower in tws:
		_draw_tower(tw, tm)
		_draw_status(tw, tm)
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
			_draw_beam(tw, tm, tw.beam, tw.heat)
		if tw.beam2 != null:
			_draw_beam(tw, tm, tw.beam2, tw.heat2)
	var full := Rect2(0, 0, level.cols * T, level.rows * T)
	if _fog != null and _night_k() > 0.001:
		var k := _night_k()
		draw_rect(full, Color(0.05, 0.07, 0.2, 0.22 * k))
		draw_texture_rect_region(_fog, full, Rect2(FOG_PX, FOG_PX, level.cols * FOG_PX, level.rows * FOG_PX), Color(1, 1, 1, k))
		for l: Array in sim.lights:   # warm lamplight in each pool
			Paint.glow(self, l[0] * T, l[1] * T * 0.9, Color(1, 0.72, 0.38, 0.13 * k))
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
	var sq := _squash(tw)
	if sq != Vector2.ONE:   # squash about the foot of the tower
		var foot := Vector2(x, y + s * 0.3)
		draw_set_transform_matrix(Transform2D(0.0, sq, 0.0, foot) * Transform2D(0.0, -foot))
	# stone platform
	Paint.ellipse(self, Vector2(x + s * 0.05, y + s * 0.34), s * 0.42, s * 0.14, Color(0, 0, 0, 0.33))
	Paint.vgrad_poly(self, Paint.ellipse_pts(Vector2(x, y + s * 0.3), s * 0.4, s * 0.13), Color("8d8478"), Color("4a443c"))
	Paint.ellipse(self, Vector2(x, y + s * 0.27), s * 0.36, s * 0.1, Color("a69c8e"))
	if lv >= 2:
		Paint.ellipse_outline(self, Vector2(x, y + s * 0.3), s * 0.4, s * 0.13, Color("e8b84a"), 2.0)
	match tw.type:
		"moss":
			Art.hut(self, x, y, s, lv, flash, tm, tw.pos.x)
		"frost":
			Art.crypt(self, x, y, s, lv, flash, tm)
		_:
			Art.shrine(self, x, y, s, lv, flash, tm, tw.pos)
	if tw.mastery != "":
		_draw_mastery(tw, x, y, s, tm)
	# a violet halo once the ability is learned; the pips below show only the upgrade level
	if tw.has_ability():
		Paint.ellipse_outline(self, Vector2(x, y + s * 0.3), s * 0.46, s * 0.17, Color(0.79, 0.75, 1, 0.5 + 0.3 * sin(tm * 3.0)), 2.0)
	if sq != Vector2.ONE:
		draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_level_badge(Vector2(x + s * 0.3, y + s * 0.3), lv)


## How a tower is squashed this frame: it settles with a little bounce for half a second after
## being built or upgraded.
func _squash(tw: GameSim.Tower) -> Vector2:
	var age := sim.time - tw.born
	var y := 1.0
	if age >= 0.0 and age < 0.6:
		y = 1.0 - 0.28 * cos(age * 22.0) * exp(-age * 9.0)
	if y == 1.0:
		return Vector2.ONE
	return Vector2(1.0 + (1.0 - y) * 0.7, y)


## The upgrade level as a gold Roman numeral on a dark plaque at the tower's foot.
func _draw_level_badge(c: Vector2, lv: int) -> void:
	var txt: String = ["I", "II", "III", "IV"][clampi(lv, 1, 4) - 1]
	var fs := 26
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 14.0
	var r := Rect2(c - Vector2(w / 2.0, 14.0), Vector2(w, 28.0))
	if _plates.is_empty():
		for col in [Color("a07a30"), Color("e8b84a")]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color("1c140c")
			sb.border_color = col
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(6)
			_plates.append(sb)
	draw_style_box(_plates[1 if lv >= 3 else 0], r)
	if lv >= 4:
		draw_rect(r.grow(2.0), Color("ffd86a"), false, 1.5)
	draw_string(font, Vector2(r.position.x + 7.0, c.y + 9.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffd86a"))


## The heroes' baked pictures (HeroSprites), with their shadows and ground rings, drawn behind the
## board. Colours here are premultiplied (see _pm).
func _draw_layer() -> void:
	if sim == null or not HeroSprites.ready():
		return
	var tm := sim.time
	var es: Array = sim.enemies.duplicate()
	es.sort_custom(func(a: GameSim.Enemy, b: GameSim.Enemy) -> bool: return a.pos.y < b.pos.y)
	for e: GameSim.Enemy in es:
		if e.hidden or not HeroSprites.has(e.code):
			continue
		var u: float = e.d["r"] * T * HERO_SCALE
		var hitk := clampf(e.hit / 0.12, 0.0, 1.0)
		var x := (e.pos.x + e.knock.x * hitk) * T
		var yb := (e.pos.y + e.knock.y * hitk) * T
		_ground_marks(_layer, e, x, yb, u, true)
		if sim.flying(e):   # in the air: the shadow stays on the ground
			yb -= Defs.FLY_LIFT * T
		var fr := HeroSprites.frame(e.code, HeroSprites.frame_of(tm * 10.0 * e.d["spd"] + e.bob))
		var src: Rect2 = fr[0]
		var k: float = u / float(fr[2])   # baked size -> drawn size
		var dst := Rect2(x - fr[1].x * k, yb - fr[1].y * k, src.size.x * k, src.size.y * k)
		if e.face < 0:   # mirror about the hero's own x
			_layer.draw_set_transform(Vector2(2.0 * x, 0.0), 0.0, Vector2(-1, 1))
		var tint := Color(0.55, 0.55, 0.62, 1) if e.covered else Color.WHITE
		_layer.draw_texture_rect_region(HeroSprites.atlas, dst, src, tint)
		if hitk > 0.0:   # hit flash: the same picture again, pushed to white
			var a := 0.6 * hitk
			_layer.draw_texture_rect_region(HeroSprites.atlas, dst, src, Color(8.0 * a, 8.0 * a, 8.0 * a, a))
		if e.face < 0:
			_layer.draw_set_transform(Vector2.ZERO)


## A colour as the premultiplied-alpha layer wants it.
static func _pm(c: Color) -> Color:
	return Color(c.r * c.a, c.g * c.a, c.b * c.a, c.a)


## What a hero casts on the ground under him: his shadow, a Herald's ring, a rain cloud's reach and
## an Inquisitor's censer smoke. pm: premultiplied colours (the sprite layer).
func _ground_marks(ci: CanvasItem, e: GameSim.Enemy, x: float, yb: float, u: float, pm: bool) -> void:
	var fix := func(c: Color) -> Color: return _pm(c) if pm else c
	if e.d.has("rain"):   # the reach of its rain cloud
		Paint.ellipse(ci, Vector2(x, yb + u * 0.95), float(e.d["rain"]) * T, float(e.d["rain"]) * T * 0.4, fix.call(Color(0.55, 0.7, 0.9, 0.12)))
	if e.d.has("censer"):   # censer smoke: towers inside are silenced
		var r := float(e.d["censer"]) * T
		Paint.ellipse(ci, Vector2(x, yb + u * 0.95), r, r * 0.45, fix.call(Color(0.7, 0.62, 0.85, 0.13)))
		Paint.ellipse_outline(ci, Vector2(x, yb + u * 0.95), r, r * 0.45, fix.call(Color(0.8, 0.72, 0.95, 0.35)), 1.5)
	Paint.ellipse(ci, Vector2(x, yb + u * 0.95), u * 0.75, u * 0.22, fix.call(Color(0, 0, 0, 0.33)))
	if e.d.has("haste"):  # the Herald's rallying ring on the ground
		Paint.ellipse_outline(ci, Vector2(x, yb + u * 0.95), Defs.HASTE_RANGE * T * 0.5, Defs.HASTE_RANGE * T * 0.16, fix.call(Color(1, 0.8, 0.3, 0.35)), 2.0)


func _draw_enemy(e: GameSim.Enemy, tm: float) -> void:
	var u: float = e.d["r"] * T * HERO_SCALE
	var f := float(e.face)
	var cyc: float = tm * 10.0 * e.d["spd"] + e.bob
	var walk := sin(cyc)
	var bob := absf(cos(cyc)) * u * 0.08
	var hitk := clampf(e.hit / 0.12, 0.0, 1.0)   # 1 just hit, fading to 0
	var x := (e.pos.x + e.knock.x * hitk) * T
	var yb := (e.pos.y + e.knock.y * hitk) * T
	var ground_y := yb
	var lift := Defs.FLY_LIFT * T if sim.flying(e) else 0.0
	yb -= lift
	var y := yb - bob
	var code := e.code
	var baked := HeroSprites.has(code)
	if e.hidden:   # a Diver under water: only a ripple and a reed give him away
		for k in 2:
			var rr := fmod(tm * 0.8 + k * 0.5, 1.0)
			Paint.ellipse_outline(self, Vector2(x, yb + u * 0.6), u * (0.4 + rr), u * (0.15 + rr * 0.35), Color(0.8, 0.9, 1, 0.5 * (1.0 - rr)), 1.5)
		draw_line(Vector2(x + u * 0.2, yb + u * 0.6), Vector2(x + u * 0.3, yb - u * 0.5), Color("6e7c3e"), 2.0, true)
		_draw_gems(Vector2(e.pos.x, e.pos.y - 0.3) * T, e.carry, 0.0)
		return
	if not baked:
		_ground_marks(self, e, x, ground_y, u, false)
	if e.d.has("rage") and e.hp < e.max_hp * 0.5:  # raging
		Paint.glow(self, Vector2(x, y - u * 0.3), u * 1.6, Color(1, 0.2, 0.1, 0.5))
	if not baked:
		var body: PackedVector2Array
		if code == "u":   # the throwing arm: cocked while it waits, swinging through as it looses
			var arm := 0.0
			if e.deployed:
				var since: float = Defs.TREBUCHET["every"] - e.sling
				arm = clampf(since / 0.35, 0.0, 1.0) if e.stones > 0 and since < 1.2 else 0.0
			body = Art.trebuchet(self, x, yb, u, f, tm if not e.deployed else 0.0, arm)
		else:
			body = Art.hero(self, code, x, y, yb, u, f, walk, tm)
		if hitk > 0.0:   # hit flash: the body (and head) blink white
			draw_colored_polygon(body, Color(1, 1, 1, 0.6 * hitk))
			if not code in ["u", "I", "l"]:
				draw_circle(Vector2(x, y - u * 0.68), u * 0.38, Color(1, 1, 1, 0.6 * hitk))
		if e.covered:
			draw_colored_polygon(body, Color(0.05, 0.05, 0.1, 0.4))
	if e.covered:   # in the Belfry's shadow: a small shield says towers can't see him
		draw_arc(Vector2(x, y - u * 0.2), u * 1.0, PI * 1.1, PI * 1.9, 10, Color(0.75, 0.75, 0.85, 0.7), 2.0, true)
	if e.d.has("sapper") and e.fuse >= 0.0:   # the fuse burns
		var sp := Vector2(x - f * u * 0.42, y - u * 0.5 - e.fuse * u * 0.3)
		Paint.glow(self, sp, u * (0.6 + 0.2 * sin(tm * 30.0)), Color(1, 0.7, 0.2, 0.9))
		draw_circle(sp, u * 0.12, Color("fff2c0"))
	if e.mark > 0.0:   # marked by a Hunter's Lodge
		draw_arc(Vector2(x, y - u * 0.2), u * 1.1, 0, TAU, 20, Color(1, 0.3, 0.25, 0.8), 2.0, true)
	if e.slow > 0.0:
		Paint.ellipse(self, Vector2(x, y - u * 0.1), u * 0.75, u * 1.1, Color(0.62, 0.88, 1, 0.25))
		for i in 3:
			var a := sim.time * 2.0 + i * 2.1
			draw_rect(Rect2(x + cos(a) * u * 0.6, y - u * 0.2 + sin(a) * u * 0.7, 2, 2), Color("e6f8ff"))
	if e.fear > 0.0:
		var fy := y - u * 1.75 + sin(sim.time * 14.0) * 1.5
		draw_string_outline(font, Vector2(x - 10, fy), "!!", HORIZONTAL_ALIGNMENT_CENTER, 20, 18, 4, OUTLINE)
		draw_string(font, Vector2(x - 10, fy), "!!", HORIZONTAL_ALIGNMENT_CENTER, 20, 18, Color("c9c0ff"))
	_draw_gems(Vector2(e.pos.x, e.pos.y - e.d["r"] * 2.3 * HERO_SCALE - 0.08) * T - Vector2(0, lift), e.carry, 0.0)
	if e.untouch > 0.0:   # a holy shield, or the Seraph landing: untouchable
		Paint.glow(self, Vector2(x, y - u * 0.4), u * 2.2, Color(1, 0.95, 0.7, 0.5))
		draw_arc(Vector2(x, y - u * 0.4), u * 1.3, 0, TAU, 24, Color(1, 0.92, 0.6, 0.85), 2.5, true)
	if e.chant > 0.0:   # a Spiriter chanting: a ring closing in as the chant runs out
		var ck := e.chant / Defs.CHANT_TIME
		draw_arc(Vector2(x, yb + u * 0.9), u * (1.0 + 1.5 * ck), 0, TAU, 24, Color(0.6, 0.85, 1, 0.8), 2.5, true)
	if e.hp < e.max_hp:
		var w := maxf(16.0, u * 2.6)
		var hy := y - u * float({"k": 1.8, "x": 1.8, "q": 2.6, "T": 2.6, "l": 2.1, "i": 2.0, "u": 2.9, "I": 5.0, "S": 2.4, "j": 1.8, "n": 1.8}.get(code, 1.65)) - 6.0
		draw_rect(Rect2(x - w / 2 - 1, hy - 1, w + 2, 6), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(x - w / 2, hy, w * e.hp / e.max_hp, 4), Color("6fd36f") if e.hp / e.max_hp > 0.4 else Color("e0503a"))


# ---------------------------------------------------------------- shots & effects

func _draw_shot(s: GameSim.Shot) -> void:
	var p := s.pos * T
	var dirv := (s.tpos - s.pos).normalized()
	if dirv == Vector2.ZERO:
		dirv = Vector2.RIGHT
	var n := dirv.orthogonal()
	_draw_trail(s, p, dirv)
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


## A fading streak behind a shot, back toward where it was fired from.
func _draw_trail(s: GameSim.Shot, p: Vector2, dirv: Vector2) -> void:
	var from := (s.src.pos + Vector2(0, -0.25)) if s.src != null else level.lair_center + Vector2(0, -0.5)
	var back := minf(T * 0.7, p.distance_to(from * T))
	if back < 2.0:
		return
	var col: Color = TRAIL.get(s.kind, Color(1, 0.55, 0.2))
	var w: float = 2.0 if s.kind == "arrow" else T * 0.07
	draw_polyline_colors(PackedVector2Array([p - dirv * back, p]), PackedColorArray([Color(col, 0.0), Color(col, col.a)]), w, true)


const TRAIL := {"arrow": Color(1, 1, 1, 0.35), "frost": Color(0.7, 0.92, 1, 0.45), "den": Color(0.55, 0.65, 1, 0.5)}


## Cinder Shrine beam: from the brazier to the hero, orange when cool, white-hot at full heat.
func _draw_beam(tw: GameSim.Tower, tm: float, target: GameSim.Enemy, h: float) -> void:
	var lift := HIGH_LIFT if level.high.has(tw.cell) else 0.0
	var a := (tw.pos + Vector2(0, 0.2 - (0.5 + tw.lvl * 0.07) - 0.1 - lift)) * T   # the flame atop _draw_shrine
	var b := target.pos * T + Vector2(0, -T * 0.15)
	if tw.mastery == "sunlance":   # burns on through to the edge of its reach
		b = (tw.pos + (target.pos - tw.pos).normalized() * tw.stat("range")) * T
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
		"surge", "splash", "flood":   # rings for the Tidecaller's surge, a falling bridge and a sluice
			var e := 1.0 - pow(1.0 - k, 2.0)
			var col: Color = {"surge": Color(0.6, 0.85, 1), "splash": Color(0.8, 0.92, 1), "flood": Color(0.5, 0.8, 1)}[f.kind]
			Paint.ellipse(self, p, f.r * T * e, f.r * T * e * 0.55, Color(col, 0.22 * (1.0 - k)))
			Paint.ellipse_outline(self, p, f.r * T * e, f.r * T * e * 0.55, Color(col, 0.8 * (1.0 - k)), 3.0)
		"shock":   # a ring sweeping out from a meteor strike
			var e := 1.0 - pow(1.0 - k, 3.0)
			draw_arc(p, f.r * T * (0.2 + 0.8 * e), 0, TAU, 48, Color(1, 0.85, 0.55, 0.8 * (1.0 - k)), T * 0.08 * (1.0 - k) + 1.0, true)
		"stone":   # a Trebuchet's stone arcing onto its tower
			if not f.hit:
				var q := f.pos.lerp(f.to, k) * T + Vector2(0, -sin(k * PI) * T * 1.6)
				draw_circle(q + Vector2(2, 3), T * 0.11, Color(0, 0, 0, 0.3))
				draw_circle(q, T * 0.11, Color("8a8478"))
				draw_arc(q, T * 0.11, 0, TAU, 10, Color("3a3430"), 1.5, true)
		"smoke":   # a burst of dust and smoke (a Sapper's blast, a stone landing)
			for i in 5:
				var a := i * TAU / 5.0 + f.pos.x
				var q := p + Vector2(cos(a), sin(a) * 0.5) * f.r * T * (0.3 + 0.7 * k) + Vector2(0, -k * T * 0.4)
				draw_circle(q, T * (0.12 + 0.18 * k), Color(0.45, 0.43, 0.4, 0.55 * (1.0 - k)))
		"text":   # pops in, rises easing out, fades over its last 40%
			var e := 1.0 - pow(1.0 - k, 3.0)
			var fs := int(28.0 * (1.0 + 0.35 * maxf(0.0, 1.0 - k * 8.0)))
			var pos := Vector2(p.x - 80, (f.pos.y - e * 0.6) * T)
			var col := f.color
			col.a = clampf((1.0 - k) / 0.4, 0.0, 1.0)
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
	Art.site(self, s.kind, c, s.owned, tm, s.cell)
	if s.kind == "sluice":   # ready: a soft glow; refilling: a ring filling up
		if s.t <= 0.0:
			Paint.glow(self, c, T * (0.45 + 0.05 * sin(tm * 3.0)), Color(0.5, 0.8, 1, 0.35))
		else:
			var kk: float = 1.0 - s.t / (float(Defs.SITES["sluice"]["recharge"]) * (1.0 - 0.2 * sim.skill("land_flood")))
			draw_arc(c + Vector2(0, -0.1) * T, T * 0.5, -PI / 2, -PI / 2 + TAU * kk, 32, Color(0.5, 0.8, 1, 0.6), 2.5, true)
	if Defs.MUSTER_SITES.has(s.kind) and not s.owned and sim.wave >= 1 and sim.wave < level.waves.size():
		var k := 1.0 - s.t / s.every
		draw_arc(c + Vector2(0, -0.1) * T, T * 0.5, -PI / 2, -PI / 2 + TAU * k, 32, Color(0.6, 0.75, 1, 0.6), 2.5, true)


func _draw_loot(l: GameSim.Loot, tm: float) -> void:
	var p := l.pos * T + Vector2(0, sin(tm * 4.0 + l.pos.x * 3.0) * 3.0)
	if l.t < 0.45:   # just dropped: it pops up out of the fallen hero and lands
		p.y -= sin(l.t / 0.45 * PI) * T * 0.35
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


## Burnt ground where a meteor struck, fading over its last seconds. Drawn under everything else.
func _draw_scorch(f: GameSim.Fx) -> void:
	var p := f.pos * T
	var a := clampf((f.dur - f.t) / 2.0, 0.0, 1.0) * clampf(f.t / 0.1, 0.0, 1.0)
	Paint.ellipse(self, p, f.r * T, f.r * T * 0.6, Color(0.08, 0.05, 0.03, 0.55 * a))
	Paint.ellipse(self, p, f.r * T * 0.6, f.r * T * 0.36, Color(0.04, 0.02, 0.01, 0.5 * a))
	var hot := clampf(1.0 - f.t / 2.5, 0.0, 1.0)   # embers glow at first, then go out
	for i in 7:
		var ang := Paint.hash01(int(f.pos.x * 10.0), int(f.pos.y * 10.0), i) * TAU
		var q := p + Vector2(cos(ang), sin(ang) * 0.6) * f.r * T * (0.3 + 0.6 * Paint.hash01(i, 3, int(f.pos.x)))
		draw_circle(q, T * 0.03, Color(1, 0.45 + 0.3 * hot, 0.1, 0.8 * hot * a) if hot > 0.0 else Color(0.1, 0.07, 0.05, 0.6 * a))



## What a level IV tower became, drawn over its level III look.
func _draw_mastery(tw: GameSim.Tower, x: float, y: float, s: float, tm: float) -> void:
	match tw.mastery:
		"longhouse":   # a second banner and a longer roof
			draw_line(Vector2(x - s * 0.34, y + s * 0.2), Vector2(x - s * 0.34, y - s * 0.62), Color("3a2414"), maxf(2.0, s * 0.035))
			draw_colored_polygon(PackedVector2Array([Vector2(x - s * 0.34, y - s * 0.62), Vector2(x - s * 0.56, y - s * 0.55), Vector2(x - s * 0.34, y - s * 0.46)]), Color("c0283a"))
		"lodge":   # a rack of javelins and antlers over the door
			for d in [-0.14, 0.0, 0.14]:
				draw_line(Vector2(x + s * (0.3 + d), y + s * 0.25), Vector2(x + s * (0.34 + d), y - s * 0.3), Color("dfe6ec"), 2.0)
			draw_arc(Vector2(x, y - s * 0.02), s * 0.12, PI, TAU, 8, Color("f1e6cc"), 2.0)
		"ossuary":   # skulls on the roof, lit by bolts stored
			for k in 4:
				var p := Vector2(x + (k - 1.5) * s * 0.14, y - s * 0.2)
				draw_circle(p, s * 0.05, Color("e9f1f4"))
				if k < tw.charges:
					Paint.glow(self, p, s * 0.09, Color(0.56, 0.88, 1, 0.8))
		"mausoleum":   # a dome
			draw_arc(Vector2(x, y - s * 0.16), s * 0.22, PI, TAU, 14, Color("c3ccd2"), 4.0)
			draw_circle(Vector2(x, y - s * 0.4), s * 0.04, Color("4fd0ff"))
		"twin":   # a second brazier
			Paint.glow(self, Vector2(x + s * 0.26, y - s * 0.38), s * 0.2, Color(1, 0.48, 0.16, 0.55))
			draw_circle(Vector2(x + s * 0.26, y - s * 0.38), s * 0.06, Color("ffd25a"))
		"sunlance":   # a sun disc above the flame
			var c := Vector2(x, y - s * (0.95 + 0.03 * sin(tm * 3.0)))
			Paint.glow(self, c, s * 0.2, Color(1, 0.9, 0.5, 0.7))
			draw_circle(c, s * 0.08, Color("fff2c0"))


## Where the next wave comes from, on lairs whose waves take different roads: its road starts glow.
func _draw_routes(tm: float) -> void:
	if sim.wave >= level.waves.size() or level.wave_roads[sim.wave].is_empty():
		return
	var roads: Array = level.wave_roads[sim.wave].duplicate()
	for r: int in level.wave_rivers[sim.wave]:
		if not roads.has(r) and level.waves[sim.wave].any(func(c: String) -> bool: return Defs.ENEMIES[c].has("boat")):
			roads.append(r)
	var pulse := 0.5 + 0.5 * sin(tm * 4.0)
	for r: int in roads:
		var p := level.path_pos(r, 1.0) * T
		Paint.glow(self, p, T * (0.6 + 0.15 * pulse), Color(1, 0.75, 0.3, 0.35 + 0.25 * pulse))
		draw_arc(p, T * 0.4, 0, TAU, 24, Color(1, 0.85, 0.45, 0.8), 3.0, true)


## How a hindered tower looks: buried under a heap of stones, stunned in smoke with circling sparks,
## or silenced (pale motes drift down over it, and its ability ring is off).
func _draw_status(tw: GameSim.Tower, tm: float) -> void:
	var x := tw.pos.x * T
	var y := tw.pos.y * T - (HIGH_LIFT * T if level.high.has(tw.cell) else 0.0)
	if tw.rubble > 0.0:
		for i in 9:
			var p := Vector2(x + (Paint.hash01(tw.cell.x, tw.cell.y, i) - 0.5) * T * 0.7, y + T * (0.28 - 0.5 * Paint.hash01(tw.cell.y, tw.cell.x, i) * (1.0 - absf(Paint.hash01(tw.cell.x, tw.cell.y, i) - 0.5))))
			draw_circle(p, T * (0.08 + 0.04 * Paint.hash01(i, tw.cell.x, 3)), Color("6e665c").lerp(Color("4a443c"), Paint.hash01(i, 2, tw.cell.y)))
			draw_arc(p, T * 0.09, PI, TAU, 6, Color(0.1, 0.08, 0.06, 0.6), 1.0)
		for k in 2:   # dust
			var q := fmod(tm * 0.5 + k * 0.5, 1.0)
			draw_circle(Vector2(x + (k - 0.5) * T * 0.4, y - q * T * 0.5), T * (0.1 + 0.1 * q), Color(0.6, 0.55, 0.48, 0.3 * (1.0 - q)))
	if tw.stun > 0.0:
		for k in 3:
			var q := fmod(tm * 0.6 + k / 3.0, 1.0)
			draw_circle(Vector2(x + sin(tm * 2.0 + k) * T * 0.15, y - T * (0.4 + q * 0.6)), T * (0.1 + 0.12 * q), Color(0.35, 0.35, 0.38, 0.5 * (1.0 - q)))
		for k in 3:   # sparks circling the top
			var a := tm * 4.0 + k * TAU / 3.0
			var p := Vector2(x + cos(a) * T * 0.3, y - T * 0.75 + sin(a) * T * 0.08)
			draw_line(p - Vector2(3, 0), p + Vector2(3, 0), Color("ffe08a"), 1.5)
			draw_line(p - Vector2(0, 3), p + Vector2(0, 3), Color("ffe08a"), 1.5)
	if tw.silence > 0.0:
		for k in 5:
			var q := fmod(tm * 0.35 + k / 5.0, 1.0)
			var p := Vector2(x + (Paint.hash01(k, tw.cell.x, 7) - 0.5) * T * 0.7, y - T * (0.9 - q * 1.1))
			draw_circle(p, T * 0.035, Color(0.9, 0.86, 1.0, 0.75 * sin(q * PI)))


## Road paved by Paviors: cobbles along the stretch, fading out over its last seconds.
func _draw_paving() -> void:
	for i in sim.paved.size():
		for p: Dictionary in sim.paved[i]:
			var a := clampf((float(p["until"]) - sim.time) / 4.0, 0.0, 1.0)
			var d := float(p["from"])
			var n := 0
			while d < float(p["to"]):
				var q := level.path_pos(i, d) * T
				var side := (Paint.hash01(i, n, 5) - 0.5) * T * 0.4
				var r := Rect2(q + Vector2(side - T * 0.07, -T * 0.05), Vector2(T * 0.14, T * 0.1))
				draw_rect(r, Color(0.62, 0.58, 0.52, 0.75 * a))
				draw_rect(r, Color(0.25, 0.22, 0.2, 0.6 * a), false, 1.0)
				d += 0.12
				n += 1


## Flight lines (air roads) as faint dashed lines, and hallowed ground glowing pale gold while a
## Chapel stands.
func _draw_sky(tm: float) -> void:
	for i in level.paths.size():
		if level.path_kind[i] != "air":
			continue
		var total: float = level.paths[i]["total"]
		var d := fmod(tm * 0.6, 0.5)
		while d < total:
			var a := level.path_pos(i, d) * T
			var b := level.path_pos(i, minf(total, d + 0.22)) * T
			draw_line(a, b, Color(0.9, 0.92, 1, 0.32), 2.0, true)
			d += 0.5
	if sim.hallow_on():
		for c: Vector2i in level.hallowed:
			var r := Rect2(Vector2(c) * T, Vector2(T, T)).grow(-3.0)
			var pulse := 0.5 + 0.5 * sin(tm * 1.5 + c.x + c.y)
			draw_rect(r, Color(1, 0.92, 0.6, 0.12 + 0.08 * pulse))
			draw_rect(r, Color(1, 0.9, 0.55, 0.45), false, 1.5)
