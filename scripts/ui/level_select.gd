extends Control
## The campaign map: one marker per level along a winding trail. Beaten levels show their
## best rating as gems, the next level glows, and locked levels can't be started.
## Builds its own nodes in code, like the HUD, and borrows the HUD's fonts and styles.

signal level_chosen(index: int)
signal skills_pressed

const Hud := preload("res://scripts/ui/hud.gd")

## Where each campaign stop sits, as a fraction of the screen. Spots past the last level file
## are drawn as unexplored ground, so the map shows how much campaign is planned.
const SPOTS: Array[Vector2] = [Vector2(0.07, 0.70), Vector2(0.19, 0.36), Vector2(0.31, 0.68), Vector2(0.44, 0.34),
	Vector2(0.56, 0.66), Vector2(0.68, 0.32), Vector2(0.81, 0.64), Vector2(0.93, 0.30)]

var _hud: Control
var _levels: Array = []       # [{"id", "title", "waves"}]
var _save: SaveData
var _markers: Array = []
var _heading: Label
var _sub: Label
var _reset: Button
var _reset_armed := false
var _skills: Button
var _sound: Button


func setup(hud: Control, levels: Array, save: SaveData) -> void:
	_hud = hud
	_levels = levels
	_save = save
	theme = hud.theme
	mouse_filter = Control.MOUSE_FILTER_STOP
	_heading = Label.new()
	_heading.text = "The Hoard Road"
	_heading.add_theme_font_override("font", hud.display_font)
	_heading.add_theme_font_size_override("font_size", 52)
	_heading.add_theme_color_override("font_color", Hud.GOLD)
	add_child(_heading)
	_sub = Label.new()
	_sub.add_theme_font_override("font", hud.body_font)
	_sub.add_theme_color_override("font_color", Hud.DIM)
	add_child(_sub)
	for i in mini(levels.size(), SPOTS.size()):
		var m := Marker.new()
		m.index = i
		m.title = levels[i]["title"]
		m.font = hud.bold_font
		m.number_font = hud.display_font
		m.pressed.connect(_on_marker)
		add_child(m)
		_markers.append(m)
	_skills = Button.new()
	_skills.focus_mode = Control.FOCUS_NONE
	_skills.custom_minimum_size = Vector2(0, 68)
	_skills.add_theme_font_size_override("font_size", 30)
	_skills.add_theme_stylebox_override("normal", hud._box(Color("3d2a12"), Color("8a6420"), 4, 8, 18))
	_skills.pressed.connect(func() -> void: skills_pressed.emit())
	add_child(_skills)
	_reset = Button.new()
	_reset.focus_mode = Control.FOCUS_NONE
	_reset.add_theme_font_size_override("font_size", 26)
	_reset.custom_minimum_size = Vector2(0, 60)
	_reset.add_theme_color_override("font_color", Hud.DIM)
	_reset.pressed.connect(_on_reset)
	add_child(_reset)
	_sound = hud.sound_button(self)
	_sound.custom_minimum_size = Vector2(0, 60)
	_sound.add_theme_font_size_override("font_size", 26)
	resized.connect(_layout)
	refresh()


## Re-reads the save, e.g. after a battle ends.
func refresh() -> void:
	var beaten := 0
	for m: Marker in _markers:
		var id: String = _levels[m.index]["id"]
		m.locked = not _save.is_unlocked(m.index)
		m.stars = _save.stars(id)
		m.night = -1 if not _save.night_unlocked(id) else _save.stars(SaveData.mission_id(id, true))
		m.current = not m.locked and m.stars == 0
		m.queue_redraw()
		if m.stars > 0:
			beaten += 1
	_sub.text = "%d of %d lairs defended. Tap a lair to defend it." % [beaten, _levels.size()]
	var free := _save.points_free()
	_skills.text = "Dark Arts · ★ %d%s" % [_save.points_total(), "  (%d to spend)" % free if free > 0 else ""]
	_reset_armed = false
	_reset.text = "Reset progress"
	_layout()
	queue_redraw()


func _layout() -> void:
	if _heading == null:
		return
	_heading.reset_size()
	_heading.position = Vector2((size.x - _heading.size.x) / 2.0, size.y * 0.04)
	_sub.reset_size()
	_sub.position = Vector2((size.x - _sub.size.x) / 2.0, _heading.position.y + _heading.size.y)
	for m: Marker in _markers:
		m.size = Marker.SIZE
		m.position = _spot(m.index) - Vector2(Marker.SIZE.x / 2.0, Marker.R)
	_reset.reset_size()
	_reset.position = size - _reset.size - Vector2(14, 12)
	_sound.reset_size()
	_sound.position = Vector2(_reset.position.x - _sound.size.x - 10, size.y - _sound.size.y - 12)
	_skills.reset_size()
	_skills.position = Vector2(14, size.y - _skills.size.y - 12)
	queue_redraw()


func _spot(i: int) -> Vector2:
	# Keep markers clear of the heading on short (landscape phone) screens.
	var top := 130.0
	return Vector2(SPOTS[i].x * size.x, top + SPOTS[i].y * (size.y - top - 60.0))


func _on_marker(i: int) -> void:
	Sfx.play("click")
	if _save.is_unlocked(i):
		level_chosen.emit(i)
	else:
		_hud.toast("Defend the previous lair first")


