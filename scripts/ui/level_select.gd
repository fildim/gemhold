extends Control
## The campaign map: one marker per level along a winding trail. Beaten levels show their
## best rating as gems, the next level glows, and locked levels can't be started.
## Builds its own nodes in code, like the HUD, and borrows the HUD's fonts and styles.

signal level_chosen(index: int)
signal skills_pressed
signal guide_pressed
signal hall_pressed
signal race_pressed   # the Race button: the Hall of Fame's Race page
signal full_unlocked   # a full-game code was accepted (main puts it on the account)

const Hud := preload("res://scripts/ui/hud.gd")

## The campaign comes in chapters of PER_PAGE lairs, one chapter on screen at a time. SPOTS is
## where each stop of a chapter sits, as a fraction of the screen. Every chapter reads the same
## way: the road zigzags left to right between a top and a bottom row, comes in at the left edge
## from the previous chapter and leaves at the right edge for the next, where the chapter buttons
## sit. Spots past the last level file are drawn as unexplored ground.
const PER_PAGE := 10
const SPOTS: Array[Vector2] = [Vector2(0.095, 0.27), Vector2(0.185, 0.70), Vector2(0.275, 0.27), Vector2(0.365, 0.70), Vector2(0.455, 0.27),
	Vector2(0.545, 0.70), Vector2(0.635, 0.27), Vector2(0.725, 0.70), Vector2(0.815, 0.27), Vector2(0.905, 0.70)]
const CHAPTERS: Array[String] = ["Chapter I: The Lowland Roads", "Chapter II: The Crusade", "Chapter III: The Drowned Marches", "Chapter IV: The Siegeworks", "Chapter V: The Radiant Host"]

var _hud: Control
var _levels: Array = []       # [{"id", "title", "waves"}]
var _save: SaveData
var focus_lair := -1               # lair just played (0-based): the map opens on its chapter, or -1 for the newest
var _markers: Array = []
var _heading: Label
var _sub: Label
var _reset: Button
var _confirm: Control       # "Erase all progress?" dialog
var _offer: Control         # demo builds: "get the full game" dialog
var _skills: Button
var _sound: Button
var _info: Button          # opens _info_panel: version, contact, full-game code
var _info_panel: Control
var online: Online   # set by main: sends the Info page's feedback
const CONTACT := "contactgemhold@gmail.com"
var _guide: Button
var _hall: Button
var _race: Button   # online races, in ember so it stands out
var _race_texts := ["Race a friend", "Race"]   # its label, and a short one for narrow screens
var _compact := false   # the bottom-left buttons were made smaller to fit (narrow screens)
var _points_badge: Label   # unspent skill points, on the Dark Arts button's corner
var _compact_w := 0.0  # the width it happened at: wider again, the buttons go back to full size
var _page := 0
var _beaten := 0
var _prev: Button
var _next: Button


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
	for i in levels.size():
		var m := Marker.new()
		m.index = i
		m.above = i % 2 == 0   # top row
		m.title = levels[i]["title"]
		m.font = hud.bold_font
		m.number_font = hud.display_font
		m.pressed.connect(_on_marker)
		add_child(m)
		_markers.append(m)
	_skills = Button.new()
	_skills.focus_mode = Control.FOCUS_NONE
	_skills.add_theme_stylebox_override("normal", hud._box(Color("3d2a12"), Color("8a6420"), 4, 8, 18))
	_skills.pressed.connect(func() -> void: skills_pressed.emit())
	add_child(_skills)
	_guide = Button.new()
	_guide.text = "Guide"
	_guide.focus_mode = Control.FOCUS_NONE
	_guide.pressed.connect(func() -> void: guide_pressed.emit())
	add_child(_guide)
	_hall = Button.new()
	_hall.text = "Hall of Fame"
	_hall.focus_mode = Control.FOCUS_NONE
	_hall.pressed.connect(func() -> void: hall_pressed.emit())
	add_child(_hall)
	_race = Button.new()
	_race.text = "Race a friend"
	_race.focus_mode = Control.FOCUS_NONE
	_race.add_theme_color_override("font_color", Hud.BONE)
	_race.add_theme_stylebox_override("normal", hud._box(Color("5a2414"), Hud.EMBER, 4, 8, 18))
	_race.add_theme_stylebox_override("hover", hud._box(Color("6e2c18"), Hud.EMBER, 4, 8, 18))
	_race.pressed.connect(func() -> void: race_pressed.emit())
	add_child(_race)
	_reset = Button.new()
	_reset.focus_mode = Control.FOCUS_NONE
	_reset.add_theme_color_override("font_color", Hud.DIM)
	_reset.pressed.connect(_on_reset)
	add_child(_reset)
	_sound = hud.sound_button(self, self)
	_info = Button.new()
	_info.text = "Info"
	_info.focus_mode = Control.FOCUS_NONE
	_info.pressed.connect(func() -> void:
		Sfx.play("click")
		_show_info())
	add_child(_info)
	# Unspent skill points: a gold badge on the Dark Arts button's corner.
	_points_badge = Label.new()
	_points_badge.add_theme_font_override("font", hud.bold_font)
	_points_badge.add_theme_font_size_override("font_size", 24)
	_points_badge.add_theme_color_override("font_color", Hud.NIGHT)
	_points_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_points_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_points_badge.custom_minimum_size = Vector2(38, 38)
	var pb := StyleBoxFlat.new()
	pb.bg_color = Hud.GOLD
	pb.set_corner_radius_all(19)
	pb.set_content_margin_all(4)
	pb.content_margin_left = 9
	pb.content_margin_right = 9
	pb.border_color = Hud.NIGHT
	pb.set_border_width_all(2)
	_points_badge.add_theme_stylebox_override("normal", pb)
	_points_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_points_badge.visible = false
	_skills.add_child(_points_badge)
	_row_size()
	_prev = _page_button("«", -1)
	_next = _page_button("»", 1)
	resized.connect(_layout)
	refresh()


