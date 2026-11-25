extends Control
## Everything drawn over the map: the top stats bar, spell buttons, the tile panel,
## messages and the start/end screens. Builds its own nodes in code.

signal next_wave_pressed
signal meteor_pressed
signal cut_pressed
signal speed_pressed
signal pause_pressed
signal action_pressed(id: String)
signal popup_closed
signal start_pressed
signal restart_pressed
signal restart_now   # the battle bar's Restart (second tap): start this lair again at once
signal next_level_pressed
signal night_pressed
signal long_pressed   # the start card's Long Night button
signal map_pressed
signal send_pressed(code: String)   # online race: buy this hero for the rival

const ACH_ON_CARD := 3   # achievements listed on the end card; the rest are counted
const NIGHT := Color("15110d")
const PANEL := Color("231b14")
const PANEL_2 := Color("2f251b")
const EDGE := Color("6b5236")
const BONE := Color("efe4cc")
const DIM := Color("a8977c")
const GOLD := Color("e8b84a")
const MANA := Color("7e6cf0")
const GEM := Color("e0405e")
const EMBER := Color("e2683a")
const POOR := Color("ff6a6a")
const SELL_CONFIRM_TIME := 2.5

var top_h := 56.0
var bottom_h := 64.0
var side := false        # stats and buttons in a panel on the right (wide screens)
var map_aspect := 1.6    # map width / height, set by main.gd
## Where the map may go, in this control's units; the bars or side panel take the rest.
var map_area := Rect2()

var body_font: Font
var bold_font: Font
var display_font: Font

var _top: PanelContainer
var _bottom: PanelContainer
var _row: BoxContainer
var _brow: BoxContainer
var _gold: Label
var _mana: Label
var _mana_bar: ProgressBar
var _gems: Label
var _wave: Label
var _resolve: Label         # "Resolve ×1.45": the dynamic difficulty, not shown in races
var _rival: Label          # the rival's progress during an online race, in a badge over the map corner
var _rival_box: PanelContainer
var _next: Button
var _meteor: Button
var _cut: Button
var _speed: Button
var _pause: Button
var _tide: Control   # the tide clock (lairs with a Tide rule); it shows the Eclipse on lairs that have one
var _boss_box: PanelContainer   # a boss's name and health over the top of the map while one is alive
var _boss_name: Label
var _boss_bar: ProgressBar
var _play_row: HBoxContainer    # speed and pause share a row
var _send: Button           # online race only, in place of Pause: opens _send_menu
var _send_menu: PopupMenu
var _send_kinds: Array[String] = []
var _sim: GameSim           # the battle shown, as of the last refresh
var _popup: PanelContainer
var _popup_box: VBoxContainer
var _popup_actions: Array = []   # [{button, gold, mana}]
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _overlay: Control
var _card_box: VBoxContainer
var _sound: Button
var _map_arms := 0
var _leave_row: HBoxContainer   # Restart and Map share a row
var _restart: Button        # hidden in online races
var _popup_anchor := Rect2()   # the tile the tile panel last opened for, and the side it took there,
var _popup_side := -1          # so an upgrade that grows the range circle keeps it on that side
var _rating: Label
var _rating_was := ""
var _rating_shown := ""      # the rating the label shows (it changes rarely; refresh runs every frame)
var _fps: Label             # the frame rate, in a corner of the map (Settings > Show frame rate)
var _fps_t := 0.0
var _fps_frames := 0
var _keys_shown := ""        # the shortcut keys the tooltips were last set for
var _boss_shown: Object      # the boss whose name the bar shows
var _brand: Label            # the lair's number and name in the top bar ("Gemhold" until one is set)
var _intro_lair := ""        # the level id on the start card, for show_world_best
var _world: RichTextLabel    # the world best line on the start card


func _ready() -> void:
	body_font = load("res://assets/fonts/AlegreyaSans-Bold.ttf")
	bold_font = load("res://assets/fonts/AlegreyaSans-ExtraBold.ttf")
	var grenze: FontFile = load("res://assets/fonts/GrenzeGotisch.ttf")
	for f: Font in [body_font, bold_font, grenze]:
		f.fallbacks = [Symbols.font()]
	var fv := FontVariation.new()
	fv.base_font = grenze
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
	display_font = fv
	theme = _make_theme()
	_build_bars()
	_build_popup()
	_build_toast()
	_build_overlay()
	_build_fps()
	resized.connect(_layout)
	_layout()


# ---------------------------------------------------------------- theme

func _box(bg: Color, border: Color, bottom := 1, radius := 8, pad := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.border_width_bottom = bottom
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.6
	sb.content_margin_bottom = pad * 0.6
	return sb


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = body_font
	t.default_font_size = 23
	t.set_color("font_color", "Label", BONE)
	t.set_color("default_color", "RichTextLabel", BONE)
	t.set_font("bold_font", "RichTextLabel", bold_font)
	t.set_font("normal_font", "RichTextLabel", body_font)
	t.set_font_size("normal_font_size", "RichTextLabel", 22)
	t.set_font_size("bold_font_size", "RichTextLabel", 22)
	t.set_font("font", "Button", bold_font)
	t.set_font_size("font_size", "Button", 22)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", BONE)
	t.set_color("font_disabled_color", "Button", Color(BONE, 0.4))
	# Carved frames (Frames.carved): a bevelled rim, a groove and a faint gold inlay.
	t.set_stylebox("normal", "Button", Frames.carved(PANEL_2, Color("6b5236"), 4, 14))
	t.set_stylebox("hover", "Button", Frames.carved(Color("3a2e22"), Color("8a6a46"), 4, 14))
	t.set_stylebox("pressed", "Button", Frames.carved(Color("1c160f"), Color("5b4630"), 1, 14))
	t.set_stylebox("disabled", "Button", Frames.carved(Color(PANEL_2, 0.5), Color(Color("5b4630"), 0.45), 4, 14, false))
	var focus := _box(Color(0, 0, 0, 0), GOLD, 2, 8, 14)
	focus.set_border_width_all(2)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("panel", "PanelContainer", Frames.carved(PANEL, EDGE, 0, 16))
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0, 0, 0, 0.6)
	bar_bg.set_corner_radius_all(5)
	bar_bg.border_color = Color(1, 1, 1, 0.12)
	bar_bg.set_border_width_all(1)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = MANA
	bar_fill.set_corner_radius_all(5)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	return t


