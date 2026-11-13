class_name Frames
extends RefCounted
## Carved frames for panels and buttons: a nine-patch drawn in code (no image files), with a bevelled
## rim lit from the top left, a dark groove, a faint gold inlay and small studs in the corners, over
## a softly graded fill. Each colour pair is drawn once and cached.

const SIZE := 48
const R := 10.0        # corner radius
const MARGIN := 14     # nine-patch margin: the corners and rim stay crisp at any size

static var _cache := {}


## A carved StyleBoxTexture. lip: a thicker dark bottom edge (buttons stand up off the page);
## pad: the content margin, like Hud._box.
static func carved(bg: Color, rim: Color, lip := 4, pad := 14, studs := true) -> StyleBoxTexture:
	var key := "%s|%s|%d|%s" % [bg.to_html(), rim.to_html(), lip, studs]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_paint(bg, rim, lip, studs))
	var sb := StyleBoxTexture.new()
	sb.texture = _cache[key]
	sb.set_texture_margin_all(MARGIN)
	sb.texture_margin_bottom = MARGIN + lip
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.6
	sb.content_margin_bottom = pad * 0.6 + lip * 0.5
	return sb


## Signed distance from (x, y) to the edge of the rounded rectangle (negative inside).
static func _sdf(p: Vector2, half: Vector2, r: float) -> float:
	var q := p.abs() - half + Vector2(r, r)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r


static func _paint(bg: Color, rim: Color, lip: int, studs: bool) -> Image:
	var h := SIZE + lip
	var img := Image.create(SIZE, h, false, Image.FORMAT_RGBA8)
	var half := Vector2(SIZE, h) / 2.0
	var inlay := Color(Color("e8b84a"), 0.22 * rim.a)
	for y in h:
		for x in SIZE:
			var p := Vector2(x + 0.5, y + 0.5) - half
			var d := -_sdf(p, half, R)   # depth inside the edge, in pixels
			if d <= -0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var col: Color
			var below := y >= h - lip - 2 and lip > 0   # the bottom lip
			if d < 2.5 or below and d < lip + 2.5:
				# The rim: lighter facing the top left, darker facing the bottom right.
				var lit := clampf((-p.x / half.x - p.y / half.y) * 0.5, -1.0, 1.0)
				col = rim.lightened(0.3 * lit) if lit > 0.0 else rim.darkened(-0.45 * lit)
				if below and d >= 2.5:
					col = rim.darkened(0.55)
			elif d < 4.0:
				col = bg.darkened(0.5)   # the groove
			else:
				var k := float(y) / h
				col = bg.lightened(0.07 * (1.0 - k)) if k < 0.5 else bg.darkened(0.12 * (k - 0.5) * 2.0)
				var grain := (Paint.hash01(x, y, 7) - 0.5) * 0.035
				col = Color(col.r + grain, col.g + grain, col.b + grain, col.a)
				if d < 5.5:
					col = col.blend(inlay)
			col.a *= clampf(d + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, col)
	if studs and rim.a > 0.0:
		for c in [Vector2(7, 7), Vector2(SIZE - 7, 7), Vector2(7, h - lip - 7), Vector2(SIZE - 7, h - lip - 7)]:
			for y in range(int(c.y) - 2, int(c.y) + 3):
				for x in range(int(c.x) - 2, int(c.x) + 3):
					var r := Vector2(x + 0.5, y + 0.5).distance_to(c)
					if r < 2.2:
						img.set_pixel(x, y, rim.lightened(0.45 - r * 0.15))
	return img