func _page_button(text: String, step: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 60)
	b.add_theme_font_size_override("font_size", 26)
	b.tooltip_text = "Previous chapter" if step < 0 else "Next chapter"
	b.pressed.connect(func() -> void:
		Sfx.play("click")
		_show_page(_page + step))
	add_child(b)
	return b


func _pages() -> int:
	return maxi(1, ceili(_levels.size() / float(PER_PAGE)))


func _show_page(p: int) -> void:
	_page = clampi(p, 0, _pages() - 1)
	for m: Marker in _markers:
		m.visible = m.index / PER_PAGE == _page
	_prev.visible = _page > 0
	_next.visible = _page < _pages() - 1
	_prev.text = "« " + _chapter_name(_page - 1)
	_next.text = _chapter_name(_page + 1) + " »"
	_sub.text = "%s  ·  %d of %d lairs defended%s" % [CHAPTERS[mini(_page, CHAPTERS.size() - 1)], _beaten, _levels.size(), "  ·  Free demo" if Edition.demo else ""]
	_layout()


## Re-reads the save, e.g. after a battle ends.
func refresh() -> void:
	_beaten = 0
	for m: Marker in _markers:
		var id: String = _levels[m.index]["id"]
		m.locked = not _save.is_unlocked(m.index) or Edition.locked(m.index)
		m.stars = _save.stars(id)
		m.night = -1 if not _save.night_unlocked(id) else _save.stars(SaveData.mission_id(id, true))
		m.current = not m.locked and m.stars == 0
		m.queue_redraw()
		if m.stars > 0:
			_beaten += 1
	var free := _save.points_free()
	_skills.text = "Dark Arts · ★ %d" % _save.points_total()
	_points_badge.text = str(free)
	_points_badge.visible = free > 0
	_reset.text = "Reset progress"
	if _confirm:
		_confirm.visible = false
	if _offer:
		_offer.visible = false
	# Open on the chapter of the lair just played, so replaying old lairs for stars keeps you there;
	# at start, on the chapter of the newest lair the player may play.
	var newest := mini(_save.unlocked, Edition.DEMO_LAIRS if Edition.demo else _levels.size())
	var at := focus_lair + 1 if focus_lair >= 0 and focus_lair < newest else newest
	_show_page((mini(at, _levels.size()) - 1) / PER_PAGE)


func _layout() -> void:
	if _heading == null:
		return
	if _compact and size.x > _compact_w + 1.0:   # wider again: the bottom row goes back to full size
		_compact = false
		_row_size()
	_heading.reset_size()
	_heading.position = Vector2((size.x - _heading.size.x) / 2.0, size.y * 0.04)
	_sub.reset_size()
	_sub.position = Vector2((size.x - _sub.size.x) / 2.0, _heading.position.y + _heading.size.y)
	for m: Marker in _markers:
		m.size = Marker.SIZE
		m.position = _spot(m.index) - Vector2(Marker.SIZE.x / 2.0, m.cy())
		# Room for its name: half-way to the next lair on the same row each side, and the screen edge.
		var sx := _spot(m.index).x
		m.room = minf(Marker.SIZE.x, minf(size.x * (SPOTS[2].x - SPOTS[0].x) - 16.0, 2.0 * minf(sx, size.x - sx) - 8.0))
		m.queue_redraw()
	_reset.reset_size()
	_reset.position = size - _reset.size - Vector2(14, 12)
	_sound.reset_size()
	_sound.position = Vector2(_reset.position.x - _sound.size.x - 10, size.y - _sound.size.y - 12)
	_skills.reset_size()
	_skills.position = Vector2(14, size.y - _skills.size.y - 12)
	_points_badge.reset_size()
	_points_badge.position = Vector2(_skills.size.x - _points_badge.size.x * 0.65, -_points_badge.size.y * 0.45)
	_guide.reset_size()
	_guide.position = Vector2(_skills.position.x + _skills.size.x + 10, size.y - _guide.size.y - 12)
	_hall.reset_size()
	_hall.position = Vector2(_guide.position.x + _guide.size.x + 10, size.y - _hall.size.y - 12)
	_info.reset_size()
	_info.position = Vector2(_sound.position.x - _info.size.x - 10, size.y - _info.size.y - 12)
	_place_race()
	if _info_panel:
		_info_panel.size = size
	_prev.reset_size()
	_prev.position = Vector2(14, _heading.position.y + 8)
	_next.reset_size()
	_next.position = Vector2(size.x - _next.size.x - 14, _heading.position.y + 8)
	if _confirm:
		_confirm.size = size
	if _offer:
		_offer.size = size
	queue_redraw()


