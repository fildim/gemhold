extends Control
## The Hall of Fame, opened from the level map: the online leaderboard, the achievements and the
## optional account (see Online). Builds its own nodes in code, like the HUD.

signal closed
signal race_ready(race: Dictionary, side: String)   # a race has begun: play it (side "h" host, "g" guest)

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
var _board_label: Button          # the board's name; opens _board_menu
var _board_menu: PopupMenu
var _board_note: Label
var _rows: VBoxContainer
var _ach_count: Label
var _ach_grid: GridContainer
var _account: VBoxContainer
var _status: Label
var _fields := {}                # LineEdits on the account page, by name
var _delete_armed := false
var _del_button: Button
var _race: VBoxContainer
var _race_status: Label
var _race_rows := {}             # "host" and "join" rows of the Race page, for the race walkthrough
var _race_pick: OptionButton
var _race_entry: LineEdit
var _race_code := ""             # the race this player hosts and waits on, or ""
var _race_poll := 0.0
var _race_asking := false


func setup(hud: Control, save: SaveData, online: Online, levels: Array) -> void:
	_hud = hud
	_save = save
	_online = online
	_levels = levels
	_boards = [{"label": "All lairs: total score", "field": "total"}, {"label": "Races: most wins", "field": "rw"}]
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
	for t in ["Leaderboard", "Achievements", "Account", "Race"]:
		var b := _big_button(head, t)
		b.pressed.connect(_show_tab.bind(_tabs.size()))
		_tabs.append(b)
	var back := _big_button(head, "Back to map")
	back.pressed.connect(func() -> void: closed.emit())

	var page_box := PanelContainer.new()
	page_box.add_theme_stylebox_override("panel", hud._box(Hud.PANEL, Hud.EDGE, 1, 14, 22))
	page_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(page_box)
	_pages = [_build_board(), _build_achievements(), _build_account(), _build_race()]
	for p in _pages:
		page_box.add_child(p)
	_online.changed.connect(_refresh_account)
	_online.changed.connect(_refresh_race)
	visibility_changed.connect(func() -> void:
		if not visible:
			_cancel_race())


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
	elif i == 3:
		_refresh_race()


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
	# The board's name is a button: it opens a list of every board, so any lair is one tap away.
	_board_label = _big_button(row, "")
	_board_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_label.add_theme_font_override("font", _hud.bold_font)
	_board_label.add_theme_font_size_override("font_size", 30)
	_board_label.add_theme_color_override("font_color", Hud.GOLD)
	_board_label.clip_text = true
	_board_label.pressed.connect(_pick_board)
	_board_menu = PopupMenu.new()
	_board_menu.add_theme_font_size_override("font_size", 28)
	_board_menu.add_theme_constant_override("v_separation", 14)
	for b in _boards:
		_board_menu.add_item(b["label"])
	_board_menu.index_pressed.connect(func(i: int) -> void:
		_board = i
		_load_board())
	page.add_child(_board_menu)
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


func _pick_board() -> void:
	Sfx.play("click")
	var rect := _board_label.get_global_rect()
	_board_menu.min_size = Vector2i(int(rect.size.x), 0)
	_board_menu.max_size = Vector2i(int(rect.size.x), int(get_viewport_rect().size.y * 0.8))
	_board_menu.popup(Rect2i(Vector2i(rect.position) + Vector2i(0, int(rect.size.y)), Vector2i(int(rect.size.x), 0)))


func _step_board(step: int) -> void:
	Sfx.play("click")
	_board = posmod(_board + step, _boards.size())
	_load_board()


func _load_board() -> void:
	var b: Dictionary = _boards[_board]
	_board_label.text = b["label"]
	_clear(_rows)
	var note := ""
	if _board == 1:
		var w := int(_save.stats.get("race_wins", 0))
		var l := int(_save.stats.get("race_losses", 0))
		note = "Your races: %d won, %d lost%s." % [w, l, ", %d drawn" % int(_save.stats["race_draws"]) if _save.stats.has("race_draws") else ""] if w + l > 0 else "No races of yours yet: race a friend from the Race page."
	else:
		var mine := _save.total_score() if _board == 0 else int(_save.scores.get(_mission(_board), 0))
		note = "Your best: %s" % Hud._thousands(mine) if mine > 0 else "No score of yours here yet."
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
		_label(_rows, "Nobody has won a race yet. Be the first!" if _board == 1 else "Nobody has a score here yet. Be the first!", 26, Hud.DIM)
		return
	for i in res.size():
		_add_row(i + 1, res[i])


