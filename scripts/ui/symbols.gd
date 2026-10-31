class_name Symbols
extends RefCounted
## A tiny fallback font, drawn in code, for the symbols the text fonts lack: ★ (stars), ● and ○
## (skill ranks). Desktop and phone systems supply these themselves, but a browser does not,
## so without it the web build shows empty boxes. Used everywhere so they look the same.

const CELL := 64
const ASCENT := 50
const DESCENT := 14
const GLYPHS := [0x2605, 0x25CF, 0x25CB]   # ★ ● ○

static var _font: FontFile


static func font() -> FontFile:
	if _font:
		return _font
	var img := Image.create_empty(CELL * GLYPHS.size(), CELL, false, Image.FORMAT_RGBA8)
	var advances := [60, 44, 44]
	for gi in GLYPHS.size():
		for y in CELL:
			for x in CELL:
				var cover := 0
				for sy in 4:       # 4×4 samples per pixel for smooth edges
					for sx in 4:
						if _inside(GLYPHS[gi], Vector2(x + (sx + 0.5) / 4.0, y + (sy + 0.5) / 4.0)):
							cover += 1
				if cover > 0:
					img.set_pixel(gi * CELL + x, y, Color(1, 1, 1, cover / 16.0))
	var f := FontFile.new()
	var sz := Vector2i(CELL, 0)
	f.fixed_size = CELL
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
	f.set_cache_ascent(0, CELL, ASCENT)
	f.set_cache_descent(0, CELL, DESCENT)
	f.set_texture_image(0, sz, 0, img)
	for gi in GLYPHS.size():
		var g: int = GLYPHS[gi]
		f.set_glyph_advance(0, CELL, g, Vector2(advances[gi], 0))
		f.set_glyph_offset(0, sz, g, Vector2(0, -ASCENT))
		f.set_glyph_size(0, sz, g, Vector2(CELL, CELL))
		f.set_glyph_uv_rect(0, sz, g, Rect2(gi * CELL, 0, CELL, CELL))
		f.set_glyph_texture_idx(0, sz, g, 0)
	_font = f
	return f


## Whether point p (in the glyph's 64-pixel cell, y down) is inked.
static func _inside(g: int, p: Vector2) -> bool:
	match g:
		0x2605:
			var c := Vector2(30, 28)
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2.0 + PI * i / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * (26.0 if i % 2 == 0 else 11.0))
			return Geometry2D.is_point_in_polygon(p, pts)
		0x25CF:
			return p.distance_to(Vector2(22, 31)) <= 15.0
		0x25CB:
			var d := p.distance_to(Vector2(22, 31))
			return d <= 15.0 and d >= 10.5
	return false
