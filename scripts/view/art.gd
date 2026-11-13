class_name Art
extends RefCounted
## The game's drawn figures, on any CanvasItem: towers, heroes and map buildings. The board draws
## them in battle; icons (GameIcon) draw the same figures for the Guide, Dark Arts and the Hall of
## Fame, so every picture of a thing is the same picture.

const T := 64.0
const OUTLINE := Color("1a120c")

const TUNIC := {"p": "9a7446", "f": "4e6584", "s": "4d7638", "c": "efe9da", "k": "c9a43c", "b": "6e7682", "t": "4a3a5a", "w": "5a4630",
	"h": "a8343e", "r": "c08a60", "x": "d8dce0"}
const TUNIC_DARK := {"p": "6a4a26", "f": "2e3e54", "s": "2e4a20", "c": "b8ae96", "k": "7a5e18", "b": "3e444c", "t": "2a2036", "w": "362818",
	"h": "5e1a22", "r": "7a4e30", "x": "7e8690"}


## A hero's figure, standing at x (feet at yb, body at y) with body unit u, facing f (1 or -1),
## legs at walk (-1..1). Returns the body outline, for the hit flash.
static func hero(ci: CanvasItem, code: String, x: float, y: float, yb: float, u: float, f: float, walk: float, tm: float) -> PackedVector2Array:
	var lw := maxf(1.0, u * 0.09)
	var tun := Color(TUNIC[code])
	var dark := Color(TUNIC_DARK[code])
	if code == "k" or code == "x":  # cape behind
		var cape := PackedVector2Array([Vector2(x - f * u * 0.2, y - u * 0.35)])
		cape.append_array(Paint.quad(Vector2(x - f * u * 0.2, y - u * 0.35), Vector2(x - f * u * (0.9 + walk * 0.1), y + u * 0.2), Vector2(x - f * u * 0.6, y + u * 0.75), 6))
		cape.append(Vector2(x - f * u * 0.05, y + u * 0.55))
		ci.draw_colored_polygon(cape, Color("5a2a7a") if code == "x" else Color("8a1e2c"))
	if code == "s":  # bow on the back
		var a0 := PI * 0.6 if f > 0 else -PI * 0.4
		ci.draw_arc(Vector2(x - f * u * 0.3, y - u * 0.05), u * 0.5, a0, a0 + PI * 0.8, 12, Color("6a4a22"), maxf(1.5, u * 0.12), true)
	if code != "c":  # legs
		var lwid := maxf(2.0, u * 0.22)
		ci.draw_line(Vector2(x - u * 0.15, y + u * 0.35), Vector2(x - u * 0.15 + walk * u * 0.28, yb + u * 0.85), dark, lwid)
		ci.draw_line(Vector2(x + u * 0.15, y + u * 0.35), Vector2(x + u * 0.15 - walk * u * 0.28, yb + u * 0.85), dark, lwid)
	var body: PackedVector2Array
	if code == "c":
		body = PackedVector2Array([Vector2(x - u * 0.3, y - u * 0.35), Vector2(x + u * 0.3, y - u * 0.35), Vector2(x + u * 0.5, yb + u * 0.85), Vector2(x - u * 0.5, yb + u * 0.85)])
	else:
		body = PackedVector2Array([Vector2(x - u * 0.34, y - u * 0.35), Vector2(x + u * 0.34, y - u * 0.35), Vector2(x + u * 0.4, y + u * 0.45), Vector2(x - u * 0.4, y + u * 0.45)])
	Paint.vgrad_poly(ci, body, tun, dark)
	var bo := body.duplicate()
	bo.append(body[0])
	ci.draw_polyline(bo, OUTLINE, lw, true)
	if code == "c":
		ci.draw_line(Vector2(x, y - u * 0.3), Vector2(x, yb + u * 0.8), Color("e8b84a"), maxf(1.0, u * 0.1))
		Paint.glow(ci, Vector2(x, y - u * 0.7), u * 0.9, Color(1, 0.95, 0.7, 0.6))
	if code == "f":
		ci.draw_rect(Rect2(x - u * 0.34, y - u * 0.35, u * 0.68, u * 0.22), Color("9aa8b5"))
	if code != "c":
		ci.draw_rect(Rect2(x - u * 0.38, y + u * 0.12, u * 0.76, u * 0.09), Color("3a2414"))
	# head
	ci.draw_circle(Vector2(x, y - u * 0.68), u * 0.38, Color("f0c9a0"))
	ci.draw_arc(Vector2(x, y - u * 0.68), u * 0.38, 0, TAU, 20, OUTLINE, lw, true)
	ci.draw_rect(Rect2(x + f * u * 0.1 - u * 0.04, y - u * 0.74, maxf(1.0, u * 0.09), maxf(1.0, u * 0.1)), OUTLINE)
	_headgear(ci, code, x, y, u, f, lw)
	_held(ci, code, x, y, yb, u, f, tm)
	return body