func _spot(i: int) -> Vector2:
	# Keep markers clear of the heading on short (landscape phone) screens.
	var top := 130.0
	var s := SPOTS[i % PER_PAGE]
	return Vector2(s.x * size.x, top + s.y * (size.y - top - 60.0))


## "Chapter II" for page 1, from CHAPTERS ("Chapter II: The Crusade").
func _chapter_name(p: int) -> String:
	var full: String = CHAPTERS[clampi(p, 0, CHAPTERS.size() - 1)] if p < CHAPTERS.size() else "Chapter %d" % (p + 1)
	return full.get_slice(":", 0)


## Where the road touches lair i: the bottom of a top-row circle, the top of a bottom-row one.
## Names, stars and moons sit on the far side of each row, so the road never crosses them.
func _foot(i: int) -> Vector2:
	if i % 2 == 0:
		return _spot(i) + Vector2(0, Marker.R + 6.0)
	return _spot(i) - Vector2(0, Marker.R + 6.0)


## Height where the road meets the screen's edges on its way to another chapter: midway
## between the two rows.
func _exit_y() -> float:
	return (_spot(0).y + _spot(1).y) / 2.0


## A point on lair i's circle edge, facing p.
func _rim(i: int, p: Vector2) -> Vector2:
	return _spot(i) + (p - _spot(i)).normalized() * (Marker.R + 6.0)


func _on_marker(i: int) -> void:
	Sfx.play("click")
	if Edition.locked(i):
		offer_full_game()
	elif _save.is_unlocked(i):
		level_chosen.emit(i)
	else:
		_hud.toast("Defend the previous lair first")


## Asks first, in a dialog, so a stray touch can't wipe the campaign.
func _on_reset() -> void:
	if _confirm == null:
		_build_confirm()
	_confirm.size = size
	_confirm.visible = true


func _build_confirm() -> void:
	_confirm = Control.new()
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_confirm)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _hud._box(Hud.PANEL, Hud.POOR, 2, 12, 24))
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	card.add_child(box)
	var h := Label.new()
	h.text = "Erase all progress?"
	h.add_theme_font_override("font", _hud.display_font)
	h.add_theme_font_size_override("font_size", 44)
	h.add_theme_color_override("font_color", Hud.GOLD)
	box.add_child(h)
	var t := Label.new()
	t.text = "Every lair, star and skill point will be lost,
and the tips will show again. This can't be undone.
Achievements and best scores are kept."
	t.add_theme_font_size_override("font_size", 26)
	box.add_child(t)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var erase := Button.new()
	erase.text = "Erase everything"
	erase.focus_mode = Control.FOCUS_NONE
	erase.custom_minimum_size = Vector2(0, 60)
	erase.add_theme_font_size_override("font_size", 26)
	erase.add_theme_stylebox_override("normal", _hud._box(Color("3a1712"), Color("8a2e22"), 2, 8, 20))
	erase.add_theme_stylebox_override("hover", _hud._box(Color("4a1d16"), Color("b23a2a"), 2, 8, 20))
	erase.add_theme_color_override("font_color", Hud.POOR)
	erase.add_theme_color_override("font_hover_color", Hud.POOR)
	erase.pressed.connect(_erase)
	row.add_child(erase)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.custom_minimum_size = Vector2(160, 60)
	cancel.add_theme_font_size_override("font_size", 26)
	cancel.pressed.connect(func() -> void: _confirm.visible = false)
	row.add_child(cancel)
	_confirm.visible = false


## Demo builds: shown on a locked lair and after the last free one.
func offer_full_game() -> void:
	if _offer == null:
		_build_offer()
	_offer.size = size
	_offer.visible = true


func _build_offer() -> void:
	var store := Edition.store()
	var url: String = store["url"]
	_offer = Control.new()
	_offer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_offer)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_offer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_offer.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _hud._box(Hud.PANEL, Hud.GOLD, 2, 12, 24))
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	card.add_child(box)
	var h := Label.new()
	h.text = "The hoard goes deeper"
	h.add_theme_font_override("font", _hud.display_font)
	h.add_theme_font_size_override("font_size", 44)
	h.add_theme_color_override("font_color", Hud.GOLD)
	box.add_child(h)
	var t := Label.new()
	var more := _levels.size() - Edition.DEMO_LAIRS
	t.text = "This free demo has the first %d lairs.\n%d more wait in the full game%s" % [Edition.DEMO_LAIRS, more,
		" on %s." % store["name"] if url != "" else ", coming soon to %s." % store["name"]]
	t.text += "\nHave a full-game code? Enter it under Info."
	t.add_theme_font_size_override("font_size", 26)
	box.add_child(t)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	if url != "":
		var get_it := Button.new()
		get_it.text = "Get the full game"
		get_it.focus_mode = Control.FOCUS_NONE
		get_it.custom_minimum_size = Vector2(0, 60)
		get_it.add_theme_font_size_override("font_size", 26)
		get_it.pressed.connect(func() -> void: OS.shell_open(url))
		row.add_child(get_it)
	var back := Button.new()
	back.text = "Later" if url != "" else "OK"
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(160, 60)
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(func() -> void: _offer.visible = false)
	row.add_child(back)
	_offer.visible = false


