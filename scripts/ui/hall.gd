extends Control
## The Hall of Fame, opened from the level map: the online leaderboard, the achievements and the
## optional account (see Online). Builds its own nodes in code, like the HUD.

signal closed

const Hud := preload("res://scripts/ui/hud.gd")

var _hud: Control
var _save: SaveData
var _online: Online
var _levels: Array = []          # [{"id", "title", "waves"}], campaign order
var _boards: Array = []          # [{"label", "field"}]: the overall total, then each mission
var _board := 0
var _ask := 0                    # bumps with every leaderboard request, so a late answer is dropped
var _tabs: Array[Button] = []
var _pages: Array[Control] = []
var _board_label: Label
var _board_note: Label
var _rows: VBoxContainer
var _ach_count: Label
var _ach_grid: GridContainer
var _account: VBoxContainer
var _status: Label
var _fields := {}                # LineEdits on the account page, by name
var _delete_armed := false
var _del_button: Button


func setup(hud: Control, save: SaveData, online: Online, levels: Array) -> void:
	_hud = hud
	_save = save
	_online = online
	_levels = levels
	_boards = [{"label": "All lairs: total score", "field": "total"}]
	for i in levels.size():
		var id: String = levels[i]["id"]
		_boards.append({"label": "Lair %d: %s" % [i + 1, levels[i]["title"]], "field": "scores." + Online.score_key(id)})
		_boards.append({"label": "Lair %d: %s · Night" % [i + 1, levels[i]["title"]], "field": "scores." + Online.score_key(SaveData.mission_id(id, true))})
	theme = hud.theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var bg := ColorRect.new()
	bg.color = Hud.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	var title := Label.new()
	title.text = "Hall of Fame"
	title.add_theme_font_override("font", hud.display_font)
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Hud.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	for t in ["Leaderboard", "Achievements", "Account"]:
		var b := _big_button(head, t)
		b.pressed.connect(_show_tab.bind(_tabs.size()))
		_tabs.append(b)
	var back := _big_button(head, "Back to map")
	back.pressed.connect(func() -> void: closed.emit())

	var page_box := PanelContainer.new()
	page_box.add_theme_stylebox_override("panel", hud._box(Hud.PANEL, Hud.EDGE, 1, 14, 22))
	page_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(page_box)
	_pages = [_build_board(), _build_achievements(), _build_account()]
	for p in _pages:
		page_box.add_child(p)
	_online.changed.connect(_refresh_account)