static func hut(ci: CanvasItem, x: float, y: float, s: float, lv: int, flash: bool, tm: float, seed_x: float) -> void:
	var top := y - s * (0.44 + lv * 0.05)
	# banner
	ci.draw_line(Vector2(x + s * 0.3, y + s * 0.24), Vector2(x + s * 0.3, top - s * 0.12), Color("3a2414"), maxf(2.0, s * 0.035))
	var wv := sin(tm * 5.0 + seed_x) * s * 0.04
	var flag := PackedVector2Array([Vector2(x + s * 0.3, top - s * 0.12)])
	flag.append_array(Paint.quad(Vector2(x + s * 0.3, top - s * 0.12), Vector2(x + s * 0.42, top - s * 0.06 + wv), Vector2(x + s * 0.52, top - s * 0.04), 5))
	flag.append(Vector2(x + s * 0.3, top + s * 0.08))
	ci.draw_colored_polygon(flag, Color("c0283a") if lv == 3 else Color("9a2a2a"))
	# log walls
	Paint.hgrad_poly(ci, Paint.rect_pts(Rect2(x - s * 0.26, y - s * 0.08, s * 0.52, s * 0.36)), Color("8a5a32"), Color("4a2e18"))
	for i in range(1, 4):
		ci.draw_line(Vector2(x - s * 0.26 + i * s * 0.13, y - s * 0.08), Vector2(x - s * 0.26 + i * s * 0.13, y + s * 0.28), Color(0.18, 0.11, 0.05, 0.55), 1.0)
	var door := PackedVector2Array([Vector2(x - s * 0.08, y + s * 0.28), Vector2(x - s * 0.08, y + s * 0.1)])
	door.append_array(Paint.quad(Vector2(x - s * 0.08, y + s * 0.1), Vector2(x, y + s * 0.0), Vector2(x + s * 0.08, y + s * 0.1), 6))
	door.append(Vector2(x + s * 0.08, y + s * 0.28))
	ci.draw_colored_polygon(door, Color("120a05"))
	# hide roof
	var roof := PackedVector2Array([Vector2(x - s * 0.38, y - s * 0.02), Vector2(x, top), Vector2(x + s * 0.38, y - s * 0.02)])
	Paint.vgrad_poly(ci, roof, Color("f0c070") if flash else Color("c09a64"), Color("7a5432"))
	for i in range(1, 3):
		var k := i / 3.0
		var ry := y - s * 0.02 - (y - s * 0.02 - top) * k
		ci.draw_line(Vector2(x - s * 0.38 * (1 - k), ry), Vector2(x + s * 0.38 * (1 - k), ry), Color("5a3a1e"), 1.5)
	# bone horns
	for d in [-1.0, 1.0]:
		var horn := PackedVector2Array([Vector2(x + d * s * 0.06, top + s * 0.06)])
		horn.append_array(Paint.quad(Vector2(x + d * s * 0.06, top + s * 0.06), Vector2(x + d * s * 0.24, top - s * 0.02), Vector2(x + d * s * 0.2, top - s * 0.18), 6))
		ci.draw_polyline(horn, Color("f1e6cc"), maxf(2.0, s * 0.045), true)


