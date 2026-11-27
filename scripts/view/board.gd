extends Node2D
## Draws everything that moves: the gem pile, towers, heroes, shots and effects.
## Redrawn every frame by main.gd.
##
## Almost everything here is drawn from pictures baked once into SpriteCache atlas pages: towers
## (with their platform, mastery and the frames of what moves on them), level badges, buildings,
## gems, glows, discs, rings, shots, cobbles and the "!!" of Dread. A frame is then a few hundred
## textured rectangles from one or two textures, which batch, instead of thousands of polygons.
## Pictures are baked as a battle opens (_prebake) at the Quality's scale; one that is not baked yet
## is drawn shape by shape for those frames, as it always was, and headless runs (which bake
## nothing) draw everything that way. Only rare or ever-changing things stay live shapes:
## progress arcs, fog, floating text, the tile selection, a few short effects.

const T := 64.0
const OUTLINE := Color("1a120c")
const HIGH_LIFT := 0.18   # towers on raised tiles stand this much higher, on the rock top
const HERO_SCALE := 1.2   # heroes are drawn this much larger than their body radius
const FOG_PX := 4         # night fog pixels per tile
## Health bar height over each hero, in body units (any other: 1.65).
const BAR_Y := {"k": 1.8, "x": 1.8, "q": 2.6, "T": 2.6, "l": 2.1, "i": 2.0, "u": 2.9, "I": 5.0, "S": 2.4, "j": 1.8, "n": 1.8}
## Tower animation loops: [seconds, frames at Detailed, frames at Light]. What moves: the Hut's
## banner, the Crypt's floating crystal (level III only), the Shrine's flame (its runes pulse
## live over the picture). Firing pictures (flash) of a Hut or Crypt have half the frames: they
## show for a moment; a Shrine flashes all the while its beam burns, so it has them all.
const TOWER_LOOP := {"moss": [TAU / 5.0, 8, 4], "frost": [TAU / 3.0, 8, 4], "ash": [TAU / 12.0, 6, 4]}
## Buildings' loops by kind: [loop when owned, loop when not], each [seconds, frames] or [] (still).
const SITE_LOOP := {
	"altar": [[TAU / 4.0, 12], []], "sluice": [[TAU / 3.0, 12], [TAU / 3.0, 12]], "mine": [[1.25, 10], []],
	"well": [[1.0 / 0.6, 12], []], "camp": [[TAU / 5.0, 8], [TAU / 5.0, 8]], "beacon": [[], [2.5, 16]],
	"workshop": [[], [PI / 4.0 / 0.8, 8]], "chapel": [[], [PI, 8]],
}
const R := 32.0           # radius the round pictures (glow, disc, rings) are baked at
## The ability halo's colour, one per tower so a learned ability is easy to spot: Hut green, Crypt ice blue,
## Shrine orange (violet for any other).
const HALO := {"moss": Color(0.45, 1.0, 0.4), "frost": Color(0.45, 0.85, 1.0), "ash": Color(1.0, 0.55, 0.2)}


static func halo_color(type: String, a: float) -> Color:
	var c: Color = HALO.get(type, Color(0.79, 0.75, 1))
	c.a = a
	return c
const RING_MIN := 0.02    # width / radius of the thinnest baked ring; each next one is RING_STEP wider
const RING_STEP := 1.25
const RINGS := 14
const TOWER_BOX := Rect2(-0.62 * T, -1.16 * T, 1.24 * T, 1.68 * T)   # a tower picture around (x, y)
const SITE_BOX := Rect2(-0.72 * T, -1.85 * T, 1.44 * T, 2.35 * T)    # a building around its tile centre

var level: Level
var sim: GameSim
var font: Font
var selected := Vector2i(-1, -1)
var armed := false
## Kinds of drawing switched off, to measure what each costs (tests/perf.gd only).
var perf_off := {}

var _fog: ImageTexture
var _bursts: Node2D      # particle bursts (bursts.gd), drawn over the board
var _plates: Array = []  # level badge backgrounds: levels I-II, level III
## Heroes as baked pictures (HeroSprites): drawn behind the board's own drawing (so their health
## bars, chill and carried gems go on top), with premultiplied blending to match the atlas.
var _layer: Node2D
## The ground marks under those heroes (shadows, rings, censer smoke), drawn just before them.
var _marks: Node2D
## What lies on the ground, under every hero: the hoard, scorch, lava, paving, the tide's flood and
## planks, raised-tile shimmer, road starts, flight lines, hallowed tiles.
var _fl: Node2D
var _flood: ImageTexture   # where the high tide floods fords: a soft mask, FLOOD_PX pixels a tile
const FLOOD_PX := 8
const FLOOD_TINT := Color(0.06, 0.17, 0.22)   # the deep water's own colour (ground.gdshader)
var _es: Array = []      # heroes nearest the top first, sorted once a frame (_process)
var _tws: Array = []     # towers likewise; re-sorted only when towers come or go
var _ring_pos: Array = []   # the hoard's gem places, nearest the top first
var _cache_key := ""     # the lair and scale the cache was baked for
var _wanted := {}        # groups of pictures already asked for this cache
# Atlas entries of the most drawn pictures, fetched once a frame ([] while not baked).
var _a_glow: Array = []
var _a_disc: Array = []
var _a_white: Array = []
var _a_rings: Array = []


func setup(lv: Level, s: GameSim, f: Font) -> void:
	level = lv
	sim = s
	font = f
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sim.light_changed.connect(_build_fog)
	_build_fog()
	_build_flood()
	SpriteCache.setup(self)
	if _bursts == null:
		_bursts = preload("res://scripts/view/bursts.gd").new()
		add_child(_bursts)
	if _layer == null:
		_fl = Node2D.new()   # first: under the heroes' marks and the heroes
		_fl.show_behind_parent = true
		_fl.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_fl.draw.connect(_draw_floor)
		add_child(_fl)
		_marks = Node2D.new()
		_marks.show_behind_parent = true
		_marks.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_marks.draw.connect(_draw_marks)
		add_child(_marks)
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
	_tws.clear()
	_es.clear()
	# The hoard: one place per gem on a ring in the cave mouth, so taken gems leave a gap.
	var slots := maxi(1, level.gems)
	_ring_pos.clear()
	for i in slots:
		var a := TAU * i / slots - PI / 2.0
		_ring_pos.append((level.lair_center + Vector2(0, 0.38) + Vector2(cos(a) * 0.32, sin(a) * 0.16)) * T)
	_ring_pos.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)


## Night darkness: FOG_PX pixels per tile, stretched with smoothing. Each light (GameSim.lights)
## clears a soft-edged circle, so the light pools read as lamplight; a tile whose centre is inside a
## light is lit for building (GameSim.is_lit), which is where the pool is brightest. Built as raw
## bytes in one go: lights change mid-battle (a tower built at night, an eclipse coming).
func _build_fog() -> void:
	if not sim.can_dark():
		_fog = null
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
	var bytes := PackedByteArray()
	bytes.resize(w * h * 4)
	var r8 := roundi(0.02 * 255.0)
	var b8 := roundi(0.07 * 255.0)
	for i in w * h:
		bytes[i * 4] = r8
		bytes[i * 4 + 1] = r8
		bytes[i * 4 + 2] = b8
		bytes[i * 4 + 3] = roundi(0.82 * (1.0 - light[i]) * 255.0)
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, bytes)
	if _fog != null and _fog.get_width() == w and _fog.get_height() == h:
		_fog.update(img)
	else:
		_fog = ImageTexture.create_from_image(img)


## Where the high tide floods: every ford tile, its outline softened over about a third of a tile
## and made to wander (value noise), running on further and fading out where the ford meets water
## or shallows, so the flood joins the water around it with no edge. Built once per lair.
func _build_flood() -> void:
	_flood = null
	if sim.tide.x <= 0.0:
		return
	var fords := {}
	for i in level.crossing_cells.size():
		if level.crossing_kind[i] == "ford":
			for c: Vector2i in level.crossing_cells[i]:
				fords[c] = true
	if fords.is_empty():
		return
	var w := (level.cols + 2) * FLOOD_PX
	var h := (level.rows + 2) * FLOOD_PX
	var bytes := PackedByteArray()
	bytes.resize(w * h * 4)
	bytes.fill(255)
	for py in h:
		for px in w:
			var p := Vector2((px + 0.5) / FLOOD_PX - 1.0, (py + 0.5) / FLOOD_PX - 1.0)
			var cell := Vector2i(floori(p.x), floori(p.y))
			var d := 9.0   # distance to the nearest ford tile
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var c := cell + Vector2i(dx, dy)
					if fords.has(c):
						var q := (p - Vector2(c) - Vector2(0.5, 0.5)).abs() - Vector2(0.5, 0.5)
						d = minf(d, Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length())
			var wet := level.is_water(cell) and not fords.has(cell)
			var jitter := (_vnoise(p * 3.0) - 0.5) * 0.22
			var v := 1.0 - smoothstep(-0.12, 0.5 if wet else 0.22, d + jitter)
			bytes[(py * w + px) * 4 + 3] = roundi(clampf(v, 0.0, 1.0) * 255.0)
	_flood = ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, bytes))


## Smooth value noise in [0, 1): stable hashes on a grid, blended between.
static func _vnoise(p: Vector2) -> float:
	var i := Vector2i(floori(p.x), floori(p.y))
	var f := p - Vector2(i)
	f = f * f * (Vector2(3, 3) - 2.0 * f)
	var a := lerpf(Paint.hash01(i.x, i.y, 77), Paint.hash01(i.x + 1, i.y, 77), f.x)
	var b := lerpf(Paint.hash01(i.x, i.y + 1, 77), Paint.hash01(i.x + 1, i.y + 1, 77), f.x)
	return lerpf(a, b, f.y)


## How far night has come in: 1 on a night mission, fading over a few seconds as Dusk or an Eclipse comes and goes.
func _night_k() -> float:
	return sim.dark_k()


# ---------------------------------------------------------------- per frame

