class_name SoundWindow
extends Control
## The Sound window: a slider for effects and one for music, opened from the Sound button on
## the map and in battle. Covers its host with a dim backdrop; tapping outside the card or
## Close shuts it. Changes apply and save at once.

const Hud := preload("res://scripts/ui/hud.gd")


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
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			queue_free())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", hud._box(Hud.PANEL, Hud.GOLD, 2, 12, 28))
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	card.add_child(box)
	var h := Label.new()
	h.text = "Sound"
	h.add_theme_font_override("font", hud.display_font)
	h.add_theme_font_size_override("font_size", 44)
	h.add_theme_color_override("font_color", Hud.GOLD)
	box.add_child(h)
	_row(hud, box, "Effects", Sfx.sfx_volume(), func(v: float, done: bool) -> void:
		Sfx.set_sfx_volume(v)
		if done:
			Sfx.play("coin"))   # a sample at the new level
	_row(hud, box, "Music", Sfx.music_volume(), func(v: float, done: bool) -> void:
		Sfx.set_music_volume(v, done))
	var close := Button.new()
	close.text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(180, 60)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.add_theme_font_size_override("font_size", 26)
	close.pressed.connect(queue_free)
	box.add_child(close)


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