static func crypt(ci: CanvasItem, x: float, y: float, s: float, lv: int, flash: bool, tm: float) -> void:
	var top := y - s * (0.48 + lv * 0.05)
	if lv >= 2:
		for px in [x - s * 0.36, x + s * 0.26]:
			Paint.vgrad_poly(ci, Paint.rect_pts(Rect2(px, y - s * 0.2, s * 0.1, s * 0.48)), Color("c3ccd2"), Color("6b767e"))
			ci.draw_rect(Rect2(px - s * 0.02, y - s * 0.24, s * 0.14, s * 0.05), Color("dfe8ee"))
	Paint.hgrad_poly(ci, Paint.rect_pts(Rect2(x - s * 0.25, y - s * 0.16, s * 0.5, s * 0.44)), Color("b8c3ca"), Color("5d6870"))
	for i in 3:
		var yy := y - s * 0.16 + i * s * 0.15
		ci.draw_line(Vector2(x - s * 0.25, yy), Vector2(x + s * 0.25, yy), Color(0.29, 0.33, 0.36, 0.55), 1.0)
		var bx := x - s * 0.25 + (s * 0.12 if i % 2 else s * 0.25)
		ci.draw_line(Vector2(bx, yy), Vector2(bx, yy + s * 0.15), Color(0.29, 0.33, 0.36, 0.55), 1.0)
	Paint.vgrad_poly(ci, PackedVector2Array([Vector2(x - s * 0.31, y - s * 0.14), Vector2(x, top), Vector2(x + s * 0.31, y - s * 0.14)]), Color("56636e"), Color("2c353d"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + s * 0.12, top + s * 0.14), Vector2(x - s * 0.12, top + s * 0.14)]), Color("eef6fa"))
	Paint.glow(ci, Vector2(x, y + s * 0.05), s * (0.4 if flash else 0.26), Color(0.56, 0.88, 1, 0.65))
	# skull
	ci.draw_circle(Vector2(x, y + s * 0.03), s * 0.1, Color("e9f1f4"))
	ci.draw_rect(Rect2(x - s * 0.06, y + s * 0.08, s * 0.12, s * 0.06), Color("e9f1f4"))
	var eye := Color.WHITE if flash else Color("4fd0ff")
	ci.draw_rect(Rect2(x - s * 0.055, y + s * 0.01, s * 0.04, s * 0.04), eye)
	ci.draw_rect(Rect2(x + s * 0.015, y + s * 0.01, s * 0.04, s * 0.04), eye)
	if lv == 3:
		var cy := top - s * 0.14 + sin(tm * 3.0) * s * 0.03
		Paint.glow(ci, Vector2(x, cy), s * 0.16, Color(0.75, 0.94, 1, 0.8))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x, cy - s * 0.1), Vector2(x + s * 0.05, cy), Vector2(x, cy + s * 0.1), Vector2(x - s * 0.05, cy)]), Color("d8f6ff"))


static func shrine(ci: CanvasItem, x: float, y: float, s: float, lv: int, flash: bool, tm: float, p: Vector2) -> void:
	var h := s * (0.5 + lv * 0.07)
	var top := y + s * 0.2 - h
	if lv >= 2:
		for d in [-1.0, 1.0]:
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x + d * s * 0.2, y + s * 0.24), Vector2(x + d * s * 0.34, y - s * 0.08), Vector2(x + d * s * 0.27, y + s * 0.24)]), Color("24140f"))
	Paint.hgrad_poly(ci, PackedVector2Array([Vector2(x - s * 0.2, y + s * 0.24), Vector2(x - s * 0.13, top + s * 0.08), Vector2(x + s * 0.13, top + s * 0.08), Vector2(x + s * 0.2, y + s * 0.24)]), Color("4a2c26"), Color("120a08"))
	var pulse := 0.55 + 0.45 * sin(tm * 4.0 + p.y)
	var rune := Color(1, (120 + pulse * 60) / 255.0, 40 / 255.0, 0.5 + pulse * 0.4)
	ci.draw_line(Vector2(x, top + s * 0.18), Vector2(x, y + s * 0.1), rune, 2.0)
	ci.draw_line(Vector2(x - s * 0.07, top + s * 0.3), Vector2(x + s * 0.07, top + s * 0.38), rune, 2.0)
	ci.draw_line(Vector2(x + s * 0.07, top + s * 0.3), Vector2(x - s * 0.07, top + s * 0.38), rune, 2.0)
	# brazier and flame
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x - s * 0.19, top + s * 0.08), Vector2(x + s * 0.19, top + s * 0.08), Vector2(x + s * 0.13, top + s * 0.15), Vector2(x - s * 0.13, top + s * 0.15)]), Color("2a1a14"))
	Paint.glow(ci, Vector2(x, top), s * (0.55 if flash else 0.38), Color(1, 0.48, 0.16, 0.55))
	var fl := sin(tm * 12.0 + p.x * 3.0) * s * 0.03
	var outer := PackedVector2Array([Vector2(x - s * 0.14, top + s * 0.08)])
	outer.append_array(Paint.quad(Vector2(x - s * 0.14, top + s * 0.08), Vector2(x - s * 0.12, top - s * 0.12), Vector2(x + fl, top - s * 0.26), 6))
	outer.append_array(Paint.quad(Vector2(x + fl, top - s * 0.26), Vector2(x + s * 0.12, top - s * 0.1), Vector2(x + s * 0.14, top + s * 0.08), 6))
	ci.draw_colored_polygon(outer, Color("ff5a1a"))
	var inner := PackedVector2Array([Vector2(x - s * 0.07, top + s * 0.08)])
	inner.append_array(Paint.quad(Vector2(x - s * 0.07, top + s * 0.08), Vector2(x - s * 0.05, top - s * 0.04), Vector2(x - fl * 0.5, top - s * 0.14), 5))
	inner.append_array(Paint.quad(Vector2(x - fl * 0.5, top - s * 0.14), Vector2(x + s * 0.06, top - s * 0.03), Vector2(x + s * 0.07, top + s * 0.08), 5))
	ci.draw_colored_polygon(inner, Color("ffd25a"))