func _process(_delta: float) -> void:
	if sim == null:
		return
	if not is_visible_in_tree():   # the map is up: let the pictures go
		if _cache_key != "":
			SpriteCache.clear()
			_cache_key = ""
		return
	_sync_cache()
	_es.assign(sim.enemies)
	_es.sort_custom(_above)
	if _tws.size() != sim.towers.size() or _tws.any(_gone):
		_tws.assign(sim.towers.values())
		_tws.sort_custom(_above)
	if _layer != null:
		_layer.visible = not perf_off.has("heroes")
		_marks.visible = _layer.visible
		_layer.queue_redraw()
		_marks.queue_redraw()
		_fl.queue_redraw()


func _draw_floor() -> void:
	if sim == null:
		return
	var tm := sim.time
	_fetch()
	if not perf_off.has("gems"):
		for i in mini(sim.home, _ring_pos.size()):
			_gem(_fl, _ring_pos[i], T * 0.1)
	if perf_off.has("ground_fx"):
		return
	for f: GameSim.Fx in sim.fx:
		if f.kind == "scorch":
			_draw_scorch(f)
	for pl: GameSim.Pool in sim.pools:
		_draw_pool(pl, tm)
	_draw_paving()
	_draw_water_state(tm)
	for c: Vector2i in level.high:
		_draw_high_shine(c, tm)
	_draw_routes(tm)
	_draw_sky(tm)


static func _above(a: Variant, b: Variant) -> bool:
	return a.pos.y < b.pos.y


func _gone(tw: GameSim.Tower) -> bool:
	return sim.towers.get(tw.cell) != tw


func _draw() -> void:
	if sim == null:
		return
	var tm := sim.time
	var off := perf_off
	_fetch()
	_draw_selection()
	if not off.has("ground_fx"):
		_draw_den_charges(tm)
	if not off.has("sites"):
		for s: GameSim.Site in sim.sites.values():
			_draw_site(s, tm)
	if not off.has("towers"):
		for tw: GameSim.Tower in _tws:
			_draw_tower(tw, tm)
			_draw_status(tw, tm)
	if not off.has("gems"):
		for g: GameSim.Drop in sim.drops:
			var at := g.pos * T + Vector2(0, (-0.1 + sin(tm * 5.0) * 0.05) * T)
			if g.fall > 0.0:   # dropped by a flying carrier: it falls from where it was carried to the road
				var k := 1.0 - g.fall / Defs.DROP_FALL
				var top := g.from * T - Vector2(0, (Defs.FLY_LIFT + 0.45) * T)
				draw_circle(g.pos * T + Vector2(0, 0.05 * T), (0.08 + 0.1 * k) * T, Color(0, 0, 0, 0.25 * k))
				at = top.lerp(at, k * k)   # speeding up as it falls
			_draw_gems(at, g.n, 0.3)
	if not off.has("overlays"):
		for e: GameSim.Enemy in _es:
			_draw_enemy(e, tm)
	if not off.has("shots"):
		for s: GameSim.Shot in sim.shots:
			_draw_shot(s)
		for tw: GameSim.Tower in _tws:
			if tw.beam != null:
				_draw_beam(tw, tm, tw.beam, tw.heat)
			if tw.beam2 != null:
				_draw_beam(tw, tm, tw.beam2, tw.heat2)
	var full := Rect2(0, 0, level.cols * T, level.rows * T)
	if _fog != null and _night_k() > 0.001 and not off.has("fog"):
		var k := _night_k()
		_rect(self, full, Color(0.05, 0.07, 0.2, 0.22 * k))
		draw_texture_rect_region(_fog, full, Rect2(FOG_PX, FOG_PX, level.cols * FOG_PX, level.rows * FOG_PX), Color(1, 1, 1, k))
		for l: Array in sim.lights:   # warm lamplight in each pool
			_glow(self, l[0] * T, l[1] * T * 0.9, Color(1, 0.72, 0.38, 0.13 * k))
	if not off.has("fx"):
		for l: GameSim.Loot in sim.loot:
			_draw_loot(l, tm)
		for f: GameSim.Fx in sim.fx:
			_draw_fx(f)
	if armed:
		_rect(self, full, Color(1, 0.42, 0.13, 0.09))


# ---------------------------------------------------------------- the picture cache

## The cache belongs to one lair at one scale: a new lair, window scale or quality bakes afresh.
func _sync_cache() -> void:
	if not SpriteCache.enabled():
		return
	var k := Quality.bake_scale(Quality.screen_scale(self))
	var key := "%s|%d|%.2f|%d" % [level.id, sim.get_instance_id(), k, Quality.version]
	if key == _cache_key:
		return
	var lair_same := _cache_key.get_slice("|", 0) == level.id
	var same_lair := lair_same and _cache_key.get_slice("|", 2) == "%.2f" % k and _cache_key.get_slice("|", 3) == str(Quality.version)
	_cache_key = key
	if same_lair:
		return   # a restart of the same lair: the pictures still fit
	if lair_same and SpriteCache.find("glow").size() > 0:
		SpriteCache.renew()   # same lair, new scale or quality: the old pictures stand in meanwhile
	else:
		SpriteCache.clear()
	SpriteCache.scale = k
	_wanted.clear()
	_prebake()


func _fetch() -> void:
	_a_glow = SpriteCache.find("glow")
	_a_disc = SpriteCache.find("disc")
	_a_white = SpriteCache.find("white")
	if _a_rings.size() != RINGS:
		_a_rings.resize(RINGS)
	for i in RINGS:
		_a_rings[i] = SpriteCache.find("ring|%d" % i)


## Everything this lair can show, asked for while the start card is up.
func _prebake() -> void:
	var w := Color.WHITE
	SpriteCache.want("glow", Rect2(-R, -R, R * 2, R * 2), func(ci: CanvasItem, at: Vector2) -> void: Paint.glow(ci, at, R, w))
	SpriteCache.want("disc", Rect2(-R - 2, -R - 2, R * 2 + 4, R * 2 + 4), func(ci: CanvasItem, at: Vector2) -> void: ci.draw_circle(at, R, w, true, -1.0, true))
	SpriteCache.want("white", Rect2(-4, -4, 8, 8), func(ci: CanvasItem, at: Vector2) -> void: ci.draw_rect(Rect2(at - Vector2(4, 4), Vector2(8, 8)), w))
	for i in RINGS:
		var rw := R * RING_MIN * pow(RING_STEP, i)
		SpriteCache.want("ring|%d" % i, Rect2(-R - rw - 2, -R - rw - 2, (R + rw + 2) * 2, (R + rw + 2) * 2),
			func(ci: CanvasItem, at: Vector2) -> void: ci.draw_arc(at, R, 0, TAU, 96, w, rw, true))
	SpriteCache.want("gem", Rect2(-0.13 * T, -0.11 * T, 0.26 * T, 0.25 * T), func(ci: CanvasItem, at: Vector2) -> void: Paint.gem(ci, at, T * 0.12))
	SpriteCache.want("halo", Rect2(-0.46 * T - 4, -0.17 * T - 4, 0.92 * T + 8, 0.34 * T + 8),
		func(ci: CanvasItem, at: Vector2) -> void: Paint.ellipse_outline(ci, at, T * 0.46, T * 0.17, w, 2.0))
	for lv in range(1, 5):
		SpriteCache.want("b|%d" % lv, Rect2(-34, -18, 68, 36), func(ci: CanvasItem, at: Vector2) -> void: _paint_badge(ci, at, lv))
	for n in range(2, 10):
		_want_text("n|%d" % n, "%d" % n, 20, Color("ff9aae"), OUTLINE, -1)
	_want_text("fear", "!!", 18, Color("c9c0ff"), OUTLINE, 20)
	for v in 8:
		SpriteCache.want("orb|%d" % v, Rect2(-36, -36, 72, 72), func(ci: CanvasItem, at: Vector2) -> void: _paint_orb(ci, at, 10.0, v * 13 + 1, 0))
	_want_shots()
	SpriteCache.want("cob", Rect2(-0.07 * T - 2, -0.05 * T - 2, 0.14 * T + 4, 0.1 * T + 4), func(ci: CanvasItem, at: Vector2) -> void:
		var r := Rect2(at + Vector2(-0.07, -0.05) * T, Vector2(0.14, 0.1) * T)
		ci.draw_rect(r, Color(0.62, 0.58, 0.52, 0.75))
		ci.draw_rect(r, Color(0.25, 0.22, 0.2, 0.6), false, 1.0))
	SpriteCache.want("glint", Rect2(-6, -6, 12, 12), func(ci: CanvasItem, at: Vector2) -> void:
		var s := T * 0.06
		ci.draw_line(at - Vector2(s, 0), at + Vector2(s, 0), w, 1.5, true)
		ci.draw_line(at - Vector2(0, s), at + Vector2(0, s), w, 1.5, true))
	SpriteCache.want("hal", Rect2(1, 1, T - 2, T - 2), func(ci: CanvasItem, at: Vector2) -> void:
		ci.draw_rect(Rect2(at, Vector2(T, T)).grow(-3.0), Color(1, 0.9, 0.55, 0.45), false, 1.5))
	# The top half of a ring, 1 px wide at the size rubble stones are drawn.
	SpriteCache.want("harc", Rect2(-R - 4, -R - 4, R * 2 + 8, R + 8), func(ci: CanvasItem, at: Vector2) -> void:
		ci.draw_arc(at, R, PI, TAU, 24, w, R / (T * 0.09), true))
	for kind in ["coin", "potion"]:
		SpriteCache.want(kind, Rect2(-0.33 * T, -0.33 * T, 0.66 * T, 0.66 * T), func(ci: CanvasItem, at: Vector2) -> void: _paint_loot(ci, at, kind))
	# Towers: every level and mastery of each kind this lair's ground allows.
	var types := {}
	for c: Vector2i in level.terrain:
		if Defs.TOWERS.has(level.terrain_at(c)):
			types[level.terrain_at(c)] = true
		if level.high.has(c):
			for t: String in Defs.TOWERS:
				types[t] = true
	for t: String in types:
		for lv in range(1, 4):
			_want_tower(t, lv, "")
		for m: Dictionary in Defs.MASTERIES[t]:
			_want_tower(t, 4, m["id"])
	for s: GameSim.Site in sim.sites.values():
		_want_site(s, false)
		_want_site(s, true)
		if s.kind == "workshop":
			_want_engines("u")   # it rolls out Trebuchets
	if level.crossing_kind.has("ford"):   # the tide's ripples, every size they grow through
		for q in 9:
			_eoutline_key(T * (0.12 + 0.25 * q / 8.0), T * (0.05 + 0.1 * q / 8.0), 1.5, true)
	# Rings that heroes of this lair carry on the ground: censer smoke, the Herald's rally, a
	# hidden Diver's ripples.
	var codes := {}
	for wv: Array in level.waves:
		for code: String in wv:
			codes[code] = true
	for code: String in codes:
		var d: Dictionary = Defs.ENEMIES[code]
		if code == "u" or code == "I":
			_want_engines(code)
		if d.has("censer"):
			_eoutline_key(float(d["censer"]) * T, float(d["censer"]) * T * 0.45, 2.5, true)
		if d.has("haste"):
			_eoutline_key(Defs.HASTE_RANGE * T * 0.5, Defs.HASTE_RANGE * T * 0.16, 3.0, true)
		if d.has("dive") or code == "d":
			var u := float(d["r"]) * T * HERO_SCALE
			for q in 9:
				_eoutline_key(u * (0.4 + q / 8.0), u * (0.15 + q / 8.0 * 0.35), 1.5, true)