# ---------------------------------------------------------------- bars

func _build_bars() -> void:
	_top = PanelContainer.new()
	_top.add_theme_stylebox_override("panel", _box(Color(NIGHT, 0.92), Color(0, 0, 0, 0), 0, 0, 14))
	_top.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_top)
	var row := BoxContainer.new()   # a row on top, or a column in the side panel
	_row = row
	row.add_theme_constant_override("separation", 18)
	_top.add_child(row)
	var brand := Label.new()
	brand.text = "Gemhold"
	brand.add_theme_font_override("font", display_font)
	brand.add_theme_font_size_override("font_size", 30)
	brand.add_theme_color_override("font_color", GOLD)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	brand.custom_minimum_size = Vector2(120, 0)
	row.add_child(brand)
	_brand = brand
	_gold = _stat(row, "coin")
	var mana_box := HBoxContainer.new()
	mana_box.add_theme_constant_override("separation", 6)
	mana_box.add_child(_icon("drop"))
	_mana_bar = ProgressBar.new()
	_mana_bar.custom_minimum_size = Vector2(90, 12)
	_mana_bar.show_percentage = false
	_mana_bar.max_value = Defs.MANA_MAX
	_mana_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mana_box.add_child(_mana_bar)
	_mana = Label.new()
	_mana.add_theme_font_override("font", bold_font)
	mana_box.add_child(_mana)
	row.add_child(mana_box)
	_gems = _stat(row, "gem")
	_rating = Label.new()
	_rating.add_theme_font_override("font", bold_font)
	row.add_child(_rating)
	_wave = Label.new()
	_wave.add_theme_font_override("font", bold_font)
	row.add_child(_wave)
	# Resolve: the dynamic difficulty (GameSim.threat), shown so the player knows the heroes answer
	# good play; hidden in races, which use a fixed curve.
	_resolve = Label.new()
	_resolve.add_theme_font_override("font", bold_font)
	_resolve.add_theme_color_override("font_color", Color("e2683a"))
	_resolve.mouse_filter = Control.MOUSE_FILTER_PASS
	_resolve.tooltip_text = "Heroes' resolve: their health grows when you defend well (up to ×%.1f, less on chapters you have moved past) and when you hoard gold (up to ×%.1f). Your score is multiplied by it." % [Defs.THREAT["max"], Defs.THREAT["max_rich"]]
	row.add_child(_resolve)
	_tide = TideClock.new()
	_tide.custom_minimum_size = Vector2(34, 34)
	_tide.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tide.visible = false
	row.add_child(_tide)

	_bottom = PanelContainer.new()
	_bottom.add_theme_stylebox_override("panel", _box(Color(NIGHT, 0.92), Color(0, 0, 0, 0), 0, 0, 10))
	add_child(_bottom)
	var brow := BoxContainer.new()
	_brow = brow
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.add_theme_constant_override("separation", 10)
	_bottom.add_child(brow)
	_next = _button(brow, "Next wave", next_wave_pressed)
	_next.add_theme_stylebox_override("normal", _box(Color("3d2a12"), Color("8a6420"), 4, 8, 14))
	_meteor = _button(brow, "Meteor %d" % Defs.METEOR["cost"], meteor_pressed)
	for st: String in ["normal", "hover", "pressed", "disabled"]:   # room for its picture on the left
		var sb: StyleBox = theme.get_stylebox(st, "Button").duplicate()
		sb.content_margin_left += 34
		_meteor.add_theme_stylebox_override(st, sb)
	var mic := GameIcon.make("spell:meteor", 40)
	mic.framed = false
	mic.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	mic.offset_left = 8
	mic.offset_right = 48
	mic.offset_top = -20
	mic.offset_bottom = 20
	_meteor.add_child(mic)
	_cut = _button(brow, "Cut woods 15", cut_pressed)
	_play_row = HBoxContainer.new()
	_play_row.add_theme_constant_override("separation", 8)
	brow.add_child(_play_row)
	_speed = _button(_play_row, "1×", speed_pressed)
	_pause = _button(_play_row, "Pause", pause_pressed)
	_send = Button.new()
	_send.text = "Send heroes"
	_send.custom_minimum_size = Vector2(0, 48)
	_send.focus_mode = Control.FOCUS_NONE
	_send.add_theme_color_override("font_color", Color("e2683a"))
	_send.visible = false
	_send.pressed.connect(_open_send)
	_play_row.add_child(_send)
	_send_menu = PopupMenu.new()
	_send_menu.add_theme_font_size_override("font_size", 28)
	_send_menu.add_theme_constant_override("v_separation", 14)
	_send_menu.index_pressed.connect(func(i: int) -> void: send_pressed.emit(_send_kinds[i]))
	add_child(_send_menu)
	_sound = sound_button(brow)
	_add_leave_row(brow)
	for b in [_meteor, _cut]:
		b.add_theme_color_override("font_color", Color("c9c0ff"))


func _stat(parent: Control, icon: String) -> Label:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_icon(icon))
	var l := Label.new()
	l.add_theme_font_override("font", bold_font)
	box.add_child(l)
	parent.add_child(box)
	return l


func _icon(kind: String) -> Control:
	var ic := StatIcon.new()
	ic.kind = kind
	ic.custom_minimum_size = Vector2(26, 26)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return ic


## Opens the Settings window (effects and music sliders, screen shake) over `host`, or over the HUD when
## none is given. Also used on the level map.
func sound_button(parent: Control, host: Control = null) -> Button:
	var b := Button.new()
	b.text = "Settings"
	b.custom_minimum_size = Vector2(0, 48)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: SoundWindow.open(self, host if host else self))
	parent.add_child(b)
	return b


## Restart and Map share the bar's last row. Both throw the battle away, so each needs a second tap
## within SELL_CONFIRM_TIME seconds, like Sell. Restart is hidden in online races.
func _add_leave_row(parent: Control) -> void:
	_leave_row = HBoxContainer.new()
	_leave_row.add_theme_constant_override("separation", 8)
	parent.add_child(_leave_row)
	_restart = _confirm_button(_leave_row, "Restart", restart_now)
	_confirm_button(_leave_row, "Map", map_pressed)