static func _headgear(ci: CanvasItem, code: String, x: float, y: float, u: float, f: float, lw: float) -> void:
	match code:
		"p":  # straw hat
			Paint.ellipse(ci, Vector2(x, y - u * 0.9), u * 0.6, u * 0.14, Color("d9b45a"))
			ci.draw_circle(Vector2(x, y - u * 0.98), u * 0.24, Color("d9b45a"))
		"f", "b":  # helmet
			var helm := PackedVector2Array()
			for i in 11:
				var a := PI + PI * i / 10.0
				helm.append(Vector2(x, y - u * 0.74) + Vector2(cos(a), sin(a)) * u * 0.42)
			Paint.vgrad_poly(ci, helm, Color("d6dee5"), Color("7b8894"))
			ci.draw_rect(Rect2(x + f * u * 0.08 - u * 0.03, y - u * 0.76, u * 0.07, u * 0.24), Color("7b8894"))
		"s", "t":  # hood
			var hood := PackedVector2Array([Vector2(x - u * 0.42, y - u * 0.55)])
			hood.append_array(Paint.quad(Vector2(x - u * 0.42, y - u * 0.55), Vector2(x - u * 0.4, y - u * 1.15), Vector2(x - f * u * 0.2, y - u * 1.35), 6))
			hood.append_array(Paint.quad(Vector2(x - f * u * 0.2, y - u * 1.35), Vector2(x + u * 0.45, y - u * 1.1), Vector2(x + u * 0.42, y - u * 0.55), 6))
			hood.append_array(Paint.quad(Vector2(x + u * 0.42, y - u * 0.55), Vector2(x, y - u * 0.85), Vector2(x - u * 0.38, y - u * 0.57), 4))
			ci.draw_colored_polygon(hood, Color("3d6a2c") if code == "s" else Color("2e2240"))
		"w":  # wide-brimmed hat
			Paint.ellipse(ci, Vector2(x, y - u * 0.92), u * 0.7, u * 0.15, Color("2a1e14"))
			ci.draw_rect(Rect2(x - u * 0.28, y - u * 1.3, u * 0.56, u * 0.4), Color("2a1e14"))
			ci.draw_rect(Rect2(x - u * 0.28, y - u * 1.02, u * 0.56, u * 0.07), Color("8a6420"))
		"c":  # cowl
			var cowl := PackedVector2Array()
			for i in 11:
				var a := PI * 1.05 + PI * 0.9 * i / 10.0
				cowl.append(Vector2(x, y - u * 0.78) + Vector2(cos(a), sin(a)) * u * 0.4)
			ci.draw_colored_polygon(cowl, Color("efe9da"))
		"h":  # feathered cap
			Paint.ellipse(ci, Vector2(x, y - u * 0.95), u * 0.42, u * 0.2, Color("5e1a22"))
			ci.draw_line(Vector2(x - f * u * 0.2, y - u * 1.0), Vector2(x - f * u * 0.65, y - u * 1.45), Color("f0e6c8"), maxf(1.5, u * 0.12))
		"r":  # wild red hair and beard
			for i in 7:
				var a := PI + PI * i / 6.0
				ci.draw_line(Vector2(x, y - u * 0.75), Vector2(x, y - u * 0.75) + Vector2(cos(a), sin(a)) * u * 0.55, Color("b0401c"), maxf(1.5, u * 0.14))
			Paint.ellipse(ci, Vector2(x + f * u * 0.08, y - u * 0.42), u * 0.24, u * 0.16, Color("b0401c"))
		"x":  # crowned great helm
			var helm := PackedVector2Array()
			for i in 13:
				var a := PI * 0.9 + PI * 1.2 * i / 12.0
				helm.append(Vector2(x, y - u * 0.7) + Vector2(cos(a), sin(a)) * u * 0.44)
			Paint.vgrad_poly(ci, helm, Color("eef2f6"), Color("7e8690"))
			ci.draw_rect(Rect2(x - u * 0.25, y - u * 0.72, u * 0.5, u * 0.06), OUTLINE)
			var crown := PackedVector2Array([Vector2(x - u * 0.34, y - u * 1.05), Vector2(x - u * 0.34, y - u * 1.35), Vector2(x - u * 0.17, y - u * 1.18),
				Vector2(x, y - u * 1.42), Vector2(x + u * 0.17, y - u * 1.18), Vector2(x + u * 0.34, y - u * 1.35), Vector2(x + u * 0.34, y - u * 1.05)])
			ci.draw_colored_polygon(crown, Color("e8b84a"))
		"k":  # gold helm and plume
			var helm := PackedVector2Array()
			for i in 13:
				var a := PI * 0.9 + PI * 1.2 * i / 12.0
				helm.append(Vector2(x, y - u * 0.7) + Vector2(cos(a), sin(a)) * u * 0.42)
			Paint.vgrad_poly(ci, helm, Color("ffe08a"), Color("9a7420"))
			ci.draw_rect(Rect2(x - u * 0.25, y - u * 0.72, u * 0.5, u * 0.06), OUTLINE)
			var plume := PackedVector2Array([Vector2(x, y - u * 1.1)])
			plume.append_array(Paint.quad(Vector2(x, y - u * 1.1), Vector2(x - f * u * 0.5, y - u * 1.6), Vector2(x - f * u * 0.75, y - u * 1.05), 6))
			plume.append_array(Paint.quad(Vector2(x - f * u * 0.75, y - u * 1.05), Vector2(x - f * u * 0.3, y - u * 1.25), Vector2(x - f * u * 0.05, y - u * 1.12), 4))
			ci.draw_colored_polygon(plume, Color("c0283a"))