## A line of text with its outline, baked: drawn later at its baseline origin as draw_string would.
func _want_text(key: String, txt: String, size: int, fill: Color, edge: Color, width: int) -> void:
	var asc := font.get_ascent(size)
	var desc := font.get_descent(size)
	var tw := maxf(font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, width)
	var align := HORIZONTAL_ALIGNMENT_LEFT if width < 0 else HORIZONTAL_ALIGNMENT_CENTER
	SpriteCache.want(key, Rect2(-8, -asc - 6, tw + 16, asc + desc + 12), func(ci: CanvasItem, at: Vector2) -> void:
		ci.draw_string_outline(font, at, txt, align, width, size, 4, edge)
		ci.draw_string(font, at, txt, align, width, size, fill))


func _frames(n: int) -> int:
	return maxi(1, n if not Quality.light() else mini(n, maxi(4, n / 2)))


func _tower_frames(type: String, lv: int, flash: bool) -> int:
	if type == "frost" and lv != 3:
		return 1   # only the level III Crypt's crystal moves
	var n := _frames(TOWER_LOOP[type][2] if Quality.light() else TOWER_LOOP[type][1])
	return n if not flash or type == "ash" else maxi(1, n / 2)


## All the pictures of one tower look: every frame of its loop, flashing and not (and, for an
## Ossuary, with each count of stored bolts).
func _want_tower(type: String, lv: int, mastery: String) -> void:
	var g := "t|%s|%d|%s" % [type, lv, mastery]
	if _wanted.has(g) or not SpriteCache.enabled():
		return
	_wanted[g] = true
	var period: float = TOWER_LOOP[type][0]
	for charges in (range(5) if mastery == "ossuary" else [0]):
		for flash in [false, true]:
			var n := _tower_frames(type, lv, flash)
			for f in n:
				var tmb := (f + 0.5) / n * period
				SpriteCache.want(_tower_key_of(type, lv, mastery, charges, flash, f), TOWER_BOX, func(ci: CanvasItem, at: Vector2) -> void:
					_paint_tower(ci, at.x, at.y, T, type, lv, mastery, charges, flash, tmb, 0.0, Vector2.ZERO, false))


static func _tower_key_of(type: String, lv: int, mastery: String, charges: int, flash: bool, f: int) -> String:
	return "t|%s|%d|%s|%d|%d|%d" % [type, lv, mastery, charges, 1 if flash else 0, f]


func _tower_key(tw: GameSim.Tower, tm: float) -> String:
	var n := _tower_frames(tw.type, tw.lvl, tw.flash > 0.0)
	var f := 0
	if n > 1:
		var period: float = TOWER_LOOP[tw.type][0]
		# Each tower's own phase: the Hut's banner waves with its x (as Art.hut's seed), the
		# Shrine's flame too (Art.shrine).
		var t := tm + (tw.pos.x / 5.0 if tw.type == "moss" else tw.pos.x / 4.0 if tw.type == "ash" else 0.0)
		f = int(fposmod(t, period) / period * n) % n
	return _tower_key_of(tw.type, tw.lvl, tw.mastery, tw.charges if tw.mastery == "ossuary" else 0, tw.flash > 0.0, f)


func _site_loop(s: GameSim.Site, owned: bool) -> Array:
	var l: Array = SITE_LOOP.get(s.kind, [[], []])[0 if owned else 1]
	return [] if l.is_empty() else [l[0], _frames(l[1])]


func _want_site(s: GameSim.Site, owned: bool) -> void:
	var g := "s|%d|%d|%d" % [s.cell.x, s.cell.y, 1 if owned else 0]
	if _wanted.has(g) or not SpriteCache.enabled():
		return
	_wanted[g] = true
	var l := _site_loop(s, owned)
	var n: int = 1 if l.is_empty() else l[1]
	var kind := s.kind
	var cell := s.cell
	for f in n:
		var tmb: float = 0.0 if l.is_empty() else (f + 0.5) / n * float(l[0])
		SpriteCache.want("s|%d|%d|%d|%d" % [cell.x, cell.y, 1 if owned else 0, f], SITE_BOX, func(ci: CanvasItem, at: Vector2) -> void:
			Paint.ellipse(ci, at + Vector2(0.03, 0.3) * T, T * 0.44, T * 0.14, Color(0, 0, 0, 0.35))
			Art.site(ci, kind, at, owned, tmb, cell))


func _site_key(s: GameSim.Site, tm: float) -> String:
	var l := _site_loop(s, s.owned)
	var f := 0
	if not l.is_empty():
		f = int(fposmod(tm, l[0]) / l[0] * l[1]) % int(l[1])
	return "s|%d|%d|%d|%d" % [s.cell.x, s.cell.y, 1 if s.owned else 0, f]


func _want_shots() -> void:
	var w := Color.WHITE
	SpriteCache.want("sh|arrow", Rect2(-0.28 * T, -0.07 * T, 0.36 * T, 0.14 * T), func(ci: CanvasItem, at: Vector2) -> void:
		_paint_shot(ci, at, Vector2.RIGHT, "arrow"))
	SpriteCache.want("sh|frost", Rect2(-0.34 * T, -0.19 * T, 0.53 * T, 0.38 * T), func(ci: CanvasItem, at: Vector2) -> void:
		_paint_shot(ci, at, Vector2.RIGHT, "frost"))
	SpriteCache.want("sh|den", Rect2(-0.36 * T, -0.09 * T, 0.4 * T, 0.18 * T), func(ci: CanvasItem, at: Vector2) -> void:
		_paint_shot(ci, at, Vector2.RIGHT, "den"))
	SpriteCache.want("sh|fire", Rect2(-0.56 * T, -0.32 * T, 0.88 * T, 0.64 * T), func(ci: CanvasItem, at: Vector2) -> void:
		_paint_shot(ci, at, Vector2.RIGHT, "fire"))
	# A soft white streak fading in toward its head, and a straight soft line: trails, beams, dashes.
	SpriteCache.want("trail", Rect2(-66, -4, 68, 8), func(ci: CanvasItem, at: Vector2) -> void:
		ci.draw_polyline_colors(PackedVector2Array([at + Vector2(-64, 0), at]), PackedColorArray([Color(1, 1, 1, 0), w]), 4.0, true))
	SpriteCache.want("beam", Rect2(-2, -6, 68, 12), func(ci: CanvasItem, at: Vector2) -> void:
		ci.draw_line(at, at + Vector2(64, 0), w, 8.0, true))
	SpriteCache.want("dash", Rect2(-2, -3, 68, 6), func(ci: CanvasItem, at: Vector2) -> void:
		ci.draw_line(at, at + Vector2(64, 0), w, 2.0, true))


# ---------------------------------------------------------------- fast shapes from the atlas

## A soft glow (Paint.glow) from the atlas.
func _glow(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if _a_glow.is_empty():
		Paint.glow(ci, c, r, col)
		return
	ci.draw_texture_rect_region(_a_glow[0], Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), _a_glow[1], col)