func _big_button(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", 28)
	parent.add_child(b)
	return b


func _label(parent: Control, text: String, size: int, color := Hud.BONE, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


## Opens on the leaderboard; the very first time, on the account page instead (Prefs "hall_seen").
func open() -> void:
	visible = true
	_refresh_account()
	_refresh_achievements()
	_show_tab(0 if Prefs.get_value("hall_seen", false) or _online.signed_in() else 2)
	Prefs.set_value("hall_seen", true)


func _show_tab(i: int) -> void:
	Sfx.play("click")
	for k in _pages.size():
		_pages[k].visible = k == i
		if k == i:
			_tabs[k].add_theme_stylebox_override("normal", _hud._box(Color("5a2414"), Hud.EMBER, 4, 8, 14))
			_tabs[k].add_theme_stylebox_override("hover", _hud._box(Color("6e2c18"), Hud.EMBER, 4, 8, 14))
		else:
			_tabs[k].remove_theme_stylebox_override("normal")
			_tabs[k].remove_theme_stylebox_override("hover")
	if i == 0:
		_load_board()


# ---------------------------------------------------------------- leaderboard

func _build_board() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	page.add_child(row)
	var prev := _big_button(row, "«")
	prev.custom_minimum_size.x = 72
	prev.pressed.connect(_step_board.bind(-1))
	_board_label = _label(row, "", 30, Hud.GOLD, _hud.bold_font)
	_board_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var next := _big_button(row, "»")
	next.custom_minimum_size.x = 72
	next.pressed.connect(_step_board.bind(1))
	var again := _big_button(row, "Refresh")
	again.pressed.connect(_load_board)
	_board_note = _label(page, "", 24, Hud.DIM)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	return page


func _step_board(step: int) -> void:
	Sfx.play("click")
	_board = posmod(_board + step, _boards.size())
	_load_board()


func _load_board() -> void:
	var b: Dictionary = _boards[_board]
	_board_label.text = b["label"]
	_clear(_rows)
	var mine := _save.total_score() if _board == 0 else int(_save.scores.get(_mission(_board), 0))
	var note := "Your best: %s" % Hud._thousands(mine) if mine > 0 else "No score of yours here yet."
	if not _online.signed_in():
		note += "  Sign in (Account) to put your name on the board."
	_board_note.text = note
	_label(_rows, "Loading…", 26, Hud.DIM)
	_ask += 1
	var ask := _ask
	var res: Variant = await _online.top(b["field"])
	if ask != _ask or not is_inside_tree():
		return
	_clear(_rows)
	if typeof(res) == TYPE_DICTIONARY:
		_label(_rows, res["error"], 26, Hud.POOR)
		return
	if (res as Array).is_empty():
		_label(_rows, "Nobody has a score here yet. Be the first!", 26, Hud.DIM)
		return
	for i in res.size():
		_add_row(i + 1, res[i])


## Mission id of leaderboard number n (1 and up: each lair's day, then night).
func _mission(n: int) -> String:
	var id: String = _levels[(n - 1) / 2]["id"]
	return SaveData.mission_id(id, (n - 1) % 2 == 1)


func _add_row(place: int, r: Dictionary) -> void:
	var me: bool = _online.signed_in() and r["uid"] == _online.uid
	var panel := PanelContainer.new()
	var bg := Color("3d2a12") if me else (Hud.PANEL_2 if place % 2 == 1 else Color(0, 0, 0, 0))
	panel.add_theme_stylebox_override("panel", _hud._box(bg, Hud.GOLD if me else Color(0, 0, 0, 0), 1, 8, 12))
	_rows.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var medal: Color = [Hud.GOLD, Color("cfd6e0"), Color("d08a4a")][place - 1] if place <= 3 else Hud.DIM
	var p := _label(row, str(place), 30, medal, _hud.display_font)
	p.custom_minimum_size.x = 56
	p.autowrap_mode = TextServer.AUTOWRAP_OFF
	var n := _label(row, r["name"], 28, Hud.GOLD if me else Hud.BONE, _hud.bold_font)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	n.clip_text = true
	var extra := _label(row, "★ %d  ·  %d/%d badges" % [r["stars"], r["ach"], Achievements.LIST.size()], 22, Hud.DIM)
	extra.autowrap_mode = TextServer.AUTOWRAP_OFF
	extra.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var v := _label(row, Hud._thousands(r["value"]), 30, Hud.GOLD, _hud.bold_font)
	v.custom_minimum_size.x = 150
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.autowrap_mode = TextServer.AUTOWRAP_OFF


# ---------------------------------------------------------------- achievements

func _build_achievements() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	_ach_count = _label(page, "", 28, Hud.GOLD, _hud.bold_font)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	_ach_grid = GridContainer.new()
	_ach_grid.columns = 2
	_ach_grid.add_theme_constant_override("h_separation", 12)
	_ach_grid.add_theme_constant_override("v_separation", 12)
	_ach_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_ach_grid)
	return page


func _refresh_achievements() -> void:
	_clear(_ach_grid)
	_ach_count.text = "%d of %d earned  ·  %s heroes slain in all" % [_save.achievements.size(), Achievements.LIST.size(), Hud._thousands(int(_save.stats.get("kills", 0)))]
	for a: Dictionary in Achievements.LIST:
		var got := _save.has_achievement(a["id"])
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _hud._box(Color("3d2a12") if got else Color(0, 0, 0, 0.3), Hud.GOLD if got else Color("3a2e22"), 3 if got else 1, 10, 16))
		_ach_grid.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)
		var icon := _label(row, "★" if got else "☆", 40, Hud.GOLD if got else Color(Hud.DIM, 0.4))
		icon.autowrap_mode = TextServer.AUTOWRAP_OFF
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		_label(col, a["name"], 28, Hud.GOLD if got else Hud.BONE, _hud.bold_font)
		_label(col, a["text"], 23, Hud.BONE if got else Hud.DIM)
		if got:
			var when := Time.get_date_string_from_unix_time(int(_save.achievements[a["id"]]))
			_label(col, "Earned " + when, 19, Hud.DIM)


# ---------------------------------------------------------------- account

func _build_account() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_account = VBoxContainer.new()
	_account.add_theme_constant_override("separation", 12)
	_account.custom_minimum_size = Vector2(680, 0)
	center.add_child(_account)
	return scroll