static func _held(ci: CanvasItem, code: String, x: float, y: float, yb: float, u: float, f: float, tm: float) -> void:
	var hx := x + f * u * 0.5
	var w := maxf(1.5, u * 0.11)
	match code:
		"p":  # pitchfork
			var tip := Vector2(hx + f * u * 0.15, y - u * 1.3)
			ci.draw_line(Vector2(hx, y + u * 0.5), tip, Color("6a4422"), w)
			for d in [-1.0, 0.0, 1.0]:
				ci.draw_line(tip + Vector2(d * u * 0.12, 0), tip + Vector2(d * u * 0.12, -u * 0.3), Color("8a8a8a"), maxf(1.0, u * 0.07))
			ci.draw_line(tip + Vector2(-u * 0.12, 0), tip + Vector2(u * 0.12, 0), Color("8a8a8a"), maxf(1.0, u * 0.07))
		"b":  # tall tower shield held in front
			var sc := Vector2(x + f * u * 0.35, y + u * 0.1)
			var tall := Paint.rect_pts(Rect2(sc - Vector2(0.32, 0.6) * u, Vector2(0.64, 1.2) * u))
			Paint.vgrad_poly(ci, tall, Color("9aa8b5"), Color("5a6672"))
			tall.append(tall[0])
			ci.draw_polyline(tall, Color("c9d2da"), maxf(1.0, u * 0.1), true)
			ci.draw_line(sc + Vector2(0, -0.5) * u, sc + Vector2(0, 0.5) * u, Color("c9d2da"), maxf(1.0, u * 0.08))
		"t":  # dagger and a sack for stolen gems
			ci.draw_line(Vector2(hx, y + u * 0.2), Vector2(hx + f * u * 0.35, y - u * 0.25), Color("dfe6ec"), maxf(1.5, u * 0.09))
			Paint.ellipse(ci, Vector2(x - f * u * 0.45, y + u * 0.35), u * 0.28, u * 0.24, Color("7a5a32"))
			ci.draw_line(Vector2(x - f * u * 0.45, y + u * 0.1), Vector2(x - f * u * 0.2, y - u * 0.3), Color("5a3e20"), maxf(1.0, u * 0.07))
		"w":  # lantern on a pole
			var top := Vector2(hx + f * u * 0.1, y - u * 1.1)
			ci.draw_line(Vector2(hx, yb + u * 0.8), top, Color("4a3220"), w)
			Paint.glow(ci, top + Vector2(0, u * 0.25), u * (1.0 + 0.1 * sin(tm * 6.0)), Color(1, 0.85, 0.45, 0.55))
			ci.draw_rect(Rect2(top + Vector2(-0.14, 0.1) * u, Vector2(0.28, 0.32) * u), Color("ffd27a"))
			ci.draw_rect(Rect2(top + Vector2(-0.14, 0.1) * u, Vector2(0.28, 0.32) * u), Color("3a2a18"), false, maxf(1.0, u * 0.06))
		"c":  # holy staff
			ci.draw_line(Vector2(hx, yb + u * 0.8), Vector2(hx, y - u * 1.2), Color("8a6420"), w)
			ci.draw_line(Vector2(hx - u * 0.18, y - u * 1.0), Vector2(hx + u * 0.18, y - u * 1.0), Color("8a6420"), w)
		"h":  # war banner
			var top := Vector2(hx, y - u * 1.6)
			ci.draw_line(Vector2(hx, yb + u * 0.8), top, Color("4a3220"), w)
			var wave := sin(tm * 5.0) * u * 0.08
			var flag := PackedVector2Array([top, top + Vector2(-f * u * 0.75, wave), top + Vector2(-f * u * 0.7, u * 0.5 + wave), top + Vector2(0, u * 0.45)])
			ci.draw_colored_polygon(flag, Color("e8b84a"))
			ci.draw_circle(top + Vector2(-f * u * 0.36, u * 0.24 + wave * 0.5), u * 0.1, Color("a8343e"))
		"r":  # two-handed axe
			var tip := Vector2(hx + f * u * 0.2, y - u * 1.25)
			ci.draw_line(Vector2(hx - f * u * 0.15, y + u * 0.45), tip, Color("6a4422"), w)
			var blade := PackedVector2Array([tip + Vector2(0, -u * 0.05), tip + Vector2(f * u * 0.45, -u * 0.3), tip + Vector2(f * u * 0.45, u * 0.35), tip + Vector2(0, u * 0.2)])
			ci.draw_colored_polygon(blade, Color("c9d2da"))
		"f", "k", "x":
			var knight := code == "k" or code == "x"
			var tip := Vector2(hx + f * u * 0.05, y - u * (0.9 if knight else 1.4))
			ci.draw_line(Vector2(hx - f * u * 0.1, y + u * 0.3), tip, Color("dfe6ec") if knight else Color("6a4422"), w)
			if not knight:
				ci.draw_colored_polygon(PackedVector2Array([tip, Vector2(hx + f * u * 0.1, y - u * 1.15), Vector2(hx, y - u * 1.15)]), Color("cfd6dc"))
			var sc := Vector2(x + f * u * 0.32, y + u * 0.02)
			var shield := PackedVector2Array([sc + Vector2(-0.28, -0.32) * u, sc + Vector2(0.28, -0.32) * u, sc + Vector2(0.26, 0.1) * u])
			shield.append_array(Paint.quad(sc + Vector2(0.26, 0.1) * u, sc + Vector2(0, 0.45) * u, sc + Vector2(-0.26, 0.1) * u, 6))
			ci.draw_colored_polygon(shield, Color("a01e2e") if knight else Color("2f4f8a"))
			var rim := Color("e8b84a") if knight else Color("c9d2da")
			var so := shield.duplicate()
			so.append(shield[0])
			ci.draw_polyline(so, rim, maxf(1.0, u * 0.09), true)
			ci.draw_line(sc + Vector2(0, -0.28) * u, sc + Vector2(0, 0.3) * u, rim, maxf(1.0, u * 0.09))
			ci.draw_line(sc + Vector2(-0.2, -0.1) * u, sc + Vector2(0.2, -0.1) * u, rim, maxf(1.0, u * 0.09))




