class_name SoundWindow
extends Control
## The Settings window: a slider for effects and one for music, the screen shake and frame rate
## switches, Graphics (Quality: Auto, Detailed, Light) and, with a keyboard, the battle shortcuts (Keys),
## opened from the Settings button on the map and in battle. A full-screen page (Screens.page); Back
## shuts it. In a battle (not a race) the battle waits while it is open. Changes apply and save at once.

const Hud := preload("res://scripts/ui/hud.gd")

var _capture := ""        # the shortcut waiting for its new key ("" when none is)
var _key_buttons := {}    # action -> its button in the Keyboard section


## Opens the window over `host` (the HUD in battle, the map on the map).
static func open(hud: Control, host: Control) -> SoundWindow:
	for w in host.get_tree().get_nodes_in_group("sound_window"):
		w.queue_free()
	var w := SoundWindow.new()
	w._build(hud)
	host.add_child(w)
	return w


## Closes any open Sound window; true if there was one (the Android back button uses this).
static func close_any(tree: SceneTree) -> bool:
	var open := tree.get_nodes_in_group("sound_window")
	for w in open:
		w.queue_free()
	return not open.is_empty()


func _build(hud: Control) -> void:
	add_to_group("sound_window")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := Screens.page(self, hud, "Settings", "Back", queue_free)
	_row(hud, box, "Effects", Sfx.sfx_volume(), func(v: float, done: bool) -> void:
		Sfx.set_sfx_volume(v)
		if done:
			Sfx.play("coin"))   # a sample at the new level
	_row(hud, box, "Music", Sfx.music_volume(), func(v: float, done: bool) -> void:
		Sfx.set_music_volume(v, done))
	var shake := CheckButton.new()
	shake.text = "Screen shake"
	shake.button_pressed = Prefs.get_value("shake", true)
	shake.focus_mode = Control.FOCUS_NONE
	shake.add_theme_font_override("font", hud.bold_font)
	shake.add_theme_font_size_override("font_size", 30)
	shake.custom_minimum_size = Vector2(0, 60)
	shake.toggled.connect(func(on: bool) -> void: Prefs.set_value("shake", on))
	var toggles := HBoxContainer.new()   # screen shake and the frame rate share a row
	toggles.add_theme_constant_override("separation", 12)
	box.add_child(toggles)
	shake.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggles.add_child(shake)
	var fps := CheckButton.new()
	fps.text = "Show frame rate"
	fps.button_pressed = Prefs.get_value("show_fps", false)
	fps.focus_mode = Control.FOCUS_NONE
	fps.add_theme_font_override("font", hud.bold_font)
	fps.add_theme_font_size_override("font_size", 30)
	fps.custom_minimum_size = Vector2(0, 60)
	fps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fps.toggled.connect(func(on: bool) -> void: Prefs.set_value("show_fps", on))
	toggles.add_child(fps)
	var loot := CheckButton.new()   # GameSim.auto_loot: wave starts gather the coins and potions left lying around
	loot.text = "Gather loot by itself"
	loot.button_pressed = bool(Prefs.get_value("auto_loot", true))
	loot.focus_mode = Control.FOCUS_NONE
	loot.add_theme_font_override("font", hud.bold_font)
	loot.add_theme_font_size_override("font_size", 30)
	loot.custom_minimum_size = Vector2(0, 60)
	loot.toggled.connect(func(on: bool) -> void: Prefs.set_value("auto_loot", on))
	box.add_child(loot)
	var loot_note := Label.new()
	loot_note.text = "On: coins and potions still lying around are picked up when the next wave starts. Off: only what you tap is picked up."
	loot_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loot_note.add_theme_font_size_override("font_size", 20)
	loot_note.add_theme_color_override("font_color", Hud.DIM)
	box.add_child(loot_note)
	var rep := CheckButton.new()   # battle reports for balance (BattleReport): on unless turned off
	rep.text = "Share battle reports"
	rep.button_pressed = BattleReport.enabled()
	rep.focus_mode = Control.FOCUS_NONE
	rep.add_theme_font_override("font", hud.bold_font)
	rep.add_theme_font_size_override("font_size", 30)
	rep.custom_minimum_size = Vector2(0, 60)
	rep.toggled.connect(func(on: bool) -> void: Prefs.set_value(BattleReport.PREF, on))
	box.add_child(rep)
	var rep_note := Label.new()
	rep_note.text = "After each battle the game sends how it went (waves, gems lost, towers, skills) to help balance the lairs. No name, account or personal data."
	rep_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rep_note.add_theme_font_size_override("font_size", 20)
	rep_note.add_theme_color_override("font_color", Hud.DIM)
	box.add_child(rep_note)
	_build_graphics(hud, box)
	if Keys.available():
		_build_keys(hud, box)
	if Ads.enabled() and Ads.privacy_options_required():   # Android Play build, where the law asks for it
		var privacy := Button.new()
		privacy.text = "Privacy choices"
		privacy.focus_mode = Control.FOCUS_NONE
		privacy.custom_minimum_size = Vector2(0, 52)
		privacy.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		privacy.add_theme_font_size_override("font_size", 24)
		privacy.pressed.connect(func() -> void:
			queue_free()
			Ads.show_privacy_options())
		box.add_child(privacy)