func _confirm_button(parent: Control, text: String, sig: Signal) -> Button:
	var b := _button(parent, text, sig)
	for c in b.pressed.get_connections():
		b.pressed.disconnect(c["callable"])
	var armed := [0]   # 0 = not armed, else which arming this is (a stale timer leaves a newer one alone)
	b.pressed.connect(func() -> void:
		if armed[0] > 0:
			armed[0] = 0
			b.text = text
			sig.emit()
			return
		_map_arms += 1
		armed[0] = _map_arms
		var mine := _map_arms
		b.text = "Tap again"
		get_tree().create_timer(SELL_CONFIRM_TIME).timeout.connect(func() -> void:
			if armed[0] == mine:
				armed[0] = 0
				b.text = text))
	return b


## Every button of the battle bar, including those sharing a row.
func _buttons() -> Array[Button]:
	var out: Array[Button] = []
	for c in _brow.get_children():
		if c is Button:
			out.append(c)
		else:
			for b in c.get_children():
				if b is Button:
					out.append(b)
	return out


func _button(parent: Control, text: String, sig: Signal) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: sig.emit())
	parent.add_child(b)
	return b


## Lays out the HUD in whichever arrangement leaves the map bigger: bars along the top and
## bottom (tall windows), or one panel down the right side (wide screens such as phones).
func _layout() -> void:
	var safe := _safe_margins()
	var next_text := _next.text
	_next.text = "First wave 99s (+99g)"   # measure with the longest label it can show
	# Bars: stats across the top, buttons across the bottom.
	_set_side(false, safe)
	top_h = _top.get_combined_minimum_size().y
	bottom_h = _bottom.get_combined_minimum_size().y
	var bar_area := Rect2(8 + safe.x, top_h + 4, size.x - 16 - safe.x - safe.z, size.y - top_h - bottom_h - 8)
	# Side panel: stats above the buttons, down the right edge.
	_set_side(true, safe)
	var w := maxf(220.0, maxf(_top.get_combined_minimum_size().x, _bottom.get_combined_minimum_size().x))
	var side_area := Rect2(8 + safe.x, 8 + safe.y, size.x - w - 16 - safe.x, size.y - 16 - safe.y - safe.w)
	side = _fit(side_area) > _fit(bar_area) + 1.0
	_next.text = next_text
	if side:
		var th := _top.get_combined_minimum_size().y
		_top.position = Vector2(size.x - w, 0)
		_top.size = Vector2(w, th)
		_bottom.position = Vector2(size.x - w, th)
		_bottom.size = Vector2(w, size.y - th)
		map_area = side_area
	else:
		_set_side(false, safe)
		_top.position = Vector2.ZERO
		_top.size = Vector2(size.x, top_h)
		_bottom.position = Vector2(0, size.y - bottom_h)
		_bottom.size = Vector2(size.x, bottom_h)
		map_area = bar_area
	if _overlay:
		_overlay.size = size


## Map height that fits in an area, keeping the map's proportions.
func _fit(area: Rect2) -> float:
	return minf(area.size.y, area.size.x / map_aspect)


func _set_side(on: bool, safe: Vector4) -> void:
	_row.vertical = on
	_brow.vertical = on
	_row.add_theme_constant_override("separation", 10 if on else 18)
	_brow.alignment = BoxContainer.ALIGNMENT_BEGIN if on else BoxContainer.ALIGNMENT_CENTER
	# The side panel (phones, wide windows) gets bigger text, and its buttons share out the
	# whole height of the screen so they are easy to hit.
	for l: Label in [_gold, _mana, _gems, _rating, _wave, _resolve]:
		l.add_theme_font_size_override("font_size", 30 if on else 23)
	_mana_bar.custom_minimum_size = Vector2(120 if on else 90, 14 if on else 12)
	for row: Control in [_play_row, _leave_row]:
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL if on else Control.SIZE_FILL
	for b: Button in _buttons():
		var paired := b.get_parent() != _brow
		b.add_theme_font_size_override("font_size", (24 if paired else 28) if on else 22)
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL if on else Control.SIZE_FILL
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL if on and paired else Control.SIZE_FILL
		b.custom_minimum_size.y = 56 if on else 48
	var tm: StyleBoxFlat = _top.get_theme_stylebox("panel")
	var bm: StyleBoxFlat = _bottom.get_theme_stylebox("panel")
	tm.content_margin_left = 14 + (0.0 if on else safe.x)
	tm.content_margin_right = 14 + safe.z
	tm.content_margin_top = (14 if on else 8) + safe.y
	tm.content_margin_bottom = 6 if on else 8
	bm.content_margin_left = 14 if on else 10
	bm.content_margin_right = (14 if on else 10) + (safe.z if on else 0.0)
	bm.content_margin_bottom = 8 + safe.w
	_top.reset_size()
	_bottom.reset_size()


## Lays the HUD out again, e.g. when a level with a different map shape loads.
func relayout() -> void:
	_layout()


## Hides the stats and spell bars (and any open card) while the level map is up.
func set_battle_visible(on: bool) -> void:
	_top.visible = on
	_bottom.visible = on
	if _fps and not on:
		_fps.visible = false
	if not on:
		_boss_box.visible = false
	if not on:
		_overlay.visible = false
		hide_popup()


## Space taken by notches and system bars, in this control's units: x=left, y=top, z=right, w=bottom.
func _safe_margins() -> Vector4:
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0 or not OS.has_feature("mobile"):
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var k := size.x / float(win.x)
	return Vector4(safe.position.x, safe.position.y, win.x - safe.end.x, win.y - safe.end.y) * k


# ---------------------------------------------------------------- per frame