func _refresh_account() -> void:
	if _account == null:
		return
	_clear(_account)
	_fields.clear()
	_delete_armed = false
	if _online.signed_in():
		_label(_account, "Signed in as %s" % _online.player_name, 36, Hud.GOLD, _hud.display_font)
		_label(_account, "%s\nTotal score %s  ·  ★ %d  ·  %d achievements. Your best results and achievements are saved to this account, so they follow you to any device you sign in on." % [_online.email, Hud._thousands(_save.total_score()), _save.points_total(), _save.achievements.size()], 24, Hud.DIM)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_account.add_child(row)
		var n := _field(row, "name", "Leaderboard name", false)
		n.text = _online.player_name
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_action(row, "Rename", _rename)
		_status = _label(_account, "", 24, Hud.DIM)
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 10)
		_account.add_child(row2)
		_action(row2, "Sign out", func() -> void:
			_online.sign_out())
		_del_button = _action(row2, "Delete account", _delete)
		_del_button.add_theme_color_override("font_color", Hud.POOR)
		return
	_label(_account, "Join the leaderboard", 36, Hud.GOLD, _hud.display_font)
	_label(_account, "An account is optional: the game plays the same without one. With one, your name, scores, stars and achievements appear on the online leaderboard for everyone to see, and follow you to any device you sign in on. Your email is never shown.", 24, Hud.DIM)
	_field(_account, "email", "Email", false)
	_field(_account, "password", "Password (6 or more characters)", true)
	_field(_account, "name", "Leaderboard name (new accounts only)", false)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_account.add_child(row)
	var up := _action(row, "Create account", _sign_up)
	up.add_theme_stylebox_override("normal", _hud._box(Color("5a2414"), Hud.EMBER, 4, 8, 20))
	up.add_theme_stylebox_override("hover", _hud._box(Color("6e2c18"), Hud.EMBER, 4, 8, 20))
	_action(row, "Sign in", _sign_in)
	_action(row, "Forgot password", _forgot)
	_status = _label(_account, "", 24, Hud.DIM)


func _field(parent: Control, key: String, hint: String, secret: bool) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = hint
	e.secret = secret
	e.custom_minimum_size = Vector2(0, 62)
	e.add_theme_font_size_override("font_size", 28)
	e.add_theme_stylebox_override("normal", _hud._box(Color(0, 0, 0, 0.45), Hud.EDGE, 1, 8, 14))
	e.add_theme_stylebox_override("focus", _hud._box(Color(0, 0, 0, 0.45), Hud.GOLD, 2, 8, 14))
	e.add_theme_color_override("font_color", Hud.BONE)
	e.add_theme_color_override("font_placeholder_color", Color(Hud.DIM, 0.6))
	if key == "name":
		e.max_length = Online.NAME_MAX
	if key == "email":
		e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	elif secret:
		e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	parent.add_child(e)
	_fields[key] = e
	return e


func _action(parent: Control, text: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 62)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(fn)
	parent.add_child(b)
	return b


func _text(key: String) -> String:
	return (_fields[key] as LineEdit).text if _fields.has(key) else ""


func _say(msg: String, bad := false) -> void:
	if _status and is_instance_valid(_status):
		_status.text = msg
		_status.add_theme_color_override("font_color", Hud.POOR if bad else Hud.DIM)


## Runs one account call with the buttons locked, then shows its error or `done`.
func _busy(call: Callable, done: String) -> void:
	_say("Please wait…")
	for b in _account.find_children("*", "Button", true, false):
		(b as Button).disabled = true
	var err: String = await call.call()
	if not is_inside_tree():
		return
	for b in _account.find_children("*", "Button", true, false):
		(b as Button).disabled = false
	if err != "":
		_say(err, true)
	elif done != "":
		_say(done)


func _sign_up() -> void:
	await _busy(func() -> String: return await _online.sign_up(_text("email"), _text("password"), _text("name"), _save), "")


func _sign_in() -> void:
	await _busy(func() -> String: return await _online.sign_in(_text("email"), _text("password"), _save), "")
	_refresh_achievements()


func _forgot() -> void:
	await _busy(func() -> String: return await _online.reset_password(_text("email")), "Check your email for a link to set a new password.")


func _rename() -> void:
	await _busy(func() -> String: return await _online.rename(_text("name"), _save), "")


## Needs a second tap, like Sell.
func _delete() -> void:
	if not _delete_armed:
		_delete_armed = true
		_del_button.text = "Tap again to delete"
		_say("This removes you from the leaderboard and deletes the account. Progress on this device stays.", true)
		return
	await _busy(func() -> String: return await _online.delete_account(), "")


# ---------------------------------------------------------------- helpers

func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