## Graphics: Auto (Detailed on a computer, Light on a phone, and Light if battles run slow),
## Detailed or Light (Quality). Applies at once.
func _build_graphics(hud: Control, box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var name_l := Label.new()
	name_l.text = "Graphics"
	name_l.custom_minimum_size = Vector2(130, 0)
	name_l.add_theme_font_override("font", hud.bold_font)
	name_l.add_theme_font_size_override("font_size", 30)
	row.add_child(name_l)
	var group := ButtonGroup.new()
	var buttons := {}
	for c: String in Quality.CHOICES:
		var b := Button.new()
		b.text = c.capitalize()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = Quality.choice() == c
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(150, 52)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(func() -> void:
			Quality.set_choice(c)
			_show_graphics(buttons))
		row.add_child(b)
		buttons[c] = b
	_show_graphics(buttons)


## The chosen setting in gold; Auto also says what it picked.
func _show_graphics(buttons: Dictionary) -> void:
	for c: String in buttons:
		var b: Button = buttons[c]
		var on := Quality.choice() == c
		b.text = c.capitalize()
		if c == Quality.AUTO and on:
			b.text = "Auto: " + ("Light" if Quality.light() else "Detailed")
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(k, Hud.GOLD if on else Hud.BONE)


## The Keyboard section: one button per shortcut showing its key. Click it, then press the new key
## (Esc keeps the old one). A key another shortcut uses swaps with it.
func _build_keys(hud: Control, box: VBoxContainer) -> void:
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := Label.new()
	title.text = "Keyboard"
	title.add_theme_font_override("font", hud.bold_font)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Hud.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var reset := Button.new()
	reset.text = "Default keys"
	reset.focus_mode = Control.FOCUS_NONE
	reset.add_theme_font_size_override("font_size", 22)
	reset.add_theme_color_override("font_color", Hud.DIM)
	reset.pressed.connect(func() -> void:
		_capture = ""
		Keys.reset()
		_show_keys())
	head.add_child(reset)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for a: Array in Keys.ACTIONS:
		var l := Label.new()
		l.text = a[1]
		l.add_theme_font_size_override("font_size", 26)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(170, 52)
		b.add_theme_font_size_override("font_size", 26)
		var action: String = a[0]
		b.pressed.connect(func() -> void:
			_capture = "" if _capture == action else action
			_show_keys())
		grid.add_child(b)
		_key_buttons[action] = b
	_show_keys()


func _show_keys() -> void:
	for action: String in _key_buttons:
		var b: Button = _key_buttons[action]
		var waiting := action == _capture
		b.text = "Press a key…" if waiting else Keys.name_of(action)
		b.add_theme_color_override("font_color", Hud.EMBER if waiting else Hud.BONE)


## While a shortcut waits for its key, the next key press is that key (Esc cancels).
func _input(e: InputEvent) -> void:
	if _capture == "" or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	get_viewport().set_input_as_handled()
	if e.keycode != KEY_ESCAPE:
		Keys.assign(_capture, Keys.code_of(e))
		Sfx.play("click")
	_capture = ""
	_show_keys()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()


## A labelled slider (0–100 %) with its value shown on the right.
func _row(hud: Control, box: VBoxContainer, title: String, value: float, changed: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	var name_l := Label.new()
	name_l.text = title
	name_l.custom_minimum_size = Vector2(130, 0)
	name_l.add_theme_font_override("font", hud.bold_font)
	name_l.add_theme_font_size_override("font_size", 30)
	row.add_child(name_l)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.value = roundf(value * 100.0)
	s.focus_mode = Control.FOCUS_NONE
	s.custom_minimum_size = Vector2(440, 56)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_slider(s)
	row.add_child(s)
	var pct := Label.new()
	pct.custom_minimum_size = Vector2(110, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.add_theme_font_override("font", hud.bold_font)
	pct.add_theme_font_size_override("font_size", 30)
	row.add_child(pct)
	var show := func(v: float) -> void:
		pct.text = "Off" if v <= 0.0 else "%d%%" % int(v)
		pct.add_theme_color_override("font_color", Hud.DIM if v <= 0.0 else Hud.BONE)
	show.call(s.value)
	s.value_changed.connect(func(v: float) -> void:
		show.call(v)
		changed.call(v / 100.0, false))
	s.drag_ended.connect(func(_c: bool) -> void: changed.call(s.value / 100.0, true))


## A thick track and a big round grabber, easy to hit on a phone.
func _style_slider(s: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color("1a140e")
	track.border_color = Hud.EDGE
	track.set_border_width_all(2)
	track.set_corner_radius_all(8)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(Hud.GOLD, 0.85)
	fill.set_corner_radius_all(8)
	fill.content_margin_top = 8
	fill.content_margin_bottom = 8
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _knob(36, Hud.BONE)
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", _knob(36, Color.WHITE))


func _knob(d: int, col: Color) -> Texture2D:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := (d - 1) / 2.0
	for y in d:
		for x in d:
			var r := Vector2(x - c, y - c).length()
			var a := clampf(c - r + 0.5, 0.0, 1.0)
			var edge := r > c - 3.0
			img.set_pixel(x, y, Color(Color("5a3a10") if edge else col, a))
	return ImageTexture.create_from_image(img)