func refresh(sim: GameSim, armed: bool, speed: int, paused: bool) -> void:
	_sim = sim
	_gold.text = str(sim.gold)
	_mana.text = str(int(sim.mana))
	_mana_bar.max_value = sim.mana_max
	_mana_bar.value = sim.mana
	_gems.text = "%d/%d" % [sim.gems_left(), sim.level.gems]
	_wave.text = "Wave %d" % sim.wave if sim.long_on else "Wave %d/%d" % [sim.wave, sim.level.waves.size()]
	_resolve.visible = not sim.race_on
	_resolve.text = ("Held %d wave%s" % [sim.cleared, "" if sim.cleared == 1 else "s"]) if sim.long_on else "Resolve ×%.2f" % sim.threat
	if sim.dusk_wave > 0 and not sim.dark:   # the Dusk rule: say when night will fall
		_wave.text += " · night at %d" % sim.dusk_wave
	# One dial serves both rules: the tide (blue arc = high water) or the eclipse (dark arc = darkness).
	var cycle := sim.tide if sim.tide.x > 0.0 else sim.eclipse
	if _tide.visible != (cycle.x > 0.0):   # the dial comes or goes with the lair: make room for it
		_tide.visible = cycle.x > 0.0
		_layout()
	if _tide.visible:
		_tide.phase = fmod(sim.time, cycle.x) / cycle.x
		_tide.high = cycle.y / cycle.x
		_tide.arc = Color("5aa0d0") if sim.tide.x > 0.0 else Color("7a5cc8")
		_tide.queue_redraw()
	_show_boss(sim)
	if Keys.available():
		var shown := ""
		for a: String in ["pause", "speed", "next", "meteor", "cut"]:
			shown += Keys.name_of(a) + ","
		if shown != _keys_shown:   # only when a key was changed
			_keys_shown = shown
			for pair: Array in [[_pause, "pause"], [_speed, "speed"], [_next, "next"], [_meteor, "meteor"], [_cut, "cut"]]:
				pair[0].tooltip_text = "Key: %s (change it in Settings)" % Keys.name_of(pair[1])
	_show_rating(sim.rating_now())
	_show_fps()
	if sim.wave < sim.level.waves.size():
		var s := int(ceil(sim.timer))
		_next.disabled = false
		_next.text = "%s %ds (+%dg)" % ["Next wave" if sim.wave > 0 else "First wave", s, s]
	else:
		_next.disabled = true
		_next.text = "Final wave"
	_meteor.disabled = not sim.can_meteor() and not armed
	_meteor.text = "Cancel meteor" if armed else "Meteor %d" % Defs.METEOR["cost"]
	_cut.disabled = sim.trees.is_empty() or sim.mana < sim.woods_cost()
	_cut.text = "Cut woods %d" % sim.woods_cost()
	_speed.text = "%d×" % speed
	_pause.text = "Resume" if paused else "Pause"
	for a in _popup_actions:
		var short: bool = (a["gold"] > 0 and sim.gold < a["gold"]) or (a["mana"] > 0 and sim.mana < a["mana"])
		if a.get("short") == short:
			continue   # a theme override re-themes the button: only when it changes
		a["short"] = short
		var col := POOR if short else BONE
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			a["button"].add_theme_color_override(c, col)


## A boss on the map: its name and health in a bar over the top of the map, so the player always
## knows how far along the fight is. Gone when no boss is alive.
func _show_boss(sim: GameSim) -> void:
	var boss: GameSim.Enemy = null
	for e: GameSim.Enemy in sim.enemies:
		if e.hp > 0.0 and e.d.has("boss") and not e.retreat:
			boss = e
			break
	_boss_box.visible = boss != null
	if boss == null:
		_boss_shown = null
		return
	_boss_bar.max_value = boss.max_hp
	_boss_bar.value = boss.hp
	if boss == _boss_shown:
		return   # name, size and place stay as they were
	_boss_shown = boss
	var bn := String(boss.d["name"])
	_boss_name.text = bn.left(1).to_upper() + bn.substr(1)
	_boss_box.reset_size()
	_boss_box.position = Vector2(map_area.position.x + (map_area.size.x - _boss_box.size.x) / 2.0, map_area.position.y + 8)


## The rating the battle is heading for, as stars, with a message the moment it slips.
func _show_rating(r: String) -> void:
	if r == _rating_shown:
		return
	_rating_shown = r
	var stars := maxi(1, SaveData.RANKS.find(r))
	_rating.text = "★".repeat(stars) + " " + r
	_rating.add_theme_color_override("font_color", {"Brilliant": GOLD, "Wicked": Color("e0a050"), "Survived": POOR}.get(r, BONE))
	if _rating_was != "" and SaveData.RANKS.find(r) < SaveData.RANKS.find(_rating_was):
		toast("A hero touched a gem: Brilliant is lost" if r == "Wicked" else "A gem was carried off: Wicked is lost")
	_rating_was = r


## Forget the last rating, so a fresh battle does not report a change.
func reset_rating() -> void:
	_rating_was = ""
	_rating_shown = ""
	_boss_shown = null


## The frame rate in the map's top left corner, when Settings > Show frame rate is on: a quiet
## number, updated twice a second, for checking a phone.
func _build_fps() -> void:
	_fps = Label.new()
	_fps.visible = false
	_fps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps.add_theme_font_override("font", bold_font)
	_fps.add_theme_font_size_override("font_size", 18)
	_fps.add_theme_color_override("font_color", Color(DIM, 0.85))
	_fps.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_fps.add_theme_constant_override("outline_size", 4)
	add_child(_fps)


func _show_fps() -> void:
	var on: bool = Prefs.get_value("show_fps", false) and _top.visible
	_fps.visible = on
	if not on:
		_fps_t = 0.0
		_fps_frames = 0
		return
	_fps_frames += 1
	_fps_t += get_process_delta_time()
	if _fps_t >= 0.5:
		_fps.text = "%d fps" % roundi(_fps_frames / _fps_t)
		_fps_t = 0.0
		_fps_frames = 0
		_fps.position = map_area.position + Vector2(6, 4)


# ---------------------------------------------------------------- tile panel

func _build_popup() -> void:
	_popup = PanelContainer.new()
	_popup.visible = false
	_popup.custom_minimum_size = Vector2(300, 0)
	add_child(_popup)
	_popup_box = VBoxContainer.new()
	_popup_box.add_theme_constant_override("separation", 8)
	_popup.add_child(_popup_box)


func popup_open() -> bool:
	return _popup.visible