## Version, how to reach us and, on demo builds, the box for a full-game code. Rebuilt on every
## opening so it always shows whether the game is unlocked.
func _show_info() -> void:
	if _info_panel:
		_info_panel.queue_free()
	_info_panel = Control.new()
	_info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_info_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_info_panel)
	var box := Screens.page(_info_panel, _hud, "Info", "Back to map", func() -> void: _info_panel.visible = false)
	var about := Label.new()
	about.text = "Gemhold, version %s%s" % [ProjectSettings.get_setting("application/config/version", ""),
		("  ·  free demo" if Edition.demo else "  ·  full game") if Edition.demo_build else ""]
	about.add_theme_font_size_override("font_size", 28)
	box.add_child(about)
	if Edition.demo_build and Edition.demo:
		var code_row := HBoxContainer.new()
		code_row.add_theme_constant_override("separation", 10)
		box.add_child(code_row)
		var code := LineEdit.new()
		code.placeholder_text = "Full-game code"
		code.custom_minimum_size = Vector2(340, 60)
		code.add_theme_font_size_override("font_size", 26)
		code_row.add_child(code)
		var status := Label.new()
		status.add_theme_font_size_override("font_size", 24)
		var go := Button.new()
		go.text = "Unlock"
		go.focus_mode = Control.FOCUS_NONE
		go.custom_minimum_size = Vector2(0, 60)
		go.add_theme_font_size_override("font_size", 26)
		var try := func() -> void:
			if Edition.try_code(code.text):
				Sfx.play("rank")
				status.add_theme_color_override("font_color", Hud.GOLD)
				status.text = "The full game is unlocked: all %d lairs are yours.\nSigned in? Your account now unlocks it on your other devices too." % _levels.size()
				code_row.visible = false
				refresh()
				full_unlocked.emit()
			else:
				Sfx.play("error")
				status.add_theme_color_override("font_color", Hud.POOR)
				status.text = "That code doesn't work. Check it and try again."
		go.pressed.connect(try)
		code.text_submitted.connect(func(_t: String) -> void: try.call())
		code_row.add_child(go)
		box.add_child(status)
	_feedback(box)


## Feedback: where to write, the address copied with a tap (phones rarely have a mail app set up),
## and a button that opens the mail app when there is one.
func _feedback(box: VBoxContainer) -> void:
	var h := Label.new()
	h.text = "Feedback"
	h.add_theme_font_override("font", _hud.display_font)
	h.add_theme_font_size_override("font_size", 36)
	h.add_theme_color_override("font_color", Hud.GOLD)
	box.add_child(h)
	var text := Label.new()
	text.text = "Found a bug, have an idea, or does a lair feel unfair? Write it here and tap Send. We read every message."
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 26)
	box.add_child(text)
	# Written right here and sent straight to us (Online.send_feedback); needs an internet connection.
	var msg := TextEdit.new()
	msg.placeholder_text = "Your message…"
	msg.custom_minimum_size = Vector2(0, 200)
	msg.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	msg.add_theme_font_size_override("font_size", 26)
	msg.add_theme_stylebox_override("normal", _hud._box(Color("1d1712"), Hud.EDGE, 2, 6, 12))
	msg.add_theme_stylebox_override("focus", _hud._box(Color("1d1712"), Hud.GOLD, 2, 6, 12))
	box.add_child(msg)
	var send_row := HBoxContainer.new()
	send_row.add_theme_constant_override("separation", 14)
	box.add_child(send_row)
	var send := Button.new()
	send.text = "Send"
	send.focus_mode = Control.FOCUS_NONE
	send.custom_minimum_size = Vector2(160, 64)
	send.add_theme_font_size_override("font_size", 28)
	send.add_theme_stylebox_override("normal", _hud._box(Color("3d2a12"), Color("8a6420"), 4, 8, 18))
	send_row.add_child(send)
	var sent := Label.new()
	sent.add_theme_font_size_override("font_size", 24)
	sent.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	send_row.add_child(sent)
	send.pressed.connect(func() -> void:
		if online == null:
			return
		send.disabled = true
		sent.remove_theme_color_override("font_color")
		sent.text = "Sending…"
		var err: String = await online.send_feedback(msg.text)
		if not is_instance_valid(sent):
			return
		send.disabled = false
		if err == "":
			Sfx.play("coin")
			msg.text = ""
			sent.add_theme_color_override("font_color", Hud.GOLD)
			sent.text = "Sent. Thank you!"
		else:
			Sfx.play("error")
			sent.add_theme_color_override("font_color", Hud.POOR)
			sent.text = err)
	var or_mail := Label.new()
	or_mail.text = "Or write to us by email. Tap the address to copy it."
	or_mail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	or_mail.add_theme_font_size_override("font_size", 24)
	or_mail.add_theme_color_override("font_color", Hud.DIM)
	box.add_child(or_mail)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var copy := Button.new()
	copy.text = CONTACT
	copy.focus_mode = Control.FOCUS_NONE
	copy.custom_minimum_size = Vector2(0, 64)
	copy.add_theme_font_size_override("font_size", 28)
	row.add_child(copy)
	var mail := Button.new()
	mail.text = "Open mail app"
	mail.focus_mode = Control.FOCUS_NONE
	mail.custom_minimum_size = Vector2(0, 64)
	mail.add_theme_font_size_override("font_size", 26)
	mail.pressed.connect(func() -> void: OS.shell_open("mailto:" + CONTACT))
	row.add_child(mail)
	var done := Label.new()
	done.add_theme_font_size_override("font_size", 24)
	done.add_theme_color_override("font_color", Hud.GOLD)
	box.add_child(done)
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(CONTACT)
		Sfx.play("coin")
		done.text = "Copied: paste it into your mail.")


