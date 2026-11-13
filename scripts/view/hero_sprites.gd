class_name HeroSprites
extends RefCounted
## Every hero's walk cycle, drawn once at start-up into one texture (an atlas) so the board can draw
## each hero as a single picture instead of dozens of shapes a frame. The pictures are the same
## Art.hero figures, baked facing right at SCALE times board size; the board mirrors them for heroes
## walking left. Until the atlas is ready (and in headless runs, which render nothing) the board
## draws heroes shape by shape as before.
##
## The atlas comes out of a SubViewport with premultiplied alpha, so it must be drawn on a canvas
## item whose material blends PREMULT_ALPHA (see Board).

const FRAMES := 8            # walk cycle frames
const SCALE := 1.5           # baked this many times board size, so it stays sharp on big screens
const T := 64.0
## Drawn shape by shape always: few on the map, and their looks change with what they are doing.
const SKIP := ["u", "I"]

static var atlas: Texture2D
static var _cells := {}      # code -> [Rect2 of frame 0 in the atlas, Vector2 anchor in that cell, u]
static var _busy := false


static func ready() -> bool:
	return atlas != null


static func has(code: String) -> bool:
	return atlas != null and _cells.has(code)


## The atlas rectangle of frame k of code, the point in it where the hero's feet line (x, yb) sits,
## and the body unit it was baked at: [Rect2, Vector2, float].
static func frame(code: String, k: int) -> Array:
	var c: Array = _cells[code]
	var r: Rect2 = c[0]
	return [Rect2(r.position + Vector2(r.size.x * (k % FRAMES), 0), r.size), c[1], c[2]]


## The walk phase (0..1) a hero at walk-cycle angle `cyc` shows: the frame to draw.
static func frame_of(cyc: float) -> int:
	return posmod(int(floor(cyc / TAU * FRAMES)), FRAMES)


## Bakes the atlas. Call once from a node in the tree; it takes two rendered frames.
static func bake(host: Node) -> void:
	if atlas != null or _busy or DisplayServer.get_name() == "headless":
		return
	_busy = true
	var layout := {}
	var y := 0.0
	var width := 0.0
	for code: String in Defs.ENEMIES:
		if SKIP.has(code):
			continue
		var u: float = float(Defs.ENEMIES[code]["r"]) * T * SCALE
		var cw := ceilf(u * 5.0)
		var top := u * 3.2   # cloud, mitre and banner tops
		var ch := ceilf(top + u * 1.5)
		layout[code] = [Rect2(0, y, cw, ch), Vector2(cw / 2.0, top), u]
		width = maxf(width, cw * FRAMES)
		y += ch + 2.0
	var vp := SubViewport.new()
	vp.size = Vector2i(ceili(width), ceili(y))
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := Node2D.new()
	painter.draw.connect(func() -> void:
		for code: String in layout:
			var c: Array = layout[code]
			var r: Rect2 = c[0]
			var u: float = c[2]
			for k in FRAMES:
				var cyc := TAU * (k + 0.5) / FRAMES
				var x: float = r.position.x + r.size.x * k + c[1].x
				var yb: float = r.position.y + c[1].y
				var bob := absf(cos(cyc)) * u * 0.08
				Art.hero(painter, code, x, yb - bob, yb, u, 1.0, sin(cyc), k * 0.12))
	vp.add_child(painter)
	host.add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	if img != null and not img.is_empty():
		img.generate_mipmaps()
		atlas = ImageTexture.create_from_image(img)
		_cells = layout
	vp.queue_free()
	_busy = false