## anchor is the selected tile's rectangle in screen coordinates; avoid (if it has an area) is the
## range circle shown around it, which the panel keeps clear of when there is room.
func show_popup(info: Dictionary, anchor: Rect2, avoid := Rect2()) -> void:
	for c in _popup_box.get_children():
		_popup_box.remove_child(c)   # now, so the panel can shrink to the new contents
		c.queue_free()
	_popup_actions.clear()
	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = info["title"]
	title.add_theme_font_override("font", display_font)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(44, 40)
	close.add_theme_font_size_override("font_size", 24)
	close.pressed.connect(func() -> void: popup_closed.emit())
	head.add_child(close)
	_popup_box.add_child(head)
	var text := Label.new()
	text.text = info["text"]
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(280, 0)
	text.add_theme_color_override("font_color", DIM)
	text.add_theme_font_override("font", body_font)
	_popup_box.add_child(text)
	if info.has("cuts"):   # a building that takes several cuts: how many are left, big and plain
		var left: int = info["cuts"][0]
		var all: int = info["cuts"][1]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var bar := CutBar.new()
		bar.left = left
		bar.total = all
		bar.custom_minimum_size = Vector2(all * 34 + (all - 1) * 6, 30)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var cl := Label.new()
		cl.text = "%d of %d cuts left" % [left, all] if left > 1 else "Last cut!"
		cl.add_theme_font_override("font", bold_font)
		cl.add_theme_font_size_override("font_size", 28)
		cl.add_theme_color_override("font_color", Color("c9c0ff"))
		row.add_child(cl)
		_popup_box.add_child(row)
	for a in info["actions"]:
		var b := Button.new()
		if a["id"] == "sell":
			_add_sell_button(b, a)
			continue
		b.text = "%s    %s" % [a["label"], a["price"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = a.get("disabled", false)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 46)
		var id: String = a["id"]
		b.pressed.connect(func() -> void: action_pressed.emit(id))
		_popup_box.add_child(b)
		_popup_actions.append({"id": id, "button": b, "gold": int(a.get("gold", 0)), "mana": int(a.get("mana", 0))})
	_popup.visible = true
	_popup.reset_size()
	var ps := _popup.get_combined_minimum_size()
	var area := map_area
	var keep := avoid.merge(anchor) if avoid.has_area() else anchor
	# Beside the circle (right, left), then below or above it; otherwise whichever side of the
	# tile has more room, so as little of the circle as possible is covered.
	var tries := [
		Vector2(keep.end.x + 6, anchor.position.y), Vector2(keep.position.x - ps.x - 6, anchor.position.y),
		Vector2(anchor.position.x, keep.end.y + 6), Vector2(anchor.position.x, keep.position.y - ps.y - 6)]
	var p := Vector2(INF, INF)
	var chosen := -1
	var order := range(tries.size())
	var same := anchor == _popup_anchor and _popup_side >= 0
	if same:   # the same tile again (an upgrade): its old side first, so the panel doesn't jump
		order.erase(_popup_side)
		order.push_front(_popup_side)
	for k: int in order:
		var t: Vector2 = tries[k]
		var q := Vector2(t.x, clampf(t.y, area.position.y, area.end.y - ps.y))
		if t.x == anchor.position.x:   # below or above: slide sideways, keep the vertical spot
			q = Vector2(clampf(t.x, area.position.x, area.end.x - ps.x), t.y)
		if Rect2(q, ps).grow(-1).intersects(keep) == false and area.encloses(Rect2(q, ps)):
			p = q
			chosen = k
			break
		if same and k == _popup_side:
			# A bigger circle no longer leaves room there: stay on that side, beside the tile itself,
			# rather than jumping across the map.
			var near := [Vector2(anchor.end.x + 6, anchor.position.y), Vector2(anchor.position.x - ps.x - 6, anchor.position.y),
				Vector2(anchor.position.x, anchor.end.y + 6), Vector2(anchor.position.x, anchor.position.y - ps.y - 6)]
			var n: Vector2 = near[k]
			q = Vector2(n.x, clampf(n.y, area.position.y, area.end.y - ps.y)) if k < 2 else Vector2(clampf(n.x, area.position.x, area.end.x - ps.x), n.y)
			if area.encloses(Rect2(q, ps)):
				p = q
				chosen = k
				break
	_popup_anchor = anchor
	_popup_side = chosen
	if p.x == INF:
		var right := area.end.x - anchor.end.x > anchor.position.x - area.position.x
		p = Vector2(area.end.x - ps.x if right else area.position.x, anchor.position.y)
	p.x = clampf(p.x, area.position.x, area.end.x - ps.x)
	p.y = clampf(p.y, area.position.y, area.end.y - ps.y)
	_popup.position = p


## Sell sits apart from the other actions, in red, and needs a second tap within
## SELL_CONFIRM_TIME seconds so a slip of the finger never loses a tower.
func _add_sell_button(b: Button, a: Dictionary) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	_popup_box.add_child(gap)
	var label := "%s    %s" % [a["label"], a["price"]]
	b.text = label
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_stylebox_override("normal", _box(Color("3a1712"), Color("8a2e22"), 2))
	b.add_theme_stylebox_override("hover", _box(Color("4a1d16"), Color("b23a2a"), 2))
	b.add_theme_stylebox_override("pressed", _box(Color("5a2219"), Color("b23a2a"), 2))
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, POOR)
	var armed := [false]
	b.pressed.connect(func() -> void:
		if armed[0]:
			action_pressed.emit("sell")
			return
		armed[0] = true
		b.text = "Tap again to sell    %s" % a["price"]
		get_tree().create_timer(SELL_CONFIRM_TIME).timeout.connect(func() -> void:
			if is_instance_valid(b):
				armed[0] = false
				b.text = label))
	_popup_box.add_child(b)


func hide_popup() -> void:
	_popup.visible = false
	_popup_actions.clear()


# ---------------------------------------------------------------- messages