func _erase() -> void:
	_confirm.visible = false
	_save.reset()
	Prefs.set_value("tutorial_done", false)
	Prefs.set_value("arts_tip", 0)
	Prefs.set_value("arts_intro", false)
	for gate: int in load("res://scripts/main.gd").TIER_TIPS:
		Prefs.set_value("tier_tip_%d" % gate, false)
	for k in Defs.SITES:
		Prefs.set_value("building_tip_" + k, false)
	for k in Defs.ENEMIES:
		Prefs.set_value("hero_tip_" + k, false)
	for k in load("res://scripts/main.gd").RULE_TIPS:
		Prefs.set_value("rule_tip_" + k, false)
	_save.save()
	refresh()
	_hud.toast("Progress erased")


func _draw() -> void:
	_draw_parchment()
	# The trail between stops: bright where it has been walked, dim and dotted beyond.
	var first := _page * PER_PAGE
	for i in range(first, first + PER_PAGE - 1):
		var a := _foot(i)
		var b := _foot(i + 1)
		var bend := (b - a).orthogonal().normalized() * (30.0 if i % 2 == 0 else -30.0)
		_trail(a, (a + b) / 2.0 + bend, b, i + 1 < _levels.size() and _save.is_unlocked(i + 1))
	# The road in from the previous chapter (left edge) and on to the next (right edge), meeting
	# the edges midway between the rows.
	if _page > 0:
		var a := Vector2(0, _exit_y())
		var c := Vector2(_spot(first).x * 0.5, a.y)
		_trail(a, c, _rim(first, c), _save.is_unlocked(first))
	if _page < _pages() - 1:
		var last := first + PER_PAGE - 1
		var b := Vector2(size.x, _exit_y())
		var c := Vector2((_spot(last).x + b.x) / 2.0, b.y)
		_trail(_rim(last, c), c, b, first + PER_PAGE < _levels.size() and _save.is_unlocked(first + PER_PAGE))
	# Planned stops with no level yet.
	for i in range(maxi(first, _levels.size()), first + PER_PAGE):
		var c := _spot(i)
		Paint.ellipse(self, c, Marker.R * 0.8, Marker.R * 0.8, Color(0, 0, 0, 0.35))
		Paint.ellipse_outline(self, c, Marker.R * 0.8, Marker.R * 0.8, Color(Hud.DIM, 0.25), 2.0)
		draw_string(_hud.bold_font, c + Vector2(-40, -Marker.R - 12 if i % 2 == 0 else Marker.R + 26), "Uncharted", HORIZONTAL_ALIGNMENT_CENTER, 80, 19, Color(Hud.DIM, 0.4))


## One stretch of trail from a to b bending through c: bright where it has been walked, dim and dotted beyond.
func _trail(a: Vector2, c: Vector2, b: Vector2, walked: bool) -> void:
	var pts := PackedVector2Array([a])
	pts.append_array(Paint.quad(a, c, b, 24))
	var col: Color = Color(Hud.GOLD, 0.75) if walked else Color(Hud.DIM, 0.3)
	for j in range(1, pts.size() - 1):
		if walked or j % 2 == 0:
			draw_circle(pts[j], 3.0 if walked else 2.5, col)


