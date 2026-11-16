class_name SpriteCache
extends RefCounted
## Pictures drawn once into a texture and from then on drawn as one textured rectangle each, so a
## tower that took forty shapes a frame costs one. The same idea as HeroSprites, for anything:
##
##   var e := SpriteCache.find(key)          # [texture, source Rect2, box Rect2] or [] if not baked
##   if e.is_empty(): SpriteCache.want(key, box, painter) and draw it the old way this frame
##   else: ci.draw_texture_rect_region(e[0], Rect2(at + box.position, box.size), e[1])
##
## `box` is the picture's extent around its anchor in board pixels, and `painter` a
## Callable(ci: CanvasItem, at: Vector2) that draws it with its anchor at `at`, as a board would.
## Wanted pictures are drawn together, a frame or two later, into one SubViewport (UPDATE_ONCE)
## at `scale` pixels per board pixel (Quality.bake_scale), packed side by side; every batch
## becomes one texture (an atlas page), so pictures of one batch batch with each other when drawn.
##
## A SubViewport's transparent output is premultiplied. A second pass (unpremult.gdshader, blend
## disabled) turns it back into ordinary alpha, so the pictures can be drawn on any canvas item
## with the usual blending, between live shapes, in the order the board always drew them.
##
## Headless runs render nothing, so nothing is ever baked there and callers keep drawing shape by
## shape. `clear()` drops everything (leaving a battle, a new quality or window scale).

## Atlas pages are Quality.page_size() pixels wide; a batch taller than that waits for the next page.
const PAD := 2            # empty pixels around each picture, so filtering never bleeds

static var scale := 1.0
static var _pics := {}    # key -> [Texture2D, Rect2 src (pixels), Rect2 box (board px)]
static var _old := {}     # the pictures from before renew(), shown until their new versions are baked
static var _want := {}    # key -> [Rect2 box, Callable painter], waiting for the next batch
static var _host: Node
static var _busy := false
static var _gen := 0      # bumps on clear(): a batch still baking is then thrown away
static var _unpremult: Shader
static var pages := 0     # atlas pages made since the last clear (for the perf notes)
static var pixels := 0    # their pixels
static var bake_ms := 0.0  # main-thread time the batches took (read back, fix edges, mipmaps, upload)


## Where batches are baked: any node in the tree (the board).
static func setup(host: Node) -> void:
	_host = host


static func enabled() -> bool:
	return DisplayServer.get_name() != "headless" and _host != null and _host.is_inside_tree()


## The baked picture: [texture, source rectangle, box], or [] when it is not baked (yet).
static func find(key: String) -> Array:
	var e: Array = _pics.get(key, [])
	return e if not e.is_empty() or _old.is_empty() else _old.get(key, [])


static func has(key: String) -> bool:
	return _pics.has(key)


## Asks for a picture; it is baked with the next batch, a frame or two from now.
static func want(key: String, box: Rect2, painter: Callable) -> void:
	if _pics.has(key) or _want.has(key) or not enabled():
		return
	_want[key] = [box, painter]
	if not _busy:
		_busy = true
		_bake.call_deferred()


## Draws picture `key` with its anchor at `at`, scaled by `k` about the anchor; false (and nothing
## drawn) when it is not baked.
static func put(ci: CanvasItem, key: String, at: Vector2, mod := Color.WHITE, k := Vector2.ONE) -> bool:
	var e := find(key)
	if e.is_empty():
		return false
	var b: Rect2 = e[2]
	ci.draw_texture_rect_region(e[0], Rect2(at + b.position * k, b.size * k), e[1], mod)
	return true


## Forgets every picture (leaving a battle, another lair).
static func clear() -> void:
	_pics.clear()
	_old.clear()
	_want.clear()
	_gen += 1
	_busy = false
	pages = 0
	pixels = 0
	bake_ms = 0.0


## Starts again at another scale or quality without a gap: until a picture is baked anew, its
## old version is drawn (boxes are in board pixels, so any scale fits).
static func renew() -> void:
	var keep := _pics.duplicate()
	clear()
	_old = keep


static func pending() -> int:
	return _want.size()


static func _bake() -> void:
	if _want.is_empty() or not enabled():
		_busy = false
		return
	var gen := _gen
	var k := scale
	var page := Quality.page_size()
	# Shelf packing, tallest first, PAGE pixels wide; what does not fit waits for the next batch.
	var keys: Array = _want.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return _want[a][0].size.y > _want[b][0].size.y)
	var place := {}
	var x := 0
	var y := 0
	var row := 0
	for key: String in keys:
		var box: Rect2 = _want[key][0]
		var w := ceili(box.size.x * k) + PAD * 2
		var h := ceili(box.size.y * k) + PAD * 2
		if x + w > page:
			x = 0
			y += row
			row = 0
		if y + h > page:
			break
		place[key] = Rect2(x, y, w, h)
		x += w
		row = maxi(row, h)
	var height := y + row
	var width := page if height > row else x
	var jobs := {}
	for key: String in place:
		jobs[key] = _want[key]
		_want.erase(key)
	var vp := SubViewport.new()
	vp.size = Vector2i(maxi(1, width), maxi(1, height))
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := Node2D.new()
	painter.draw.connect(func() -> void:
		for key: String in jobs:
			var r: Rect2 = place[key]
			var box: Rect2 = jobs[key][0]
			painter.draw_set_transform(r.position + Vector2(PAD, PAD) - box.position * k, 0.0, Vector2(k, k))
			jobs[key][1].call(painter, Vector2.ZERO)
		painter.draw_set_transform(Vector2.ZERO))
	vp.add_child(painter)
	# Second pass: premultiplied back to ordinary alpha.
	if _unpremult == null:
		_unpremult = preload("res://scripts/view/unpremult.gdshader")
	var vp2 := SubViewport.new()
	vp2.size = vp.size
	vp2.transparent_bg = true
	vp2.disable_3d = true
	vp2.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var spr := Sprite2D.new()
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.texture = vp.get_texture()
	spr.material = ShaderMaterial.new()
	spr.material.shader = _unpremult
	vp2.add_child(spr)
	_host.add_child(vp)
	_host.add_child(vp2)
	await RenderingServer.frame_post_draw
	if gen == _gen and is_instance_valid(vp2):
		vp2.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var t0 := Time.get_ticks_usec()
	var img: Image = null
	if gen == _gen and is_instance_valid(vp2):
		img = vp2.get_texture().get_image()
	if is_instance_valid(vp):
		vp.queue_free()
	if is_instance_valid(vp2):
		vp2.queue_free()
	if gen != _gen:
		return   # cleared meanwhile; that clear() reset _busy
	if img != null and not img.is_empty():
		img.generate_mipmaps()
		var tex := ImageTexture.create_from_image(img)
		bake_ms += (Time.get_ticks_usec() - t0) / 1000.0
		pages += 1
		pixels += img.get_width() * img.get_height()
		for key: String in place:
			var r: Rect2 = place[key]
			_pics[key] = [tex, Rect2(r.position + Vector2(PAD, PAD), r.size - Vector2(PAD, PAD) * 2.0), jobs[key][0]]
	if _want.is_empty():
		_busy = false
		_old.clear()   # everything asked for is baked: the old pictures can go
	else:
		_bake.call_deferred()