func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.8), Color(0, 0, 0, 0), 0, 18, 14))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	_toast_label = Label.new()
	_toast_label.add_theme_font_override("font", bold_font)
	_toast.add_child(_toast_label)
	add_child(_toast)
	_boss_box = PanelContainer.new()
	_boss_box.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.72), Color("8a2e3a"), 1, 10, 12))
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.visible = false
	var bb := VBoxContainer.new()
	bb.add_theme_constant_override("separation", 4)
	_boss_box.add_child(bb)
	_boss_name = Label.new()
	_boss_name.add_theme_font_override("font", display_font)
	_boss_name.add_theme_font_size_override("font_size", 28)
	_boss_name.add_theme_color_override("font_color", Color("ff9aae"))
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bb.add_child(_boss_name)
	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size = Vector2(420, 18)
	_boss_bar.show_percentage = false
	var bf := StyleBoxFlat.new()
	bf.bg_color = GEM
	bf.set_corner_radius_all(5)
	_boss_bar.add_theme_stylebox_override("fill", bf)
	bb.add_child(_boss_bar)
	add_child(_boss_box)
	_rival_box = PanelContainer.new()
	_rival_box.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.7), Color("e2683a"), 1, 10, 12))
	_rival_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rival_box.visible = false
	_rival = Label.new()
	_rival.add_theme_font_override("font", bold_font)
	_rival.add_theme_font_size_override("font_size", 26)
	_rival.add_theme_color_override("font_color", Color("e2683a"))
	_rival_box.add_child(_rival)
	add_child(_rival_box)


func toast(msg: String) -> void:
	_toast_label.text = msg
	_toast.reset_size()
	_toast.position = Vector2(map_area.position.x + (map_area.size.x - _toast.size.x) / 2.0,
		map_area.position.y + 10 + (_boss_box.size.y + 8 if _boss_box.visible else 0.0))
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast.modulate.a = 1.0
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.3)


## Where a HUD button is on screen, for the tutorial spotlight: "next" or "meteor".
func button_rect(button: String) -> Rect2:
	var b: Control = {"next": _next, "meteor": _meteor, "tide": _tide}.get(button)
	return b.get_global_rect() if b and b.is_visible_in_tree() else Rect2()


## Where the open tile panel's button for an action is on screen, or an empty rect.
func action_rect(id: String) -> Rect2:
	if not _popup.visible:
		return Rect2()
	for a in _popup_actions:
		if a["id"] == id:
			return (a["button"] as Button).get_global_rect()
	return Rect2()


# ---------------------------------------------------------------- start / end screens

func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(PANEL, EDGE, 1, 12, 24))
	center.add_child(card)
	_card_box = VBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 12)
	_card_box.custom_minimum_size = Vector2(600, 0)
	card.add_child(_card_box)


## buttons is a list of [text, signal]; the first is drawn as the main choice.
func _show_card(title: String, bbcode: String, buttons: Array) -> void:
	for c in _card_box.get_children():
		_card_box.remove_child(c)
		c.queue_free()
	var h := Label.new()
	h.text = title
	h.add_theme_font_override("font", display_font)
	h.add_theme_font_size_override("font_size", 48)
	h.add_theme_color_override("font_color", GOLD)
	_card_box.add_child(h)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.text = bbcode
	rt.custom_minimum_size = Vector2(600, 0)
	_card_box.add_child(rt)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_card_box.add_child(row)
	for i in buttons.size():
		var b := Button.new()
		b.text = buttons[i][0]
		b.custom_minimum_size = Vector2(0, 52)
		if i == 0:
			b.add_theme_stylebox_override("normal", _box(Color("5a2414"), EMBER, 4, 8, 20))
			b.add_theme_stylebox_override("hover", _box(Color("6e2c18"), EMBER, 4, 8, 20))
		b.pressed.connect(_on_card_button.bind(buttons[i][1]))
		row.add_child(b)
	_overlay.size = size
	_overlay.visible = true


func _on_card_button(sig: Signal) -> void:
	_overlay.visible = false
	sig.emit()


## The start card: the goal, the lair's best rating and its night mission.
## best_score and night_score are the player's best scores (0 for none). The world best arrives later,
## from the online leaderboard, through show_world_best().
func show_intro(level: Level, number: int, best_rank: String, night_open := false, night_best := "",
		best_score := 0, night_score := 0, long_best := -1) -> void:
	var txt := "[b]Guard the gems!!![/b]\n\n"
	txt += "[color=#a8977c]Lair %d · %d waves[/color]" % [number, level.waves.size()]
	if best_rank != "":
		txt += "   [color=#e8b84a]Best: %s%s[/color]" % [best_rank, " · %s" % _thousands(best_score) if best_score > 0 else ""]
	var buttons := [["Defend the hoard", start_pressed]]
	if night_open:
		txt += "\n\n[color=#9fb4ff][b]Night mission unlocked.[/b] Same lair in darkness: build only where you can see. Earns its own stars.[/color]"
		if night_best != "":
			txt += "   [color=#e8b84a]Night best: %s%s[/color]" % [night_best, " · %s" % _thousands(night_score) if night_score > 0 else ""]
		buttons.append(["Night mission", night_pressed])
	else:
		txt += "\n[color=#6f7aa8]Clear it Brilliant to unlock its night mission.[/color]"
	if long_best >= 0:   # won by day: the Long Night is open
		txt += "\n\n[color=#c9a0ff][b]The Long Night.[/b] Endless waves with your own Dark Arts, until the hoard falls. Its own leaderboard.[/color]"
		if long_best > 0:
			txt += "   [color=#e8b84a]Best: %d waves held[/color]" % GameSim.long_waves(long_best)
		buttons.append(["Long Night", long_pressed])
	buttons.append(["Map", map_pressed])
	_show_card(level.title, txt, buttons)
	_intro_lair = level.id
	_world = RichTextLabel.new()
	_world.bbcode_enabled = true
	_world.fit_content = true
	_world.scroll_active = false
	_world.visible = false
	_card_box.add_child(_world)
	_card_box.move_child(_world, 2)   # under the text, above the buttons


## The world's best scores for the lair on the start card (from Online.top), if it is still shown:
## day and night are [name, score] or [] when nobody has one.
func show_world_best(level_id: String, day: Array, night: Array) -> void:
	if level_id != _intro_lair or not is_instance_valid(_world) or not _overlay.visible:
		return
	var parts := []
	if not day.is_empty():
		parts.append("%s  [color=#a8977c](%s)[/color]" % [_thousands(int(day[1])), str(day[0]).xml_escape()])
	if not night.is_empty():
		parts.append("night %s  [color=#a8977c](%s)[/color]" % [_thousands(int(night[1])), str(night[0]).xml_escape()])
	if parts.is_empty():
		return
	_world.text = "[color=#c9c0ff]World best: %s[/color]" % "   ".join(parts)
	_world.visible = true