## Two taps, so a stray touch can't wipe the campaign.
func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset.text = "Tap again to erase all progress"
		_layout()
		return
	_save.reset()
	Prefs.set_value("tutorial_done", false)
	Prefs.set_value("arts_tip", 0)
	Prefs.set_value("arts_intro", false)
	_save.save()
	refresh()
	_hud.toast("Progress erased")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Hud.NIGHT)
	# Faint patches of moss, frost and ash so the map reads as land, not a blank page.
	var tints := [Color8(58, 74, 44), Color8(70, 86, 104), Color8(86, 60, 52)]
	for k in 46:
		var p := Vector2(Paint.hash01(k, 1) * size.x, Paint.hash01(k, 2) * size.y)
		var r := 40.0 + Paint.hash01(k, 3) * 110.0
		Paint.glow(self, p, r, Color(tints[k % 3], 0.22))
	# The trail between stops: bright where it has been walked, dim and dotted beyond.
	for i in SPOTS.size() - 1:
		var a := _spot(i)
		var b := _spot(i + 1)
		var bend := Vector2(0, -60.0 if i % 2 == 0 else 60.0)
		var pts := PackedVector2Array([a])
		pts.append_array(Paint.quad(a, (a + b) / 2.0 + bend, b, 24))
		var walked := i + 1 < _levels.size() and _save.is_unlocked(i + 1)
		var col: Color = Color(Hud.GOLD, 0.75) if walked else Color(Hud.DIM, 0.3)
		for j in range(1, pts.size() - 1):
			if walked or j % 2 == 0:
				draw_circle(pts[j], 3.0 if walked else 2.5, col)
	# Planned stops with no level yet.
	for i in range(_levels.size(), SPOTS.size()):
		var c := _spot(i)
		Paint.ellipse(self, c, Marker.R * 0.8, Marker.R * 0.8, Color(0, 0, 0, 0.35))
		Paint.ellipse_outline(self, c, Marker.R * 0.8, Marker.R * 0.8, Color(Hud.DIM, 0.25), 2.0)
		draw_string(_hud.bold_font, c + Vector2(-40, Marker.R + 26), "Uncharted", HORIZONTAL_ALIGNMENT_CENTER, 80, 19, Color(Hud.DIM, 0.4))


## One tappable lair on the map.
class Marker extends Control:
	signal pressed(index: int)

	const R := 34.0
	const SIZE := Vector2(240, 140)

	var index := 0
	var title := ""
	var locked := true
	var current := false
	var stars := 0
	var night := -1       # -1 locked, 0 open but unbeaten, 1-3 night rating
	var font: Font
	var number_font: Font
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _process(delta: float) -> void:
		if current:
			_t += delta
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if event.position.distance_to(Vector2(size.x / 2.0, R)) <= R + 14.0 or event.position.y > R * 2.0:
				pressed.emit(index)
				accept_event()

	func _draw() -> void:
		var c := Vector2(size.x / 2.0, R)
		if current:
			Paint.glow(self, c, R * 2.2 + sin(_t * 3.0) * 6.0, Color("e2683a", 0.55))
		var fill := Color("2f251b") if not locked else Color("1c160f")
		var edge := Color("e8b84a") if stars > 0 else (Color("e2683a") if current else Color("5b4630"))
		Paint.ellipse(self, c, R, R, fill)
		Paint.ellipse_outline(self, c, R, R, edge, 3.0)
		if locked:
			# A small padlock.
			draw_arc(c + Vector2(0, -4), 8, PI, TAU, 12, Color("6b5236"), 3.0, true)
			draw_rect(Rect2(c + Vector2(-11, -4), Vector2(22, 16)), Color("6b5236"))
		else:
			var num := str(index + 1)
			var w := number_font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
			draw_string(number_font, c + Vector2(-w / 2.0, 12), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("efe4cc"))
		if not locked:
			_draw_moon(c + Vector2(R * 1.05, -R * 0.55))
		var tc := Color("efe4cc") if not locked else Color("a8977c", 0.6)
		draw_string(font, Vector2(0, R * 2.0 + 24), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 25, tc)
		# Best rating as three stars: gold ones earned, dark ones still to win.
		for k in 3:
			var p := Vector2(size.x / 2.0 + (k - 1) * 22.0, R * 2.0 + 44)
			if k < stars:
				_draw_star(p, 10.0, Color("e8b84a"))
			elif not locked:
				_draw_star(p, 10.0, Color(0, 0, 0, 0.45))

	## Night mission badge: a faint crescent until unlocked, pale and glowing when open,
	## gold once won, with one dot per night rating.
	func _draw_moon(m: Vector2) -> void:
		var r := 11.0
		var outer := Paint.ellipse_pts(m, r, r, 24)
		var bite := Paint.ellipse_pts(m + Vector2(r * 0.55, -r * 0.3), r * 0.85, r * 0.85, 24)
		var col := Color("a8977c", 0.3)
		if night == 0:
			col = Color("dfe6ff")
			Paint.glow(self, m, r * 2.4, Color(0.62, 0.7, 1, 0.45))
		elif night > 0:
			col = Color("e8b84a")
			Paint.glow(self, m, r * 2.2, Color(1, 0.8, 0.3, 0.35))
		for poly in Geometry2D.clip_polygons(outer, bite):
			draw_colored_polygon(poly, col)
		for k in maxi(0, night):
			draw_circle(m + Vector2(r + 5, -6 + k * 6), 2.2, Color("e8b84a"))

	func _draw_star(c: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 10:
			var a := -PI / 2.0 + i * PI / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
		draw_colored_polygon(pts, col)
		if col.a > 0.5:
			pts.append(pts[0])
			draw_polyline(pts, Color("5a3a10"), 1.0, true)


## For the tutorial spotlight.
func skills_rect() -> Rect2:
	return _skills.get_global_rect()