## A map building at c (pixels, tile centre): "mine", "well" or "camp" (barracks). A razed
## barracks is ruins; cell seeds where its charred beams lie.
static func site(ci: CanvasItem, kind: String, c: Vector2, owned: bool, tm: float, cell: Vector2i) -> void:
	match kind:
		"mine":
			var hill := PackedVector2Array([c + Vector2(-0.45, 0.3) * T])
			hill.append_array(Paint.quad(c + Vector2(-0.45, 0.3) * T, c + Vector2(0, -0.6) * T, c + Vector2(0.45, 0.3) * T, 10))
			Paint.vgrad_poly(ci, hill, Color("8a7a66"), Color("3e342a"))
			var mouth := PackedVector2Array([c + Vector2(-0.16, 0.3) * T, c + Vector2(-0.16, 0.02) * T, c + Vector2(0.16, 0.02) * T, c + Vector2(0.16, 0.3) * T])
			ci.draw_colored_polygon(mouth, Color("0c0807"))
			ci.draw_line(c + Vector2(-0.19, 0.3) * T, c + Vector2(-0.19, -0.02) * T, Color("6a4422"), 3.0)
			ci.draw_line(c + Vector2(0.19, 0.3) * T, c + Vector2(0.19, -0.02) * T, Color("6a4422"), 3.0)
			ci.draw_line(c + Vector2(-0.23, -0.02) * T, c + Vector2(0.23, -0.02) * T, Color("6a4422"), 3.0)
			if owned:
				Paint.glow(ci, c + Vector2(0, 0.18) * T, T * 0.3, Color(1, 0.8, 0.3, 0.6))
				for i in 3:
					var k := fmod(tm * 0.8 + i * 0.33, 1.0)
					ci.draw_circle(c + Vector2(-0.1 + i * 0.1, 0.1 - k * 0.5) * T, T * 0.03, Color(1, 0.85, 0.35, 1.0 - k))
		"well":
			Paint.ellipse(ci, c + Vector2(0, 0.12) * T, T * 0.34, T * 0.2, Color("6e665c"))
			Paint.ellipse(ci, c + Vector2(0, 0.08) * T, T * 0.26, T * 0.14, Color("2a2440") if not owned else Color("5a48d0"))
			Paint.ellipse_outline(ci, c + Vector2(0, 0.12) * T, T * 0.34, T * 0.2, Color("a69c8e"), 2.0)
			if owned:
				Paint.glow(ci, c, T * (0.45 + 0.05 * sin(tm * 3.0)), Color(0.5, 0.42, 0.95, 0.55))
				for i in 3:
					var k := fmod(tm * 0.6 + i * 0.33, 1.0)
					ci.draw_circle(c + Vector2(-0.12 + i * 0.12, 0.05 - k * 0.55) * T, T * 0.025, Color(0.8, 0.75, 1, 1.0 - k))
		"camp":
			if owned:
				for i in 5:
					var q := c + Vector2(Paint.hash01(cell.x, cell.y, i) - 0.5, Paint.hash01(cell.x, cell.y, i + 9) * 0.4) * T * 0.8
					ci.draw_line(q, q + Vector2(0.18, -0.05) * T, Color("1c1210"), 4.0)
				Paint.glow(ci, c + Vector2(0, 0.15) * T, T * 0.25, Color(1, 0.4, 0.1, 0.3 + 0.1 * sin(tm * 5.0)))
				return
			# palisade, tent and the heroes' banner
			for i in 7:
				var px := c.x + (i - 3) * T * 0.13
				ci.draw_colored_polygon(PackedVector2Array([Vector2(px - T * 0.05, c.y + T * 0.32), Vector2(px - T * 0.05, c.y + T * 0.02), Vector2(px, c.y - T * 0.06), Vector2(px + T * 0.05, c.y + T * 0.02), Vector2(px + T * 0.05, c.y + T * 0.32)]), Color("7a5432") if i % 2 else Color("6a4628"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.24, 0.05) * T, c + Vector2(0, -0.4) * T, c + Vector2(0.24, 0.05) * T]), Color("d8d0bc"))
			ci.draw_line(c + Vector2(0, -0.4) * T, c + Vector2(0, 0.05) * T, Color("9a9280"), 1.5)
			var pole := c + Vector2(0.3, -0.05) * T
			ci.draw_line(pole, pole + Vector2(0, -0.55) * T, Color("3a2414"), 2.5)
			var wv := sin(tm * 5.0) * T * 0.03
			ci.draw_colored_polygon(PackedVector2Array([pole + Vector2(0, -0.55) * T, pole + Vector2(0.26, -0.48) * T + Vector2(0, wv), pole + Vector2(0, -0.38) * T]), Color("2f4f8a"))