## One tappable lair on the map.
class Marker extends Control:
	signal pressed(index: int)

	const R := 34.0
	const SIZE := Vector2(240, 166)

	var index := 0
	var title := ""
	var locked := true
	var current := false
	var stars := 0
	var night := -1       # -1 locked, 0 open but unbeaten, 1-3 night rating
	var font: Font
	var number_font: Font
	var above := false    # top row: name, stars and moon above the circle, so the road below stays clear
	var room := 240.0     # widest its name may be (set by the map's layout so neighbours never touch)
	var _t := 0.0

	## Circle centre in local coordinates.
	func cy() -> float:
		return SIZE.y - R - 2.0 if above else R

	## Top of the name/stars/moon block.
	func _base() -> float:
		return 0.0 if above else R * 2.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _process(delta: float) -> void:
		if current:
			_t += delta
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var on_text: bool = event.position.y < cy() - R if above else event.position.y > R * 2.0
			if event.position.distance_to(Vector2(size.x / 2.0, cy())) <= R + 14.0 or on_text:
				pressed.emit(index)
				accept_event()

	func _draw() -> void:
		var c := Vector2(size.x / 2.0, cy())
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
		var fit := _fit_title()
		var lines: Array = fit[0]
		var fs: int = fit[1]
		# A second line goes above the first on the top row (the circle is below) and pushes the
		# stars and moon down on the bottom row.
		var extra := 0.0 if lines.size() == 1 or above else float(fs)
		if not locked:
			_draw_moon(Vector2(size.x / 2.0 - 36.0, _base() + 72 + extra))
		var tc := Color("efe4cc") if not locked else Color("a8977c", 0.6)
		for j in lines.size():
			var ty := _base() + 24 + (j - (lines.size() - 1 if above else 0)) * fs
			draw_string(font, Vector2(0, ty), lines[j], HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, tc)
		# Best rating as three stars: gold ones earned, dark ones still to win.
		for k in 3:
			var p := Vector2(size.x / 2.0 + (k - 1) * 22.0, _base() + 44 + extra)
			if locked:
				pass   # a result from before the lair moved later in the campaign shows once it opens
			elif k < stars:
				_draw_star(p, 10.0, Color("e8b84a"))
			elif not locked:
				_draw_star(p, 10.0, Color(0, 0, 0, 0.45))

	## The name in at most two lines that fit `room`: one line if it fits at 20–25, else split at
	## the space nearest the middle, shrinking the font (down to 18) only if a line is still too wide.
	## Returns [lines, font size].
	func _fit_title() -> Array:
		var fs := 25
		var wide := func(t: String, s: int) -> float: return font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
		for s in range(25, 19, -1):   # one line, a little smaller if need be
			if wide.call(title, s) <= room:
				return [[title], s]
		var lines: Array = [title]
		var best := -1
		for i in title.length():
			if title[i] == " " and (best < 0 or absi(i - title.length() / 2) < absi(best - title.length() / 2)):
				best = i
		if best > 0:
			lines = [title.substr(0, best), title.substr(best + 1)]
		while fs > 18 and lines.any(func(l: String) -> bool: return wide.call(l, fs) > room):
			fs -= 1
		return [lines, fs]

	## Night mission badge: a faint crescent until unlocked, pale and glowing when open,
	## gold once won, with its own three-star rating beside it, on a row under the day stars.
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
		# Night rating: three stars beside the moon, moonlit when earned, dark until then.
		if night >= 0:
			for k in 3:
				var p := m + Vector2(26 + k * 22, 1)
				if k < night:
					Paint.glow(self, p, 20.0, Color(0.62, 0.7, 1, 0.8))
					_draw_star(p, 10.0, Color("bcc9ff"))
				else:
					_draw_star(p, 10.0, Color(0, 0, 0, 0.55))
					_draw_star_outline(p, 10.0, Color(0.62, 0.7, 1, 0.8))

	func _draw_star_outline(c: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 11:
			var a := -PI / 2.0 + i * PI / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
		draw_polyline(pts, col, 1.2, true)

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


# ---------------------------------------------------------------- the old map

const INK := Color(0.86, 0.72, 0.5)


## An old map drawn on dark, stained parchment: faint lines of latitude, a burnt edge, and ink
## sketches of the chapter's country (lowland hills, woods and a river; the crusade's castles,
## camps and mountains), kept clear of the lair markers.
func _draw_parchment() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("211810"))
	for k in 40:   # stains, lighter and darker
		var p := Vector2(Paint.hash01(k, 1, _page) * size.x, Paint.hash01(k, 2, _page) * size.y)
		var r := 50.0 + Paint.hash01(k, 3, _page) * 140.0
		Paint.glow(self, p, r, Color("4a3a24", 0.3) if k % 3 else Color(0, 0, 0, 0.25))
	for i in range(1, 6):   # lines of latitude, dashed
		var y := size.y * i / 6.0 + sin(i * 1.7) * 12.0
		for x in range(0, int(size.x), 28):
			draw_line(Vector2(x, y), Vector2(x + 14, y + sin((x + i * 50) * 0.004) * 6.0), Color(INK, 0.05), 1.5)
	var first := _page * PER_PAGE
	var spots: Array[Vector2] = []
	for i in range(first, first + PER_PAGE):
		spots.append(_spot(i))
	if _page == 0:
		_river(spots)
	for k in 70:
		var p := Vector2(Paint.hash01(k, 11, _page) * size.x, (0.12 + Paint.hash01(k, 12, _page) * 0.8) * size.y)
		# Keep clear of the markers with their names and stars, the heading and the button rows.
		var blocked := false
		for j in spots.size():
			var dy := p.y - spots[j].y   # top-row names sit above the marker, bottom-row names below
			if absf(spots[j].x - p.x) < 150.0 and (dy > -135.0 and dy < 60.0 if j % 2 == 0 else dy > -60.0 and dy < 120.0):
				blocked = true
		if blocked:
			continue
		if p.y < 150.0 and absf(p.x - size.x * 0.5) < size.x * 0.25 or p.y > size.y - 100.0:
			continue
		var r := 14.0 + Paint.hash01(k, 13, _page) * 14.0
		var kind := int(Paint.hash01(k, 14, _page) * 4.0)
		var col := Color(INK, 0.16 + Paint.hash01(k, 15, _page) * 0.08)
		if _page == 2:   # the Drowned Marches: pools and reed beds
			match kind:
				0, 1: _pool(p, r, col)
				_: _reed(p, r, col)
		elif _page == 3:   # the Siegeworks: walls, palisades and engines
			match kind:
				0: _castle(p, r, col)
				1, 2: _palisade(p, r, col)
				_: _engine(p, r, col)
		elif _page == 4:   # the Radiant Host: chapel spires, suns and wings
			match kind:
				0: _spire(p, r, col)
				1: _sun(p, r, col)
				2: _wing(p, r, col)
				_: _field(p, r, col)
		elif _page % 2 == 0:
			match kind:
				0, 1: _hill(p, r, col)
				2: _wood(p, r, col)
				_: _field(p, r, col)
		else:
			match kind:
				0: _castle(p, r, col)
				1: _tent(p, r, col)
				_: _mountain(p, r, col)
	for i in 14:   # a burnt, darkened edge
		var a := 0.07 * (1.0 - i / 14.0)
		var w := i * 6.0
		draw_rect(Rect2(w, w, size.x - 2.0 * w, size.y - 2.0 * w), Color(0, 0, 0, a), false, 6.0)


