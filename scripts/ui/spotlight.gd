extends Control
## The tutorial's spotlight: darkens the whole screen except one lit hole around the thing to tap,
## with the tip in a panel beside it. Taps inside the hole go through to the game (the map, a
## HUD button, a panel button); everywhere else they are blocked, so the player does exactly
## that one thing. Tips with nothing to tap get a "Got it" button instead.

signal ok_pressed
signal skip_pressed

const Hud := preload("res://scripts/ui/hud.gd")
const DIM := Color(0.02, 0.015, 0.01, 0.72)
const PAD := 6.0

var hole := Rect2()           # in this control's coordinates; empty means no hole
var _panel: PanelContainer
var _text: RichTextLabel
var _ok: Button
var _skip: Button
var _key := ""                # what is showing, so the panel is rebuilt only on change


func setup(hud: Control) -> void:
	theme = hud.theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", hud._box(Hud.PANEL, Hud.GOLD, 2, 12, 18))
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in ["normal_font_size", "bold_font_size"]:
		_text.add_theme_font_size_override(k, 26)
	box.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_ok = Button.new()
	_ok.text = "Got it"
	_ok.focus_mode = Control.FOCUS_NONE
	_ok.custom_minimum_size = Vector2(140, 60)
	_ok.add_theme_font_size_override("font_size", 26)
	_ok.add_theme_stylebox_override("normal", hud._box(Color("5a2414"), Hud.EMBER, 4, 8, 20))
	_ok.pressed.connect(func() -> void: ok_pressed.emit())
	row.add_child(_ok)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	_skip = Button.new()
	_skip.text = "Skip tutorial"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.add_theme_font_size_override("font_size", 22)
	_skip.add_theme_color_override("font_color", Hud.DIM)
	_skip.pressed.connect(func() -> void: skip_pressed.emit())
	row.add_child(_skip)


## Shows a tip (BBCode) with the hole over target (screen rect, may be empty). ok: show "Got it".
func show_tip(text: String, target: Rect2, ok: bool) -> void:
	hole = target.grow(PAD) if target.has_area() else Rect2()
	var key := text + str(ok)
	if key != _key or not visible:
		_key = key
		_text.text = text
		_ok.visible = ok
		var w := minf(760.0, size.x - 32.0)
		_text.custom_minimum_size = Vector2(w - 40.0, 0)
	visible = true
	_panel.reset_size()
	# Keep the panel clear of the hole and what is around it (a tile's panel opens next to the
	# tile): at the far edge of the screen from the hole, or mid-screen if there is no hole.
	var ps := _panel.size
	var x := clampf((hole.get_center().x if hole.has_area() else size.x / 2.0) - ps.x / 2.0, 16.0, size.x - ps.x - 16.0)
	var y := (size.y - ps.y) / 2.0
	if hole.has_area():
		y = size.y - ps.y - 12.0 if hole.get_center().y < size.y / 2.0 else 12.0
	_panel.position = Vector2(x, y)
	queue_redraw()


func hide_tip() -> void:
	visible = false
	_key = ""


## Taps inside the hole are not ours, so they reach whatever is underneath.
func _has_point(p: Vector2) -> bool:
	return not (hole.has_area() and hole.has_point(p))


func _process(_dt: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if not hole.has_area():
		draw_rect(Rect2(Vector2.ZERO, size), DIM)
		return
	var h := hole
	draw_rect(Rect2(0, 0, size.x, h.position.y), DIM)
	draw_rect(Rect2(0, h.end.y, size.x, size.y - h.end.y), DIM)
	draw_rect(Rect2(0, h.position.y, h.position.x, h.size.y), DIM)
	draw_rect(Rect2(h.end.x, h.position.y, size.x - h.end.x, h.size.y), DIM)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
	draw_rect(h.grow(2.0 + 3.0 * pulse), Color(Hud.GOLD, 0.5 + 0.5 * pulse), false, 3.0)