## The lair being played, in the top bar: "46 · Pilgrim's Flood", with "(night)" on night missions.
func set_lair(number: int, title: String, night := false, long_night := false) -> void:
	_brand.text = "%d · %s%s" % [number, title, " (Long Night)" if long_night else " (night)" if night else ""]
	_brand.tooltip_text = _brand.text


## The end of a Long Night: how many waves were held, against the lair's best until now
## (GameSim.long_score values); earned lists new achievement ids.
func show_long_end(sim: GameSim, best_before: int, earned_ach: Array[String] = []) -> void:
	var txt := "The night swallowed the hoard in wave %d.\n\n" % sim.wave
	txt += "Held: [b][color=#e8b84a]%d wave%s[/color][/b]   [color=#a8977c]%s heroes slain[/color]" % [sim.cleared, "" if sim.cleared == 1 else "s", _thousands(sim.kills)]
	if sim.long_score() > best_before and best_before > 0:
		txt += "\n[color=#e2683a]New best for this lair's Long Night![/color]"
	elif best_before > 0:
		txt += "\n[color=#a8977c]Best: %d waves held[/color]" % GameSim.long_waves(best_before)
	for id in earned_ach.slice(0, ACH_ON_CARD):
		var a := Achievements.find(id)
		txt += "\n[b][color=#c9c0ff]★ Achievement: %s[/color][/b] [color=#a8977c]%s[/color]" % [a["name"], a["text"]]
	if earned_ach.size() > ACH_ON_CARD:
		txt += "\n[b][color=#c9c0ff]★ +%d more in the Hall of Fame[/color][/b]" % (earned_ach.size() - ACH_ON_CARD)
	_show_card("Dawn never came", txt, [["Play again", restart_pressed], ["Map", map_pressed]])


## score is this battle's (GameSim.score), best_before the mission's best until now; earned lists new
## achievement ids.
func show_end(sim: GameSim, has_next: bool, new_best: bool, new_stars := 0, free_points := 0, night_opened := false,
		score := 0, best_before := 0, earned_ach: Array[String] = [], finale := false) -> void:
	var txt := ""
	if finale:   # the last lair of the campaign is won
		txt = "[b]The Seraph has fallen and the last of the heroes are gone. Every road to your hoard lies quiet: the realm is yours, dark lord.[/b]
[color=#a8977c]Stars and night missions you missed still wait on the map.[/color]

"
	if not sim.won:
		txt = "Heroes carried off every gem by wave %d.\n\n" % sim.wave
	var earned := maxi(0, SaveData.RANKS.find(sim.rank()))
	txt += "Rating: [b][color=#e8b84a]%s  %s[/color][/b][color=#5b4630]%s[/color]" % [sim.rank(), "★".repeat(earned), "★".repeat(3 - earned)]
	match sim.rank():
		"Survived":
			txt += "   [color=#a8977c]Lose no gems for Wicked.[/color]"
		"Wicked":
			txt += "   [color=#a8977c]Let no hero touch a gem for Brilliant.[/color]"
	if sim.won:
		txt += "\nScore: [b][color=#e8b84a]%s[/color][/b]" % _thousands(score)
		if not sim.race_on and sim.threat > 1.0:
			txt += "   [color=#e2683a]×%.2f Resolve[/color]" % sim.threat
		if score > best_before and best_before > 0:
			txt += "   [color=#e2683a]New high score![/color]"
		elif best_before > score:
			txt += "   [color=#a8977c]Best: %s[/color]" % _thousands(best_before)
	if night_opened:
		txt += "\n[b][color=#9fb4ff]Night mission unlocked for this lair![/color][/b]"
	if new_best:
		txt += "\n[color=#e2683a]New best for this lair. Progress saved.[/color]"
	if new_stars > 0:
		txt += "\n[b][color=#e8b84a]+%d star%s! You have %d skill point%s to spend in Dark Arts on the map.[/color][/b]" % [new_stars, "" if new_stars == 1 else "s", free_points, "" if free_points == 1 else "s"]
	for id in earned_ach.slice(0, ACH_ON_CARD):
		var a := Achievements.find(id)
		txt += "\n[b][color=#c9c0ff]★ Achievement: %s[/color][/b] [color=#a8977c]%s[/color]" % [a["name"], a["text"]]
	if earned_ach.size() > ACH_ON_CARD:
		txt += "\n[b][color=#c9c0ff]★ +%d more in the Hall of Fame[/color][/b]" % (earned_ach.size() - ACH_ON_CARD)
	var buttons := []
	if sim.won and has_next:
		buttons.append(["Next lair", next_level_pressed])
	buttons.append(["Play again", restart_pressed])
	buttons.append(["Map", map_pressed])
	_show_card("The realm is yours" if finale else "The hoard holds" if sim.won else "The hoard is empty", txt, buttons)
	if sim.won and Ads.enabled() and Ads.rewarded_ready() and Ads.ad_free_wins() == 0:
		_add_reward_button()


## Android Play build: an optional rewarded ad under the win card's buttons that buys a break
## from ads (Ads.REWARD_WINS wins). Left out when the card would not fit the screen.
func _add_reward_button() -> void:
	var b := Button.new()
	b.text = "Watch an ad: no ads for %d wins" % Ads.REWARD_WINS
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 40)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", DIM)
	b.pressed.connect(func() -> void:
		b.disabled = true
		Ads.show_rewarded(func(earned: bool) -> void:
			if not is_instance_valid(b):
				return
			if earned:
				b.text = "No ads for the next %d wins" % Ads.REWARD_WINS
			else:
				b.disabled = not Ads.rewarded_ready()))
	_card_box.add_child(b)
	var card := _card_box.get_parent() as Control
	(func() -> void:   # once the card is laid out (the text's height depends on its width)
		if is_instance_valid(b) and card.get_combined_minimum_size().y > _overlay.size.y:
			b.queue_free()).call_deferred()   # keep the card's own buttons on a small screen