func _pool(p: Vector2, r: float, col: Color) -> void:
	for k in 3:
		draw_arc(p + Vector2(0, k * r * 0.25), r * (1.0 - k * 0.25), PI * 0.1, PI * 0.9, 12, col, 1.5, true)
	draw_line(p + Vector2(-r * 0.8, r * 0.1), p + Vector2(-r * 0.4, r * 0.1), col, 1.5)


func _spire(p: Vector2, r: float, col: Color) -> void:
	draw_rect(Rect2(p + Vector2(-r * 0.25, -r * 0.2), Vector2(r * 0.5, r * 0.7)), col, false, 1.5)
	draw_line(p + Vector2(-r * 0.3, -r * 0.2), p + Vector2(0, -r * 0.9), col, 1.5)
	draw_line(p + Vector2(r * 0.3, -r * 0.2), p + Vector2(0, -r * 0.9), col, 1.5)
	draw_line(p + Vector2(0, -r * 0.9), p + Vector2(0, -r * 1.2), col, 1.5)
	draw_line(p + Vector2(-r * 0.12, -r * 1.08), p + Vector2(r * 0.12, -r * 1.08), col, 1.5)


func _sun(p: Vector2, r: float, col: Color) -> void:
	draw_arc(p, r * 0.35, 0, TAU, 14, col, 1.5, true)
	for k in 8:
		var a := k * TAU / 8.0
		draw_line(p + Vector2(cos(a), sin(a)) * r * 0.5, p + Vector2(cos(a), sin(a)) * r * 0.8, col, 1.5)


func _wing(p: Vector2, r: float, col: Color) -> void:
	for k in 3:
		draw_arc(p + Vector2(k * r * 0.15, k * r * 0.12), r * (0.9 - k * 0.2), PI * 1.05, PI * 1.6, 10, col, 1.5, true)


func _palisade(p: Vector2, r: float, col: Color) -> void:
	for j in 5:
		var x := p.x + (j - 2) * r * 0.32
		draw_line(Vector2(x, p.y + r * 0.5), Vector2(x, p.y - r * 0.4), col, 2.0)
		draw_line(Vector2(x, p.y - r * 0.4), Vector2(x + r * 0.08, p.y - r * 0.6), col, 1.5)
	draw_line(p + Vector2(-r * 0.75, r * 0.1), p + Vector2(r * 0.75, r * 0.1), col, 1.5)


func _engine(p: Vector2, r: float, col: Color) -> void:
	draw_line(p + Vector2(-r * 0.8, r * 0.5), p + Vector2(r * 0.8, r * 0.5), col, 2.0)
	draw_line(p + Vector2(-r * 0.5, r * 0.5), p + Vector2(0, -r * 0.3), col, 1.5)
	draw_line(p + Vector2(r * 0.5, r * 0.5), p + Vector2(0, -r * 0.3), col, 1.5)
	draw_line(p + Vector2(-r * 0.4, r * 0.1), p + Vector2(r * 0.9, -r * 0.9), col, 2.0)
	draw_arc(p + Vector2(-r * 0.5, r * 0.55), r * 0.18, 0, TAU, 8, col, 1.5)
	draw_arc(p + Vector2(r * 0.5, r * 0.55), r * 0.18, 0, TAU, 8, col, 1.5)


func _reed(p: Vector2, r: float, col: Color) -> void:
	for j in 4:
		var x := p.x + (j - 1.5) * r * 0.35
		draw_line(Vector2(x, p.y + r * 0.5), Vector2(x + (j - 1.5) * 2.0, p.y - r * 0.7), col, 1.5, true)
	draw_line(p + Vector2(-r * 0.9, r * 0.5), p + Vector2(r * 0.9, r * 0.5), col, 1.5)