## Mission id of leaderboard number n (2 and up: each lair's day, then night).
func _mission(n: int) -> String:
	var id: String = _levels[(n - 2) / 2]["id"]
	return SaveData.mission_id(id, (n - 2) % 2 == 1)


func _add_row(place: int, r: Dictionary) -> void:
	var me: bool = _online.signed_in() and r["uid"] == _online.uid
	var panel := PanelContainer.new()
	var bg := Color("3d2a12") if me else (Hud.PANEL_2 if place % 2 == 1 else Color(0, 0, 0, 0))
	panel.add_theme_stylebox_override("panel", _hud._box(bg, Hud.GOLD if me else Color(0, 0, 0, 0), 1, 8, 12))
	_rows.add_child(panel)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	# Tapping a player shows their best score on every lair.
	var detail := _label(col, _lair_scores(r["scores"]), 24, Hud.DIM)
	detail.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_PASS   # lets the list still scroll by dragging
	var down := [Vector2.ZERO]
	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				down[0] = ev.position
			elif ev.position.distance_to(down[0]) < 20.0:
				Sfx.play("click")
				detail.visible = not detail.visible)
	var medal: Color = [Hud.GOLD, Color("cfd6e0"), Color("d08a4a")][place - 1] if place <= 3 else Hud.DIM
	var p := _label(row, str(place), 30, medal, _hud.display_font)
	p.custom_minimum_size.x = 56
	p.autowrap_mode = TextServer.AUTOWRAP_OFF
	var n := _label(row, r["name"], 28, Hud.GOLD if me else Hud.BONE, _hud.bold_font)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	n.clip_text = true
	var info := "★ %d  ·  %d/%d badges" % [r["stars"], r["ach"], Achievements.LIST.size()]
	if _board == 1:   # races: the record, and the share won
		var games: int = r["rw"] + r["rl"]
		info = "%d lost  ·  %d%% won" % [r["rl"], roundi(100.0 * r["rw"] / games) if games > 0 else 0]
	var extra := _label(row, info, 22, Hud.DIM)
	extra.autowrap_mode = TextServer.AUTOWRAP_OFF
	extra.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var v := _label(row, ("%d wins" % r["value"]) if _board == 1 else Hud._thousands(r["value"]), 30, Hud.GOLD, _hud.bold_font)
	v.custom_minimum_size.x = 150
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.autowrap_mode = TextServer.AUTOWRAP_OFF


## One player's per-lair bests (score_key → points) as a line per lair, campaign order.
func _lair_scores(scores: Dictionary) -> String:
	var lines := []
	for i in _levels.size():
		var id: String = _levels[i]["id"]
		var day := int(scores.get(Online.score_key(id), 0))
		var night := int(scores.get(Online.score_key(SaveData.mission_id(id, true)), 0))
		if day > 0 or night > 0:
			lines.append("Lair %d: %s   —   day %s  ·  night %s" % [i + 1, _levels[i]["title"],
				Hud._thousands(day) if day > 0 else "–", Hud._thousands(night) if night > 0 else "–"])
	return "\n".join(lines) if lines else "No lair won yet."


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


# ---------------------------------------------------------------- race
# One player hosts a race on a lair and gets a code; the rival types it in to join, and the race
# begins for both: same lair, same heroes, no Dark Arts. See Online (races) and main.gd.

func _build_race() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_race = VBoxContainer.new()
	_race.add_theme_constant_override("separation", 12)
	_race.custom_minimum_size = Vector2(760, 0)
	center.add_child(_race)
	return scroll