## The rival's badge in the map's top-left corner during an online race (Online.race_progress);
## "" hides it.
func set_rival(rival_name: String, p: Dictionary = {}) -> void:
	_rival_box.visible = rival_name != ""
	_send.visible = _rival_box.visible     # in a race, Send takes Pause's place: pausing would
	_pause.visible = not _rival_box.visible   # only lose time on the race clock
	_restart.visible = not _rival_box.visible
	if not _rival_box.visible:
		return
	if p.get("done", false):
		_rival.text = "%s: %s" % [rival_name, "survived" if p.get("won", false) else "fell at wave %d" % p.get("wave", 0)]
	else:
		_rival.text = "%s: wave %d · %d gems" % [rival_name, p.get("wave", 0), p.get("gems", 0)]
	_rival_box.reset_size()
	_rival_box.position = map_area.position + Vector2(8, 8)


## The Send menu: every hero kind of this lair with its price; the ones you can't afford are greyed.
func _open_send() -> void:
	if _sim == null or _sim.over:
		return
	_send_menu.clear()
	_send_kinds = _sim.race_shop()
	for code in _send_kinds:
		var cost := GameSim.race_cost(code)
		_send_menu.add_item("%s  ·  %d gold" % [Defs.ENEMIES[code]["name"], cost])
		_send_menu.set_item_disabled(_send_menu.item_count - 1, _sim.gold < cost)
	var r := _send.get_global_rect()
	_send_menu.reset_size()
	var at := Vector2(r.position.x - _send_menu.size.x - 8, r.position.y) if side else Vector2(r.position.x, r.position.y - _send_menu.size.y - 8)
	_send_menu.popup(Rect2i(Vector2i(at), Vector2i.ZERO))


## The end card of an online race. me and rival are Online.race_progress records; while the rival
## is still playing, the card says so and is shown again when they finish.
func show_race_end(me: Dictionary, rival: Dictionary, rival_name: String) -> void:
	var line := func(who: String, p: Dictionary, other: Dictionary) -> String:
		if not p.get("done", false):
			return "%s: [color=#a8977c]still playing, wave %d · %d gems · %d kills[/color]" % [who, p.get("wave", 0), p.get("gems", 0), p.get("kills", 0)]
		var n := str(p.get("out", "")).length()
		var sent := "  ·  sent %d hero%s" % [n, "" if n == 1 else "es"] if n > 0 else ""
		if not p.get("won", false):
			if p.get("stopped", false):
				return "%s: [color=#a8977c]stopped at wave %d[/color] with %d gems · %d kills%s" % [who, p.get("wave", 0), p.get("gems", 0), p.get("kills", 0), sent]
			return "%s: [color=#e2683a]fell at wave %d[/color] · %d kills%s" % [who, p.get("wave", 0), p.get("kills", 0), sent]
		var t := "%s: [b][color=#e8b84a]survived[/color][/b] in %s with %d gems · %d kills%s\n      score %s" % [who, _clock(int(p.get("time", 0))),
			p.get("gems", 0), p.get("kills", 0), sent, _thousands(int(p.get("score", 0)))]
		var pts := Online.race_points(p, other)
		if pts > int(p.get("score", 0)):
			t += " + %s for finishing %s sooner" % [_thousands(pts - int(p.get("score", 0))), _clock(int(other.get("time", 0)) - int(p.get("time", 0)))]
		if other.get("done", false) and other.get("won", false):
			t += " = [b]%s[/b] race points" % _thousands(pts)
		return t
	var txt: String = line.call("You", me, rival) + "\n" + line.call(rival_name, rival, me)
	var title := "Waiting for %s…" % rival_name
	if rival.get("done", false):
		match Online.race_compare(me, rival):
			1:
				title = "You win the race!"
			-1:
				title = "%s wins the race" % rival_name
			_:
				title = "A draw!"
	_show_card(title, txt, [["Map", map_pressed]])


## 125 seconds as "2:05".
static func _clock(s: int) -> String:
	return "%d:%02d" % [s / 60, s % 60]


## Small drawn icons for the stats bar.
class StatIcon extends Control:
	var kind := "coin"

	func _draw() -> void:
		var c := size / 2.0
		var k := size.x / 20.0   # drawn for 20 px, scaled to the icon size
		match kind:
			"coin":
				draw_circle(c, 9 * k, Color("e8b84a"))
				draw_arc(c, 9 * k, 0, TAU, 20, Color("8a6420"), 1.5 * k, true)
				draw_circle(c, 4 * k, Color("c9952e"))
			"drop":
				var pts := PackedVector2Array([c + Vector2(0, -9) * k])
				for i in 13:
					var a := -0.15 * PI + 1.3 * PI * i / 12.0
					pts.append(c + (Vector2(0, 3) + Vector2(cos(a), sin(a)) * 6.0) * k)
				draw_colored_polygon(pts, Color("7e6cf0"))
			"gem":
				Paint.gem(self, c, 9 * k)


## 12345 as "12,345".
static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## A building's cuts as a row of blocks: the ones already made filled gold, the ones still to
## make dark with a violet rim.
class CutBar extends Control:
	var left := 0
	var total := 1

	func _draw() -> void:
		var w := (size.x - (total - 1) * 6.0) / total
		for i in total:
			var r := Rect2(i * (w + 6.0), 0, w, size.y)
			var done := i < total - left
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(6)
			sb.bg_color = Color("e8b84a") if done else Color("1c160f")
			sb.border_color = Color("8a6420") if done else Color("c9c0ff")
			sb.set_border_width_all(3)
			draw_style_box(sb, r)


## The tide clock: a dial whose blue arc is high tide; the hand shows where the tide is now.
class TideClock extends Control:
	var phase := 0.0   # 0..1 through the tide's period
	var high := 0.3    # the share of the period the water is up (at the end of each period)
	var arc := Color("5aa0d0")   # blue for high tide, violet for an eclipse's darkness

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 2.0
		draw_circle(c, r, Color("1c160f"))
		draw_arc(c, r - 3.0, -PI / 2 + TAU * (1.0 - high), -PI / 2 + TAU, 20, arc, 5.0, true)
		draw_arc(c, r, 0, TAU, 28, Color("8a6420"), 2.0, true)
		var a := -PI / 2 + TAU * phase
		draw_line(c, c + Vector2(cos(a), sin(a)) * (r - 2.0), Color("efe4cc"), 2.5, true)