func _hill(p: Vector2, r: float, col: Color) -> void:
	draw_arc(p, r, PI * 1.1, PI * 1.9, 12, col, 2.0, true)
	draw_arc(p + Vector2(r * 0.9, r * 0.25), r * 0.7, PI * 1.1, PI * 1.9, 10, col, 2.0, true)


func _wood(p: Vector2, r: float, col: Color) -> void:
	for j in 3:
		var q := p + Vector2((j - 1) * r * 0.7, (j % 2) * r * 0.3)
		draw_circle(q - Vector2(0, r * 0.4), r * 0.35, col)
		draw_line(q - Vector2(0, r * 0.1), q + Vector2(0, r * 0.35), col, 2.0)


func _field(p: Vector2, r: float, col: Color) -> void:
	for j in 4:
		var x := p.x - r + j * r * 0.6
		draw_line(Vector2(x, p.y - r * 0.4), Vector2(x + r * 0.5, p.y + r * 0.4), col, 1.5)


func _castle(p: Vector2, r: float, col: Color) -> void:
	draw_rect(Rect2(p - Vector2(r * 0.7, r * 0.6), Vector2(r * 1.4, r * 1.0)), col, false, 2.0)
	for j in 3:
		draw_rect(Rect2(p + Vector2(-r * 0.7 + j * r * 0.55, -r * 0.85), Vector2(r * 0.3, r * 0.25)), col)
	draw_line(p + Vector2(0, -r * 0.85), p + Vector2(0, -r * 1.4), col, 1.5)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r * 1.4), p + Vector2(r * 0.4, -r * 1.28), p + Vector2(0, -r * 1.16)]), col)


func _tent(p: Vector2, r: float, col: Color) -> void:
	draw_polyline(PackedVector2Array([p + Vector2(-r * 0.7, r * 0.4), p + Vector2(0, -r * 0.6), p + Vector2(r * 0.7, r * 0.4), p + Vector2(-r * 0.7, r * 0.4)]), col, 2.0, true)
	draw_line(p + Vector2(0, -r * 0.6), p + Vector2(0, r * 0.4), col, 1.5)


func _mountain(p: Vector2, r: float, col: Color) -> void:
	draw_polyline(PackedVector2Array([p + Vector2(-r * 1.2, r * 0.5), p + Vector2(-r * 0.3, -r * 0.7), p + Vector2(r * 0.2, -r * 0.1), p + Vector2(r * 0.6, -r * 0.5), p + Vector2(r * 1.2, r * 0.5)]), col, 2.0, true)
	draw_line(p + Vector2(-r * 0.3, -r * 0.7), p + Vector2(-r * 0.1, -r * 0.2), col, 1.5)


## Chapter I's river: a wavy double line across the map, passing between the rows of lairs.
func _river(_spots: Array[Vector2]) -> void:
	var pts := PackedVector2Array()
	for k in 41:
		var x := size.x * k / 40.0
		pts.append(Vector2(x, size.y * (0.5 + 0.06 * sin(k * 0.45)) + 18.0 * sin(k * 1.3)))
	draw_polyline(pts, Color(INK, 0.14), 3.0, true)
	var pts2 := PackedVector2Array()
	for q in pts:
		pts2.append(q + Vector2(0, 10))
	draw_polyline(pts2, Color(INK, 0.08), 2.0, true)


## Challenges waiting for this player (Hall of Fame, Race page): the Race button says so, and
## glows when an agreed race is due now.
func set_race_badge(attention: int, live: bool) -> void:
	if live:
		_race_texts = ["Your race is now!", "Race now!"]
	elif attention > 0:
		_race_texts = ["Race a friend · %d" % attention, "Race · %d" % attention]
	else:
		_race_texts = ["Race a friend", "Race"]
	_race.add_theme_color_override("font_color", Hud.GOLD if attention > 0 else Hud.BONE)
	_layout()


## The Race button goes after Hall of Fame on the bottom row, with its short label if the full one
## would run into Info; if even that does not fit, the bottom-left buttons get a smaller face, and only
## if that is not enough either does it sit above Hall of Fame.
func _place_race() -> void:
	var room := _info.position.x - 10.0
	for t: String in _race_texts:
		_race.text = t
		_race.reset_size()
		_race.position = Vector2(_hall.position.x + _hall.size.x + 10, size.y - _race.size.y - 12)
		if _race.position.x + _race.size.x <= room:
			return
	# Still no room: the left-hand buttons in a smaller face, then the row laid out again.
	if not _compact:
		_compact = true
		_compact_w = size.x
		_row_size()
		_layout()
		return
	# Even then: above Hall of Fame, with its full label.
	_race.text = _race_texts[0]
	_race.reset_size()
	_race.position = Vector2(_hall.position.x, _hall.position.y - _race.size.y - 10)


## Every button of the bottom row the same size: ROW_FONT text, ROW_H tall (smaller when _compact).
const ROW_FONT := 28
const ROW_H := 64


func _row_size() -> void:
	for b: Button in [_skills, _guide, _hall, _race, _info, _sound, _reset]:
		b.add_theme_font_size_override("font_size", 23 if _compact else ROW_FONT)
		b.custom_minimum_size.y = 56 if _compact else ROW_H