func _refresh_race() -> void:
	if _race == null:
		return
	_clear(_race)
	_race_rows.clear()
	_label(_race, "Race a rival", 36, Hud.GOLD, _hud.display_font)
	if not _online.signed_in():
		_label(_race, "Races are played online, so both of you need an account. Sign in or create one on the Account page.", 24, Hud.DIM)
		_action(_race, "Go to Account", _show_tab.bind(2))
		return
	if _race_code != "":
		_label(_race, "Give your rival this code. The race starts the moment they join.", 24, Hud.DIM)
		var code := _label(_race, _race_code, 96, Hud.GOLD, _hud.display_font)
		code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_race_status = _label(_race, "Waiting for a rival…", 26, Hud.DIM)
		_action(_race, "Call off the race", func() -> void:
			_cancel_race()
			_refresh_race())
		return
	_label(_race, "You both play the same lair at the same time (by day, or at night once you have opened it), with the same heroes and no Dark Arts skills. Slaying heroes and spending gold sends heroes onto your rival's road. The race ends for both the moment one of you clears the last wave or falls: clear it first to win. Every race counts on the Races leaderboard.", 24, Hud.DIM)
	var host := HBoxContainer.new()
	_race_rows["host"] = host
	host.add_theme_constant_override("separation", 10)
	_race.add_child(host)
	_race_pick = OptionButton.new()
	_race_pick.focus_mode = Control.FOCUS_NONE
	_race_pick.custom_minimum_size = Vector2(0, 62)
	_race_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_race_pick.add_theme_font_size_override("font_size", 26)
	_race_pick.get_popup().add_theme_font_size_override("font_size", 28)
	# Item id = lair index × 2, +1 for its night mission (offered once the host has opened it).
	var newest := 0
	for i in _levels.size():
		if _save.is_unlocked(i):
			_race_pick.add_item("Lair %d: %s" % [i + 1, _levels[i]["title"]], i * 2)
			newest = _race_pick.item_count - 1
			if _save.night_unlocked(_levels[i]["id"]):
				_race_pick.add_item("Lair %d: %s · Night" % [i + 1, _levels[i]["title"]], i * 2 + 1)
	_race_pick.select(newest)
	host.add_child(_race_pick)
	_action(host, "Host a race", _host_race)
	var join := HBoxContainer.new()
	_race_rows["join"] = join
	join.add_theme_constant_override("separation", 10)
	_race.add_child(join)
	_race_entry = _field(join, "race_code", "Rival's race code", false)
	_race_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_race_entry.max_length = Online.RACE_CODE_LEN
	_action(join, "Join", _join_race)
	_race_status = _label(_race, "", 24, Hud.DIM)


func _race_say(msg: String, bad := false) -> void:
	if _race_status and is_instance_valid(_race_status):
		_race_status.text = msg
		_race_status.add_theme_color_override("font_color", Hud.POOR if bad else Hud.DIM)


func _race_lock(on: bool) -> void:
	for b in _race.find_children("*", "Button", true, false):
		(b as Button).disabled = on


func _host_race() -> void:
	var pick := _race_pick.get_selected_id()
	_race_say("Please wait…")
	_race_lock(true)
	var r: Dictionary = await _online.race_host(_levels[pick / 2]["id"], pick % 2 == 1)
	if not is_inside_tree():
		return
	_race_lock(false)
	if r.has("error"):
		_race_say(r["error"], true)
		return
	_race_code = r["code"]
	_race_poll = 2.0
	_refresh_race()


func _join_race() -> void:
	_race_say("Please wait…")
	_race_lock(true)
	var r: Dictionary = await _online.race_join(_race_entry.text)
	if not is_inside_tree():
		return
	_race_lock(false)
	if r.has("error"):
		_race_say(r["error"], true)
		return
	race_ready.emit(r, "g")


func _cancel_race() -> void:
	if _race_code == "":
		return
	_online.race_cancel(_race_code)
	_race_code = ""


## While hosting, looks every couple of seconds whether a rival has joined.
func _process(delta: float) -> void:
	if _race_code == "" or _race_asking:
		return
	_race_poll -= delta
	if _race_poll > 0.0:
		return
	_race_poll = 2.0
	_race_asking = true
	var code := _race_code
	var r: Dictionary = await _online.race_get(code)
	_race_asking = false
	if code != _race_code:
		return   # called off meanwhile
	if r.has("error"):
		_race_say(r["error"], true)
		return
	if r["state"] == "on":
		_race_code = ""   # it is no longer waiting, so closing the hall must not call it off
		_refresh_race()
		race_ready.emit(r, "h")


# ---------------------------------------------------------------- helpers

func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()




## The Race page is showing its host and join choices (signed in, not waiting on a rival).
func race_page_open() -> bool:
	return visible and _pages[3].visible and _race_code == "" and _race_rows.has("host") and is_instance_valid(_race_rows["host"])


## Where a Race page row ("host" or "join") is on screen, for the walkthrough.
func race_rect(row: String) -> Rect2:
	var c: Control = _race_rows.get(row)
	return c.get_global_rect() if c and is_instance_valid(c) and c.is_visible_in_tree() else Rect2()