## A filled circle (draw_circle) from the atlas.
func _circle(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if _a_disc.is_empty():
		ci.draw_circle(c, r, col)
		return
	var b: Rect2 = _a_disc[2]
	var k := r / R
	ci.draw_texture_rect_region(_a_disc[0], Rect2(c + b.position * k, b.size * k), _a_disc[1], col)


## A filled ellipse (Paint.ellipse) from the atlas.
func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	if _a_disc.is_empty():
		Paint.ellipse(ci, c, rx, ry, col)
		return
	var b: Rect2 = _a_disc[2]
	var k := Vector2(rx, ry) / R
	ci.draw_texture_rect_region(_a_disc[0], Rect2(c + b.position * k, b.size * k), _a_disc[1], col)


## A filled rectangle from the atlas's white square, so it batches with the pictures around it.
func _rect(ci: CanvasItem, r: Rect2, col: Color) -> void:
	if _a_white.is_empty():
		ci.draw_rect(r, col)
		return
	var src: Rect2 = _a_white[1]
	ci.draw_texture_rect_region(_a_white[0], r, Rect2(src.get_center() - Vector2(1, 1), Vector2(2, 2)), col)


## A full circle outline (draw_arc over TAU, antialiased): the baked ring whose width-to-radius
## is nearest, scaled. Big circles (wider than the baked ones read well) stay live.
func _ring(ci: CanvasItem, c: Vector2, r: float, w: float, col: Color) -> void:
	var i := clampi(roundi(log(w / maxf(r, 0.01) / RING_MIN) / log(RING_STEP)), 0, RINGS - 1)
	var e: Array = _a_rings[i] if _a_rings.size() == RINGS else []
	if e.is_empty() or r > 2.0 * R:
		ci.draw_arc(c, r, 0, TAU, 24, col, w, true)
		return
	var b: Rect2 = e[2]
	var k := r / R
	ci.draw_texture_rect_region(e[0], Rect2(c + b.position * k, b.size * k), e[1], col)


## The key of an ellipse outline of about this size: sizes go in steps of 12%, the shape in 2%
## steps and the width in half pixels, so growing ripples share a handful of pictures.
func _eoutline_key(rx: float, ry: float, w: float, want: bool) -> String:
	var qr := pow(1.12, roundf(log(maxf(rx, 1.0)) / log(1.12)))
	var asp := snappedf(ry / maxf(rx, 0.01), 0.02)
	var qw := snappedf(w, 0.5)
	var key := "eo|%.2f|%.2f|%.1f" % [qr, asp, qw]
	if want and not SpriteCache.has(key):
		var m := qr + qw + 2.0
		var my := qr * asp + qw + 2.0
		SpriteCache.want(key, Rect2(-m, -my, m * 2, my * 2), func(ci: CanvasItem, at: Vector2) -> void:
			Paint.ellipse_outline(ci, at, qr, qr * asp, Color.WHITE, qw))
	return key


## An ellipse outline (Paint.ellipse_outline) from the atlas, baked the first time it is needed.
## krx, kry: the size whose picture to use (growing ripples pass one of their 9 baked steps).
func _eoutline(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, w: float, krx := -1.0, kry := -1.0) -> void:
	var key := _eoutline_key(rx if krx < 0.0 else krx, ry if kry < 0.0 else kry, w, true)
	var e := SpriteCache.find(key)
	if e.is_empty():
		Paint.ellipse_outline(ci, c, rx, ry, col, w)
		return
	var qr := float(key.get_slice("|", 1))
	var b: Rect2 = e[2]
	var k := rx / qr
	ci.draw_texture_rect_region(e[0], Rect2(c + b.position * k, b.size * k), e[1], col)


## A baked picture drawn along a direction: anchor at `at`, rotated to `dir`, stretched by k.
func _put_along(ci: CanvasItem, e: Array, at: Vector2, dir: Vector2, k: Vector2, col: Color) -> void:
	var b: Rect2 = e[2]
	ci.draw_set_transform(at, dir.angle())
	ci.draw_texture_rect_region(e[0], Rect2(b.position * k, b.size * k), e[1], col)
	ci.draw_set_transform(Vector2.ZERO)


func _gem(ci: CanvasItem, c: Vector2, s: float) -> void:
	if not SpriteCache.put(ci, "gem", c, Color.WHITE, Vector2.ONE * (s / (T * 0.12))):
		Paint.gem(ci, c, s)


## n gems side by side, far enough apart that each one shows; glow 0 is the small halo
## of a carried gem, more for gems lying on the road.
func _draw_gems(c: Vector2, n: int, glow: float) -> void:
	var gap := T * 0.3
	for i in n:
		var gp := c + Vector2((i - (n - 1) / 2.0) * gap, absf(i - (n - 1) / 2.0) * T * 0.06)
		_glow(self, gp, T * (0.2 + glow * 0.3), Color(1, 0.38, 0.5, 0.65 - glow * 0.5))
		_gem(self, gp, T * 0.12)
	if n > 1:
		var lbl := "%d" % n
		var at := c + Vector2(n * gap * 0.5 + 2.0, -T * 0.06)
		if n > 9 or not SpriteCache.put(self, "n|%d" % n, at):
			draw_string_outline(font, at, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, OUTLINE)
			draw_string(font, at, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ff9aae"))


func _draw_selection() -> void:
	if selected.x < 0:
		return
	var r := Rect2(Vector2(selected) * T, Vector2(T, T))
	draw_rect(r.grow(-1), Color.WHITE, false, 2.0)
	var rg := sim.preview_range(selected)
	if rg > 0.0:
		var c := sim.preview_center(selected) * T
		draw_circle(c, rg * T, Color(1, 1, 1, 0.08))
		draw_arc(c, rg * T, 0, TAU, 64, Color(1, 1, 1, 0.45), 1.5, true)


# ---------------------------------------------------------------- towers

func _draw_tower(tw: GameSim.Tower, tm: float) -> void:
	var x := tw.pos.x * T
	var y := tw.pos.y * T - (HIGH_LIFT * T if level.high.has(tw.cell) else 0.0)
	var s := T
	var e := SpriteCache.find(_tower_key(tw, tm))
	if e.is_empty():
		_want_tower(tw.type, tw.lvl, tw.mastery)
		_draw_tower_shapes(tw, x, y, s, tm)
		return
	# One picture, squashed about the tower's foot for a moment after it is built or upgraded.
	var sq := _squash(tw)
	var foot := Vector2(x, y + s * 0.3)
	var b: Rect2 = e[2]
	draw_texture_rect_region(e[0], Rect2(foot + (Vector2(x, y) + b.position - foot) * sq, b.size * sq), e[1])
	if tw.type == "ash":   # the runes pulse live, at the shrine's own pace
		var rl := Art.rune_lines(x, y, s, tw.lvl)
		var col := Art.rune_color(tm, tw.pos)
		for i in range(0, rl.size(), 2):
			_seg(self, foot + (rl[i] - foot) * sq, foot + (rl[i + 1] - foot) * sq, col, 2.0)
	if tw.mastery == "sunlance":   # a sun disc bobbing above the flame
		var c := foot + (Vector2(x, y - s * (0.95 + 0.03 * sin(tm * 3.0))) - foot) * sq
		_glow(self, c, s * 0.2, Color(1, 0.9, 0.5, 0.7))
		_circle(self, c, s * 0.08, Color("fff2c0"))
	if tw.has_ability():   # the halo once the ability is learned, in the tower's own colour
		var h := SpriteCache.find("halo")
		var col := halo_color(tw.type, 0.6 + 0.3 * sin(tm * 3.0))
		if h.is_empty():
			Paint.ellipse_outline(self, foot, s * 0.46 * sq.x, s * 0.17 * sq.y, col, 2.0)
		else:
			var hb: Rect2 = h[2]
			draw_texture_rect_region(h[0], Rect2(foot + hb.position * sq, hb.size * sq), h[1], col)
	_draw_level_badge(Vector2(x + s * 0.3, y + s * 0.3), tw.lvl)


## The tower shape by shape, for frames before its picture is baked (and headless runs).
func _draw_tower_shapes(tw: GameSim.Tower, x: float, y: float, s: float, tm: float) -> void:
	var sq := _squash(tw)
	if sq != Vector2.ONE:   # squash about the foot of the tower
		var foot := Vector2(x, y + s * 0.3)
		draw_set_transform_matrix(Transform2D(0.0, sq, 0.0, foot) * Transform2D(0.0, -foot))
	_paint_tower(self, x, y, s, tw.type, tw.lvl, tw.mastery, tw.charges, tw.flash > 0.0, tm, tw.pos.x, tw.pos)
	if tw.mastery == "sunlance":
		var c := Vector2(x, y - s * (0.95 + 0.03 * sin(tm * 3.0)))
		Paint.glow(self, c, s * 0.2, Color(1, 0.9, 0.5, 0.7))
		draw_circle(c, s * 0.08, Color("fff2c0"))
	# the halo once the ability is learned, in the tower's own colour; the pips below show only the upgrade level
	if tw.has_ability():
		Paint.ellipse_outline(self, Vector2(x, y + s * 0.3), s * 0.46, s * 0.17, halo_color(tw.type, 0.6 + 0.3 * sin(tm * 3.0)), 2.0)
	if sq != Vector2.ONE:
		draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_level_badge(Vector2(x + s * 0.3, y + s * 0.3), tw.lvl)


## A tower's platform, building and mastery decoration (everything but the sunlance's sun disc,
## the ability halo and the badge), on any canvas.
func _paint_tower(ci: CanvasItem, x: float, y: float, s: float, type: String, lv: int, mastery: String, charges: int, flash: bool, tm: float, seed_x: float, p: Vector2, runes := true) -> void:
	# stone platform
	Paint.ellipse(ci, Vector2(x + s * 0.05, y + s * 0.34), s * 0.42, s * 0.14, Color(0, 0, 0, 0.33))
	Paint.vgrad_poly(ci, Paint.ellipse_pts(Vector2(x, y + s * 0.3), s * 0.4, s * 0.13), Color("8d8478"), Color("4a443c"))
	Paint.ellipse(ci, Vector2(x, y + s * 0.27), s * 0.36, s * 0.1, Color("a69c8e"))
	if lv >= 2:
		Paint.ellipse_outline(ci, Vector2(x, y + s * 0.3), s * 0.4, s * 0.13, Color("e8b84a"), 2.0)
	match type:
		"moss":
			Art.hut(ci, x, y, s, lv, flash, tm, seed_x)
		"frost":
			Art.crypt(ci, x, y, s, lv, flash, tm)
		_:
			Art.shrine(ci, x, y, s, lv, flash, tm, p, runes)
	if mastery != "":
		_paint_mastery(ci, mastery, charges, x, y, s)


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
	if not SpriteCache.put(self, "b|%d" % clampi(lv, 1, 4), c):
		_paint_badge(self, c, lv)


func _paint_badge(ci: CanvasItem, c: Vector2, lv: int) -> void:
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
	ci.draw_style_box(_plates[1 if lv >= 3 else 0], r)
	if lv >= 4:
		ci.draw_rect(r.grow(2.0), Color("ffd86a"), false, 1.5)
	ci.draw_string(font, Vector2(r.position.x + 7.0, c.y + 9.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffd86a"))


# ---------------------------------------------------------------- heroes

## The heroes' baked pictures (HeroSprites), drawn behind the board. Their ground marks are on
## _marks, just under them.
func _draw_layer() -> void:
	if sim == null or not HeroSprites.ready():
		return
	for e: GameSim.Enemy in _es:
		if e.hidden or not HeroSprites.has(e.code):
			continue
		var u: float = e.d["r"] * T * HERO_SCALE
		var hitk := clampf(e.hit / 0.12, 0.0, 1.0)
		var x := (e.pos.x + e.knock.x * hitk) * T
		var yb := (e.pos.y + e.knock.y * hitk) * T
		if sim.flying(e):   # in the air: the shadow stays on the ground
			yb -= Defs.FLY_LIFT * T
		var fr := HeroSprites.frame(e.code, HeroSprites.frame_of(e.stride * 10.0 + e.bob))
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


## Shadows and ground rings of the heroes drawn from HeroSprites, all before any of them.
func _draw_marks() -> void:
	if sim == null or not HeroSprites.ready():
		return
	for e: GameSim.Enemy in _es:
		if e.hidden or not HeroSprites.has(e.code):
			continue
		var u: float = e.d["r"] * T * HERO_SCALE
		var hitk := clampf(e.hit / 0.12, 0.0, 1.0)
		_ground_marks(_marks, e, (e.pos.x + e.knock.x * hitk) * T, (e.pos.y + e.knock.y * hitk) * T, u)


## What a hero casts on the ground under him: his shadow, a Herald's ring, a rain cloud's reach and
## an Inquisitor's censer smoke. (The two outlines are a pixel wider than they once were drawn:
## on the old premultiplied hero layer their soft edges added light, which made them read brighter.)
func _ground_marks(ci: CanvasItem, e: GameSim.Enemy, x: float, yb: float, u: float) -> void:
	var g := Vector2(x, yb + u * 0.95)
	if e.d.has("rain"):   # the reach of its rain cloud
		_ellipse(ci, g, float(e.d["rain"]) * T, float(e.d["rain"]) * T * 0.4, Color(0.55, 0.7, 0.9, 0.12))
	if e.d.has("censer"):   # censer smoke: towers inside are silenced
		var r := float(e.d["censer"]) * T
		_ellipse(ci, g, r, r * 0.45, Color(0.7, 0.62, 0.85, 0.13))
		_eoutline(ci, g, r, r * 0.45, Color(0.8, 0.72, 0.95, 0.35), 2.5)
	_ellipse(ci, g, u * 0.75, u * 0.22, Color(0, 0, 0, 0.33))
	if e.d.has("haste"):  # the Herald's rallying ring on the ground
		_eoutline(ci, g, Defs.HASTE_RANGE * T * 0.5, Defs.HASTE_RANGE * T * 0.16, Color(1, 0.8, 0.3, 0.35), 3.0)


func _draw_enemy(e: GameSim.Enemy, tm: float) -> void:
	var u: float = e.d["r"] * T * HERO_SCALE
	var f := float(e.face)
	var cyc: float = e.stride * 10.0 + e.bob
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
			var rs := roundf(rr * 8.0) / 8.0
			_eoutline(self, Vector2(x, yb + u * 0.6), u * (0.4 + rr), u * (0.15 + rr * 0.35), Color(0.8, 0.9, 1, 0.5 * (1.0 - rr)), 1.5, u * (0.4 + rs), u * (0.15 + rs * 0.35))
		draw_line(Vector2(x + u * 0.2, yb + u * 0.6), Vector2(x + u * 0.3, yb - u * 0.5), Color("6e7c3e"), 2.0, true)
		_draw_gems(Vector2(e.pos.x, e.pos.y - 0.3) * T, e.carry, 0.0)
		return
	if not baked:
		_ground_marks(self, e, x, ground_y, u)
	if e.d.has("rage") and e.hp < e.max_hp * 0.5:  # raging
		_glow(self, Vector2(x, y - u * 0.3), u * 1.6, Color(1, 0.2, 0.1, 0.5))
	if not baked:
		var body: PackedVector2Array
		var arm := 0.0
		if code == "u":   # the throwing arm: cocked while it waits, swinging through as it looses
			if e.deployed:
				var since: float = Defs.TREBUCHET["every"] - e.sling
				arm = clampf(since / 0.35, 0.0, 1.0) if e.stones > 0 and since < 1.2 else 0.0
		var eng := _engine_key(e, tm, arm)
		var pic := SpriteCache.find(eng) if eng != "" else []
		if not pic.is_empty():   # a siege engine's baked picture (mirrored when it faces left)
			if f < 0:
				draw_set_transform(Vector2(2.0 * x, 0.0), 0.0, Vector2(-1, 1))
			var b: Rect2 = pic[2]
			var dst := Rect2(Vector2(x, yb) + b.position, b.size)
			draw_texture_rect_region(pic[0], dst, pic[1], Color(0.6, 0.6, 0.68) if e.covered else Color.WHITE)
			if hitk > 0.0:   # hit flash: the same picture again, pushed to white
				var a := 0.6 * hitk
				draw_texture_rect_region(pic[0], dst, pic[1], Color(8.0, 8.0, 8.0, a))
			if f < 0:
				draw_set_transform(Vector2.ZERO)
			hitk = 0.0
			body = PackedVector2Array()
		elif code == "u":
			_want_engines(code)
			body = Art.trebuchet(self, x, yb, u, f, tm if not e.deployed else 0.0, arm)
		else:
			_want_engines(code)
			body = Art.hero(self, code, x, y, yb, u, f, walk, tm)
		if hitk > 0.0:   # hit flash: the body (and head) blink white
			draw_colored_polygon(body, Color(1, 1, 1, 0.6 * hitk))
			if not code in ["u", "I", "l"]:
				draw_circle(Vector2(x, y - u * 0.68), u * 0.38, Color(1, 1, 1, 0.6 * hitk))
		if e.covered and not body.is_empty():
			draw_colored_polygon(body, Color(0.05, 0.05, 0.1, 0.4))
	if e.covered:   # in the Belfry's shadow: a small shield says towers can't see him
		draw_arc(Vector2(x, y - u * 0.2), u * 1.0, PI * 1.1, PI * 1.9, 10, Color(0.75, 0.75, 0.85, 0.7), 2.0, true)
	if e.d.has("sapper") and e.fuse >= 0.0:   # the fuse burns
		var sp := Vector2(x - f * u * 0.42, y - u * 0.5 - e.fuse * u * 0.3)
		_glow(self, sp, u * (0.6 + 0.2 * sin(tm * 30.0)), Color(1, 0.7, 0.2, 0.9))
		_circle(self, sp, u * 0.12, Color("fff2c0"))
	if e.soak > 0.0 and not sim.in_water(e):   # soaked: drips fall from him for a few seconds
		for k in 3:
			var q := fmod(tm * 1.6 + k / 3.0 + e.bob, 1.0)
			_circle(self, Vector2(x + (k - 1) * u * 0.45, y - u * 0.2 + q * u * 1.1), maxf(1.5, u * 0.09), Color(0.6, 0.85, 1, 0.85 * (1.0 - q)))
	if e.work > 0.0:   # an Engineer rebuilding a bridge: a ring filling up over him
		var c := Vector2(x, y - u * 2.2)
		_circle(self, c, u * 0.55, Color(0, 0, 0, 0.55))
		draw_arc(c, u * 0.55, -PI / 2, -PI / 2 + TAU * clampf(e.work / Defs.ENGINEER_FIX, 0.0, 1.0), 20, Color("ff9a7a"), 3.0, true)
	if e.mark > 0.0:   # marked by a Hunter's Lodge
		_ring(self, Vector2(x, y - u * 0.2), u * 1.1, 2.0, Color(1, 0.3, 0.25, 0.8))
	if e.slow > 0.0:
		_ellipse(self, Vector2(x, y - u * 0.1), u * 0.75, u * 1.1, Color(0.62, 0.88, 1, 0.25))
		for i in 3:
			var a := sim.time * 2.0 + i * 2.1
			_rect(self, Rect2(x + cos(a) * u * 0.6, y - u * 0.2 + sin(a) * u * 0.7, 2, 2), Color("e6f8ff"))
	if e.fear > 0.0:
		var fy := y - u * 1.75 + sin(sim.time * 14.0) * 1.5
		if not SpriteCache.put(self, "fear", Vector2(x - 10, fy)):
			draw_string_outline(font, Vector2(x - 10, fy), "!!", HORIZONTAL_ALIGNMENT_CENTER, 20, 18, 4, OUTLINE)
			draw_string(font, Vector2(x - 10, fy), "!!", HORIZONTAL_ALIGNMENT_CENTER, 20, 18, Color("c9c0ff"))
	_draw_gems(Vector2(e.pos.x, e.pos.y - e.d["r"] * 2.3 * HERO_SCALE - 0.08) * T - Vector2(0, lift), e.carry, 0.0)
	if e.untouch > 0.0:   # a holy shield, or the Seraph landing: untouchable
		_glow(self, Vector2(x, y - u * 0.4), u * 2.2, Color(1, 0.95, 0.7, 0.5))
		_ring(self, Vector2(x, y - u * 0.4), u * 1.3, 2.5, Color(1, 0.92, 0.6, 0.85))
	if e.chant > 0.0:   # a Spiriter chanting: a ring closing in as the chant runs out
		var ck := e.chant / Defs.CHANT_TIME
		_ring(self, Vector2(x, yb + u * 0.9), u * (1.0 + 1.5 * ck), 2.5, Color(0.6, 0.85, 1, 0.8))
	if e.hp < e.max_hp:
		var w := maxf(16.0, u * 2.6)
		var hy := y - u * float(BAR_Y.get(code, 1.65)) - 6.0
		_rect(self, Rect2(x - w / 2 - 1, hy - 1, w + 2, 6), Color(0, 0, 0, 0.7))
		_rect(self, Rect2(x - w / 2, hy, w * e.hp / e.max_hp, 4), Color("6fd36f") if e.hp / e.max_hp > 0.4 else Color("e0503a"))


## Siege engines are not in HeroSprites (their looks follow what they do), so the board bakes
## them here: a rolling Trebuchet's wheels (8 frames), a slinging one's arm (8 positions, wheels
## still), the Belfry's swinging bell (8 frames). "" for any other hero.
const ENGINE_FRAMES := 8


func _engine_key(e: GameSim.Enemy, tm: float, arm: float) -> String:
	if e.code == "u":
		if e.deployed:
			return "eng|u|a%d" % mini(ENGINE_FRAMES, floori(arm * ENGINE_FRAMES))
		return "eng|u|w%d" % (int(fposmod(tm * 2.0, PI) / PI * ENGINE_FRAMES) % ENGINE_FRAMES)
	if e.code == "I":
		return "eng|I|%d" % (int(fposmod(tm * 2.0, TAU) / TAU * ENGINE_FRAMES) % ENGINE_FRAMES)
	return ""


func _want_engines(code: String) -> void:
	if (code != "u" and code != "I") or _wanted.has("eng|" + code) or not SpriteCache.enabled():
		return
	_wanted["eng|" + code] = true
	var u := float(Defs.ENEMIES[code]["r"]) * T * HERO_SCALE
	if code == "u":
		var box := Rect2(-2.4 * u, -4.0 * u, 4.8 * u, 4.9 * u)
		for i in ENGINE_FRAMES:
			var tw := (i + 0.5) / ENGINE_FRAMES * PI / 2.0
			SpriteCache.want("eng|u|w%d" % i, box, func(ci: CanvasItem, at: Vector2) -> void: Art.trebuchet(ci, at.x, at.y, u, 1.0, tw, 0.0))
		for i in ENGINE_FRAMES + 1:
			var arm := float(i) / ENGINE_FRAMES
			SpriteCache.want("eng|u|a%d" % i, box, func(ci: CanvasItem, at: Vector2) -> void: Art.trebuchet(ci, at.x, at.y, u, 1.0, 0.0, arm))
	else:
		for i in ENGINE_FRAMES:
			var tb := (i + 0.5) / ENGINE_FRAMES * PI
			SpriteCache.want("eng|I|%d" % i, Rect2(-1.2 * u, -4.4 * u, 2.4 * u, 5.3 * u), func(ci: CanvasItem, at: Vector2) -> void: Art.belfry(ci, at.x, at.y, u, 1.0, tb))


## A straight band from a to b, w wide (a draw_line without antialiasing): the atlas's white
## square, turned and stretched, so it batches.
func _seg(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var d := b - a
	if _a_white.is_empty() or d.length() < 0.01:
		ci.draw_line(a, b, col, w)
		return
	var src: Rect2 = _a_white[1]
	ci.draw_set_transform(a, d.angle())
	ci.draw_texture_rect_region(_a_white[0], Rect2(0, -w / 2.0, d.length(), w), Rect2(src.get_center() - Vector2(1, 1), Vector2(2, 2)), col)
	ci.draw_set_transform(Vector2.ZERO)


# ---------------------------------------------------------------- shots & effects

func _draw_shot(s: GameSim.Shot) -> void:
	var p := s.pos * T
	var dirv := (s.tpos - s.pos).normalized()
	if dirv == Vector2.ZERO:
		dirv = Vector2.RIGHT
	_draw_trail(s, p, dirv)
	var kind := s.kind if s.kind in ["arrow", "frost", "den"] else "fire"
	var e := SpriteCache.find("sh|" + kind)
	if e.is_empty():
		_paint_shot(self, p, dirv, kind)
	else:
		_put_along(self, e, p, dirv, Vector2.ONE, Color.WHITE)
	if kind == "den":
		_draw_orb(p, T * 0.1, sim.time, 7)


## A shot in flight with its little smoke or frost trail, pointing along dirv, on any canvas.
func _paint_shot(ci: CanvasItem, p: Vector2, dirv: Vector2, kind: String) -> void:
	var n := dirv.orthogonal()
	match kind:
		"arrow":
			var tail := p - dirv * T * 0.24
			ci.draw_line(tail, p, Color("5a3a1e"), maxf(2.0, T * 0.035))
			ci.draw_colored_polygon(PackedVector2Array([p + dirv * T * 0.06, p + n * T * 0.035, p - n * T * 0.035]), Color("d8dde2"))
			ci.draw_line(tail, tail + dirv * T * 0.06 + n * T * 0.04, Color("f2f2f2"), 1.5)
			ci.draw_line(tail, tail + dirv * T * 0.06 - n * T * 0.04, Color("f2f2f2"), 1.5)
		"frost":
			for i in range(3, 0, -1):
				ci.draw_circle(p - dirv * T * 0.08 * i, T * 0.06, Color(0.75, 0.92, 1, 0.15 * (4 - i)))
			Paint.glow(ci, p, T * 0.18, Color(0.66, 0.9, 1, 0.75))
			ci.draw_circle(p, T * 0.055, Color.WHITE)
		"den":   # the trail only; the orb itself crackles live (_draw_orb)
			for i in range(4, 0, -1):
				ci.draw_circle(p - dirv * T * 0.07 * i, T * (0.03 + 0.01 * i), Color(0.6, 0.7, 1, 0.12 * (5 - i)))
		_:
			for i in range(4, 0, -1):
				ci.draw_circle(p - dirv * T * 0.1 * i, T * (0.05 + 0.02 * i), Color(0.35, 0.24, 0.2, 0.12 * (5 - i)))
			Paint.glow(ci, p, T * 0.3, Color(1, 0.48, 0.16, 0.8))
			ci.draw_circle(p, T * 0.11, Color("ff6a20"))
			ci.draw_circle(p, T * 0.055, Color("ffe08a"))


## A fading streak behind a shot, back toward where it was fired from.
func _draw_trail(s: GameSim.Shot, p: Vector2, dirv: Vector2) -> void:
	var from := (s.src.pos + Vector2(0, -0.25)) if s.src != null else level.lair_center + Vector2(0, -0.5)
	var back := minf(T * 0.7, p.distance_to(from * T))
	if back < 2.0:
		return
	var col: Color = TRAIL.get(s.kind, Color(1, 0.55, 0.2))
	var w: float = 2.0 if s.kind == "arrow" else T * 0.07
	var e := SpriteCache.find("trail")
	if e.is_empty():
		draw_polyline_colors(PackedVector2Array([p - dirv * back, p]), PackedColorArray([Color(col, 0.0), Color(col, col.a)]), w, true)
	else:
		_put_along(self, e, p, dirv, Vector2(back / 64.0, w / 4.0), col)


const TRAIL := {"arrow": Color(1, 1, 1, 0.35), "frost": Color(0.7, 0.92, 1, 0.45), "den": Color(0.55, 0.65, 1, 0.5)}


## A straight soft line from a to b (an antialiased draw_line) from the baked "beam" or "dash".
func _line(ci: CanvasItem, key: String, base_w: float, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var e := SpriteCache.find(key)
	var d := b - a
	if e.is_empty() or d.length() < 0.5:
		ci.draw_line(a, b, col, w, true)
		return
	_put_along(ci, e, a, d, Vector2(d.length() / 64.0, w / base_w), col)


## Cinder Shrine beam: from the brazier to the hero, orange when cool, white-hot at full heat.
func _draw_beam(tw: GameSim.Tower, tm: float, target: GameSim.Enemy, h: float) -> void:
	var lift := HIGH_LIFT if level.high.has(tw.cell) else 0.0
	var a := (tw.pos + Vector2(0, 0.2 - (0.5 + tw.lvl * 0.07) - 0.1 - lift)) * T   # the flame atop the shrine
	var b := target.pos * T + Vector2(0, -T * 0.15)
	if tw.mastery == "sunlance":   # burns on through to the edge of its reach
		b = (tw.pos + (target.pos - tw.pos).normalized() * tw.stat("range")) * T
	var flick := 0.85 + 0.15 * sin(tm * 40.0 + tw.pos.x * 7.0)
	var outer := Color(1, 0.35 + 0.25 * h, 0.08, 0.35 * flick)
	var core := Color(1, 0.7 + 0.3 * h, 0.35 + 0.6 * h, 0.95)
	_line(self, "beam", 8.0, a, b, outer, T * (0.1 + 0.08 * h))
	_line(self, "beam", 8.0, a, b, core, T * (0.03 + 0.03 * h) * flick)
	_glow(self, b, T * (0.22 + 0.15 * h), Color(1, 0.5 + 0.3 * h, 0.15, 0.7))
	_glow(self, a, T * 0.18, Color(1, 0.6, 0.2, 0.6))


func _draw_fx(f: GameSim.Fx) -> void:
	var k := f.t / f.dur
	var p := f.pos * T
	match f.kind:
		"boom":
			var rr := f.r * T * (0.4 + 0.6 * k)
			_glow(self, p, rr * 1.15, Color(1, 0.47, 0.16, (1 - k) * 0.9))
			_circle(self, p, rr * 0.45, Color(1, 0.94, 0.67, (1 - k) * 0.8))
		"meteor":
			if not f.hit:
				var q := f.t / Defs.METEOR["delay"]
				draw_arc(p, Defs.METEOR["radius"] * T, 0, TAU, 48, Color(1, 0.69, 0.25, 0.55), 2.0, true)
				var m := Vector2((f.pos.x + 2.0 * (1 - q)) * T, (f.pos.y - 4.0 * (1 - q)) * T)
				_glow(self, m, T * 0.6, Color(1, 0.42, 0.13, 0.7))
				_circle(self, m, T * 0.28, Color("ff6a20"))
				_circle(self, m, T * 0.14, Color("ffe08a"))
		"surge", "splash", "flood":   # rings for the Tidecaller's surge, a falling bridge and a sluice
			var e := 1.0 - pow(1.0 - k, 2.0)
			var col: Color = FX_RING[f.kind]
			_ellipse(self, p, f.r * T * e, f.r * T * e * 0.55, Color(col, 0.22 * (1.0 - k)))
			Paint.ellipse_outline(self, p, f.r * T * e, f.r * T * e * 0.55, Color(col, 0.8 * (1.0 - k)), 3.0)
		"shock":   # a ring sweeping out from a meteor strike
			var e := 1.0 - pow(1.0 - k, 3.0)
			draw_arc(p, f.r * T * (0.2 + 0.8 * e), 0, TAU, 48, Color(1, 0.85, 0.55, 0.8 * (1.0 - k)), T * 0.08 * (1.0 - k) + 1.0, true)
		"stone":   # a Trebuchet's stone arcing onto its tower
			if not f.hit:
				var q := f.pos.lerp(f.to, k) * T + Vector2(0, -sin(k * PI) * T * 1.6)
				_circle(self, q + Vector2(2, 3), T * 0.11, Color(0, 0, 0, 0.3))
				_circle(self, q, T * 0.11, Color("8a8478"))
				_ring(self, q, T * 0.11, 1.5, Color("3a3430"))
		"smoke":   # a burst of dust and smoke (a Sapper's blast, a stone landing)
			for i in 5:
				var a := i * TAU / 5.0 + f.pos.x
				var q := p + Vector2(cos(a), sin(a) * 0.5) * f.r * T * (0.3 + 0.7 * k) + Vector2(0, -k * T * 0.4)
				_circle(self, q, T * (0.12 + 0.18 * k), Color(0.45, 0.43, 0.4, 0.55 * (1.0 - k)))
		"text":   # pops in, rises easing out, fades over its last 40%
			var e := 1.0 - pow(1.0 - k, 3.0)
			var fs := int(28.0 * (1.0 + 0.35 * maxf(0.0, 1.0 - k * 8.0)))
			var pos := Vector2(p.x - 80, (f.pos.y - e * 0.6) * T)
			var col := f.color
			col.a = clampf((1.0 - k) / 0.4, 0.0, 1.0)
			draw_string_outline(font, pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, 160, fs, 4, Color(0, 0, 0, col.a * 0.7))
			draw_string(font, pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, 160, fs, col)


const FX_RING := {"surge": Color(0.6, 0.85, 1), "splash": Color(0.8, 0.92, 1), "flood": Color(0.5, 0.8, 1)}


# ---------------------------------------------------------------- lava, map buildings, loot

func _draw_pool(pl: GameSim.Pool, tm: float) -> void:
	var p := pl.pos * T
	var fade := clampf((pl.dur - pl.t) / 0.6, 0.0, 1.0)
	_ellipse(_fl, p, pl.r * T, pl.r * T * 0.55, Color(0.3, 0.06, 0.02, 0.6 * fade))
	_glow(_fl, p, pl.r * T * 1.1, Color(1, 0.35, 0.05, 0.55 * fade))
	for i in 5:
		var a := i * 1.26 + tm * 0.7
		var q := p + Vector2(cos(a) * pl.r * 0.55, sin(a) * pl.r * 0.3) * T
		_circle(_fl, q, T * (0.03 + 0.02 * sin(tm * 6.0 + i)), Color(1, 0.8, 0.3, 0.8 * fade))


func _draw_site(s: GameSim.Site, tm: float) -> void:
	var c := s.pos * T
	if not SpriteCache.put(self, _site_key(s, tm), c):
		_want_site(s, s.owned)
		Paint.ellipse(self, c + Vector2(0.03, 0.3) * T, T * 0.44, T * 0.14, Color(0, 0, 0, 0.35))
		Art.site(self, s.kind, c, s.owned, tm, s.cell)
	if s.kind == "sluice":   # ready: a soft glow; refilling: a ring filling up
		if s.t <= 0.0:
			_glow(self, c, T * (0.45 + 0.05 * sin(tm * 3.0)), Color(0.5, 0.8, 1, 0.35))
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
	_ellipse(self, l.pos * T + Vector2(0, T * 0.12), T * 0.13, T * 0.05, Color(0, 0, 0, 0.35))
	var kind := "coin" if l.kind == "coin" else "potion"
	if not SpriteCache.put(self, kind, p):
		_paint_loot(self, p, kind)


func _paint_loot(ci: CanvasItem, p: Vector2, kind: String) -> void:
	if kind == "coin":
		Paint.glow(ci, p, T * 0.32, Color(1, 0.8, 0.3, 0.55))
		ci.draw_circle(p, T * 0.11, Color("e8b84a"))
		ci.draw_arc(p, T * 0.11, 0, TAU, 20, Color("8a6420"), 1.5, true)
		ci.draw_circle(p, T * 0.05, Color("c9952e"))
	else:
		Paint.glow(ci, p, T * 0.32, Color(0.5, 0.42, 0.95, 0.6))
		ci.draw_circle(p + Vector2(0, T * 0.03), T * 0.1, Color("7e6cf0"))
		ci.draw_rect(Rect2(p + Vector2(-0.035, -0.15) * T, Vector2(0.07, 0.1) * T), Color("b8b0e8"))
		ci.draw_rect(Rect2(p + Vector2(-0.045, -0.18) * T, Vector2(0.09, 0.04) * T), Color("6a4422"))
		ci.draw_circle(p + Vector2(-0.03, 0.0) * T, T * 0.025, Color(1, 1, 1, 0.7))


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
	sparks.sort()   # by depth: the far side of the loop first
	for s: Array in sparks:
		var depth: float = 0.8 + 0.2 * s[0]   # 0.6 at the back of the loop, 1.0 at the front
		var i: int = s[1]
		var p: Vector2 = s[2]
		if i < sim.den_charges:
			_draw_orb(p, T * 0.11 * depth, tm, i)
		else:
			_circle(self, p, T * 0.05 * depth, Color(0, 0, 0, 0.55))
			if i == sim.den_charges:
				var k: float = sim.den_refill / sim.den_refill_time
				draw_arc(p, T * 0.075 * depth, -PI / 2, -PI / 2 + TAU * k, 16, Color("a0b4ff"), 2.0, true)


## Raised tiles shimmer: a slow golden glow on the rock top and a few twinkling glints, so they
## stand out as the tiles any tower can use. Light keeps the glow (it tells the tiles apart) and
## leaves out the glints.
func _draw_high_shine(c: Vector2i, tm: float) -> void:
	var top := (Vector2(c) + Vector2(0.5, 0.36)) * T
	var k := float(c.x * 7 + c.y * 13)
	var pulse := 0.5 + 0.5 * sin(tm * 2.0 + k)
	_glow(_fl, top, T * (0.42 + 0.06 * pulse), Color(1, 0.85, 0.45, 0.16 + 0.14 * pulse))
	if Quality.light():
		return
	var g := SpriteCache.find("glint")
	for i in 3:
		var t := fmod(tm * 0.7 + i / 3.0 + Paint.hash01(c.x, c.y, i), 1.0)
		var a := sin(t * PI)   # fades in and out over its cycle
		var p := top + Vector2(Paint.hash01(c.x, c.y, i + 10) - 0.5, (Paint.hash01(c.x, c.y, i + 20) - 0.5) * 0.6) * T * 0.6
		var col := Color(1, 0.95, 0.75, 0.9 * a)
		if not g.is_empty():
			var b: Rect2 = g[2]
			_fl.draw_texture_rect_region(g[0], Rect2(p + b.position * a, b.size * a), g[1], col)
			continue
		var s := T * 0.06 * a
		_fl.draw_line(p - Vector2(s, 0), p + Vector2(s, 0), col, 1.5, true)
		_fl.draw_line(p - Vector2(0, s), p + Vector2(0, s), col, 1.5, true)


## A ball of crackling energy that swells and shrinks: a den charge, or a bolt in flight.
func _draw_orb(p: Vector2, r: float, tm: float, id: int) -> void:
	var pulse := 0.7 + 0.45 * (0.5 + 0.5 * sin(tm * 7.0 + id * 1.9))
	var rr := r * pulse
	# The forks are re-rolled about 20 times a second: one of eight baked crackles each time.
	if not SpriteCache.put(self, "orb|%d" % ((int(tm * 20.0) + id * 5) % 8), p, Color.WHITE, Vector2.ONE * (rr / 10.0)):
		_paint_orb(self, p, rr, int(tm * 20.0), id)


func _paint_orb(ci: CanvasItem, p: Vector2, rr: float, tick: int, id: int) -> void:
	Paint.glow(ci, p, rr * 3.4, Color(0.35, 0.5, 1, 0.8))
	ci.draw_circle(p, rr * 1.15, Color(0.15, 0.25, 0.75, 0.55))
	ci.draw_circle(p, rr, Color(0.45, 0.62, 1))
	ci.draw_circle(p, rr * 0.55, Color(0.95, 0.97, 1))
	# Three short forks of lightning.
	for k in 3:
		var a := Paint.hash01(tick, id, k) * TAU
		var pts := PackedVector2Array([p])
		var q := p
		for j in 3:
			a += (Paint.hash01(tick, id, k * 7 + j) - 0.5) * 1.6
			q += Vector2(cos(a), sin(a)) * rr * (0.6 + Paint.hash01(tick, id, k * 11 + j) * 0.5)
			pts.append(q)
		ci.draw_polyline(pts, Color(0.85, 0.9, 1, 0.85), maxf(1.0, rr * 0.18), true)


## Burnt ground where a meteor struck, fading over its last seconds. Drawn under everything else.
func _draw_scorch(f: GameSim.Fx) -> void:
	var p := f.pos * T
	var a := clampf((f.dur - f.t) / 2.0, 0.0, 1.0) * clampf(f.t / 0.1, 0.0, 1.0)
	_ellipse(_fl, p, f.r * T, f.r * T * 0.6, Color(0.08, 0.05, 0.03, 0.55 * a))
	_ellipse(_fl, p, f.r * T * 0.6, f.r * T * 0.36, Color(0.04, 0.02, 0.01, 0.5 * a))
	var hot := clampf(1.0 - f.t / 2.5, 0.0, 1.0)   # embers glow at first, then go out
	for i in 7:
		var ang := Paint.hash01(int(f.pos.x * 10.0), int(f.pos.y * 10.0), i) * TAU
		var q := p + Vector2(cos(ang), sin(ang) * 0.6) * f.r * T * (0.3 + 0.6 * Paint.hash01(i, 3, int(f.pos.x)))
		_circle(_fl, q, T * 0.03, Color(1, 0.45 + 0.3 * hot, 0.1, 0.8 * hot * a) if hot > 0.0 else Color(0.1, 0.07, 0.05, 0.6 * a))


## What a level IV tower became, drawn over its level III look (the Sunlance's sun disc moves, so
## the board draws it live).
func _paint_mastery(ci: CanvasItem, mastery: String, charges: int, x: float, y: float, s: float) -> void:
	match mastery:
		"longhouse":   # a second banner and a longer roof
			ci.draw_line(Vector2(x - s * 0.34, y + s * 0.2), Vector2(x - s * 0.34, y - s * 0.62), Color("3a2414"), maxf(2.0, s * 0.035))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x - s * 0.34, y - s * 0.62), Vector2(x - s * 0.56, y - s * 0.55), Vector2(x - s * 0.34, y - s * 0.46)]), Color("c0283a"))
		"lodge":   # a rack of javelins and antlers over the door
			for d in [-0.14, 0.0, 0.14]:
				ci.draw_line(Vector2(x + s * (0.3 + d), y + s * 0.25), Vector2(x + s * (0.34 + d), y - s * 0.3), Color("dfe6ec"), 2.0)
			ci.draw_arc(Vector2(x, y - s * 0.02), s * 0.12, PI, TAU, 8, Color("f1e6cc"), 2.0)
		"ossuary":   # skulls on the roof, lit by bolts stored
			for k in 4:
				var p := Vector2(x + (k - 1.5) * s * 0.14, y - s * 0.2)
				ci.draw_circle(p, s * 0.05, Color("e9f1f4"))
				if k < charges:
					Paint.glow(ci, p, s * 0.09, Color(0.56, 0.88, 1, 0.8))
		"mausoleum":   # a dome
			ci.draw_arc(Vector2(x, y - s * 0.16), s * 0.22, PI, TAU, 14, Color("c3ccd2"), 4.0)
			ci.draw_circle(Vector2(x, y - s * 0.4), s * 0.04, Color("4fd0ff"))
		"twin":   # a second brazier
			Paint.glow(ci, Vector2(x + s * 0.26, y - s * 0.38), s * 0.2, Color(1, 0.48, 0.16, 0.55))
			ci.draw_circle(Vector2(x + s * 0.26, y - s * 0.38), s * 0.06, Color("ffd25a"))


## Where the next wave comes from, on lairs whose waves take different roads: its road starts glow.
var _routes_wave := -1
var _routes: Array = []


func _draw_routes(tm: float) -> void:
	if sim.wave >= level.waves.size() or level.wave_roads[sim.wave].is_empty():
		return
	if _routes_wave != sim.wave:   # worked out once a wave
		_routes_wave = sim.wave
		_routes = level.wave_roads[sim.wave].duplicate()
		for r: int in level.wave_rivers[sim.wave]:
			if not _routes.has(r) and level.waves[sim.wave].any(func(c: String) -> bool: return Defs.ENEMIES[c].has("boat")):
				_routes.append(r)
	var pulse := 0.5 + 0.5 * sin(tm * 4.0)
	for r: int in _routes:
		var p := level.path_pos(r, 1.0) * T
		_glow(_fl, p, T * (0.6 + 0.15 * pulse), Color(1, 0.75, 0.3, 0.35 + 0.25 * pulse))
		_ring(_fl, p, T * 0.4, 3.0, Color(1, 0.85, 0.45, 0.8))


## How a hindered tower looks: buried under a heap of stones, stunned in smoke with circling sparks,
## or silenced (pale motes drift down over it, and its ability ring is off).
func _draw_status(tw: GameSim.Tower, tm: float) -> void:
	if tw.rubble <= 0.0 and tw.stun <= 0.0 and tw.silence <= 0.0:
		return
	var x := tw.pos.x * T
	var y := tw.pos.y * T - (HIGH_LIFT * T if level.high.has(tw.cell) else 0.0)
	if tw.rubble > 0.0:
		for i in 9:
			var p := Vector2(x + (Paint.hash01(tw.cell.x, tw.cell.y, i) - 0.5) * T * 0.7, y + T * (0.28 - 0.5 * Paint.hash01(tw.cell.y, tw.cell.x, i) * (1.0 - absf(Paint.hash01(tw.cell.x, tw.cell.y, i) - 0.5))))
			_circle(self, p, T * (0.08 + 0.04 * Paint.hash01(i, tw.cell.x, 3)), Color("6e665c").lerp(Color("4a443c"), Paint.hash01(i, 2, tw.cell.y)))
			if not SpriteCache.put(self, "harc", p, Color(0.1, 0.08, 0.06, 0.6), Vector2.ONE * (T * 0.09 / R)):
				draw_arc(p, T * 0.09, PI, TAU, 6, Color(0.1, 0.08, 0.06, 0.6), 1.0)
		for k in 2:   # dust
			var q := fmod(tm * 0.5 + k * 0.5, 1.0)
			_circle(self, Vector2(x + (k - 0.5) * T * 0.4, y - q * T * 0.5), T * (0.1 + 0.1 * q), Color(0.6, 0.55, 0.48, 0.3 * (1.0 - q)))
	if tw.stun > 0.0:
		for k in 3:
			var q := fmod(tm * 0.6 + k / 3.0, 1.0)
			_circle(self, Vector2(x + sin(tm * 2.0 + k) * T * 0.15, y - T * (0.4 + q * 0.6)), T * (0.1 + 0.12 * q), Color(0.35, 0.35, 0.38, 0.5 * (1.0 - q)))
		for k in 3:   # sparks circling the top
			var a := tm * 4.0 + k * TAU / 3.0
			var p := Vector2(x + cos(a) * T * 0.3, y - T * 0.75 + sin(a) * T * 0.08)
			_seg(self, p - Vector2(3, 0), p + Vector2(3, 0), Color("ffe08a"), 1.5)
			_seg(self, p - Vector2(0, 3), p + Vector2(0, 3), Color("ffe08a"), 1.5)
	if tw.silence > 0.0:
		for k in 5:
			var q := fmod(tm * 0.35 + k / 5.0, 1.0)
			var p := Vector2(x + (Paint.hash01(k, tw.cell.x, 7) - 0.5) * T * 0.7, y - T * (0.9 - q * 1.1))
			_circle(self, p, T * 0.035, Color(0.9, 0.86, 1.0, 0.75 * sin(q * PI)))


## Road paved by Paviors: cobbles along the stretch, fading out over its last seconds.
func _draw_paving() -> void:
	var cob := SpriteCache.find("cob")
	for i in sim.paved.size():
		for p: Dictionary in sim.paved[i]:
			var a := clampf((float(p["until"]) - sim.time) / 4.0, 0.0, 1.0)
			var d := float(p["from"])
			var n := 0
			# A grey stone strip down the road first, so the stretch reads as paving, not loose lines.
			if float(p["to"]) - d > 0.05:
				var strip := PackedVector2Array()
				var s := d
				while s < float(p["to"]):
					strip.append(level.path_pos(i, s) * T)
					s += 0.25
				strip.append(level.path_pos(i, float(p["to"])) * T)
				_fl.draw_polyline(strip, Color(0.33, 0.31, 0.29, 0.55 * a), T * 0.62)
				_fl.draw_polyline(strip, Color(0.58, 0.55, 0.5, 0.5 * a), T * 0.5)
			while d < float(p["to"]):
				var q := level.path_pos(i, d) * T
				var side := (Paint.hash01(i, n, 5) - 0.5) * T * 0.4
				if cob.is_empty():
					var r := Rect2(q + Vector2(side - T * 0.07, -T * 0.05), Vector2(T * 0.14, T * 0.1))
					_fl.draw_rect(r, Color(0.62, 0.58, 0.52, 0.75 * a))
					_fl.draw_rect(r, Color(0.25, 0.22, 0.2, 0.6 * a), false, 1.0)
				else:
					var b: Rect2 = cob[2]
					_fl.draw_texture_rect_region(cob[0], Rect2(q + Vector2(side, 0) + b.position, b.size), cob[1], Color(1, 1, 1, a))
				d += 0.12
				n += 1


## What the water is doing right now: fords drowned by the high tide (deep blue, with ripples), and
## planks an Engineer has laid over a ford (they fade as they rot).
func _draw_water_state(tm: float) -> void:
	var k := 0.0   # 0 low tide .. 1 high tide, rising and falling over a second
	if sim.tide.x > 0.0:
		var t := fmod(sim.time, sim.tide.x)
		var rise: float = sim.tide.x - sim.tide.y
		k = clampf(t - rise, 0.0, 1.0) if t >= rise else clampf(1.0 - t, 0.0, 1.0) if sim.time >= sim.tide.x else 0.0
	if k > 0.0 and _flood != null:   # the fords go under: deep water spreading softly over them
		_fl.draw_texture_rect_region(_flood, Rect2(0, 0, level.cols * T, level.rows * T),
			Rect2(FLOOD_PX, FLOOD_PX, level.cols * FLOOD_PX, level.rows * FLOOD_PX), Color(FLOOD_TINT, 0.88 * k))
	if k > 0.0:
		for i in level.crossing_cells.size():
			if level.crossing_kind[i] != "ford":
				continue
			for c: Vector2i in level.crossing_cells[i]:
				var r := Rect2(Vector2(c) * T, Vector2(T, T))
				for j in (1 if Quality.light() else 2):
					var q := fmod(tm * 0.5 + j * 0.5 + Paint.hash01(c.x, c.y, j), 1.0)
					var qs := roundf(q * 8.0) / 8.0
					_eoutline(_fl, r.get_center() + Vector2((Paint.hash01(c.x, c.y, j + 4) - 0.5) * T * 0.5, (j - 0.5) * T * 0.3),
						T * (0.12 + 0.25 * q), T * (0.05 + 0.1 * q), Color(0.75, 0.9, 1, 0.5 * k * (1.0 - q)), 1.5, T * (0.12 + 0.25 * qs), T * (0.05 + 0.1 * qs))
	if sim.planks.is_empty():
		return
	for p in level.paths.size():
		for z: Dictionary in level.zones[p]:
			if z["kind"] != "ford":
				continue
			var d: float = z["from"]
			while d < float(z["to"]):
				var at := level.path_pos(p, d)
				var idx: int = level.crossings.get(Vector2i(floori(at.x), floori(at.y)), -1)
				var left: float = float(sim.planks.get(idx, -1.0)) - sim.time
				if idx >= 0 and left > 0.0:
					var dir := (level.path_pos(p, d + 0.05) - at).normalized()
					var n := dir.orthogonal()
					var a := clampf(left / 4.0, 0.0, 1.0)
					_seg(_fl, (at - n * 0.3) * T, (at + n * 0.3) * T, Color(Color("8a6238") if int(d * 8.0) % 2 else Color("9c7244"), a), T * 0.1)
				d += 0.125


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
			_line(_fl, "dash", 2.0, a, b, Color(0.9, 0.92, 1, 0.32), 2.0)
			d += 0.5
	if sim.hallow_on():
		var hal := SpriteCache.find("hal")
		for c: Vector2i in level.hallowed:
			var r := Rect2(Vector2(c) * T, Vector2(T, T)).grow(-3.0)
			var pulse := 0.5 + 0.5 * sin(tm * 1.5 + c.x + c.y)
			_rect(_fl, r, Color(1, 0.92, 0.6, 0.12 + 0.08 * pulse))
			if hal.is_empty():
				_fl.draw_rect(r, Color(1, 0.9, 0.55, 0.45), false, 1.5)
			else:
				var b: Rect2 = hal[2]
				_fl.draw_texture_rect_region(hal[0], Rect2(Vector2(c) * T + b.position, b.size), hal[1])
