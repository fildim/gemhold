extends Control
## Everything drawn over the map: the top stats bar, spell buttons, the tile panel,
## messages and the start/end screens. Builds its own nodes in code.

signal next_wave_pressed
signal meteor_pressed
signal speed_pressed
signal pause_pressed
signal action_pressed(id: String)
signal popup_closed
signal start_pressed
signal restart_pressed
signal next_level_pressed
signal night_pressed
signal map_pressed
signal hint_closed

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
var _next: Button
var _meteor: Button
var _speed: Button
var _pause: Button
var _popup: PanelContainer
var _popup_box: VBoxContainer
var _popup_actions: Array = []   # [{button, gold, mana}]
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _overlay: Control
var _card_box: VBoxContainer
var _sound: Button
var _hint: PanelContainer
var _hint_text: RichTextLabel


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
	_build_hint()
	_build_overlay()
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
	t.default_font_size = 19
	t.set_color("font_color", "Label", BONE)
	t.set_color("default_color", "RichTextLabel", BONE)
	t.set_font("bold_font", "RichTextLabel", bold_font)
	t.set_font("normal_font", "RichTextLabel", body_font)
	t.set_font_size("normal_font_size", "RichTextLabel", 19)
	t.set_font_size("bold_font_size", "RichTextLabel", 19)
	t.set_font("font", "Button", bold_font)
	t.set_font_size("font_size", "Button", 19)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", BONE)
	t.set_color("font_disabled_color", "Button", Color(BONE, 0.4))
	t.set_stylebox("normal", "Button", _box(PANEL_2, Color("5b4630"), 4, 8, 14))
	t.set_stylebox("hover", "Button", _box(Color("3a2e22"), Color("7a5e40"), 4, 8, 14))
	t.set_stylebox("pressed", "Button", _box(Color("1c160f"), Color("5b4630"), 1, 8, 14))
	t.set_stylebox("disabled", "Button", _box(Color(PANEL_2, 0.5), Color(Color("5b4630"), 0.4), 4, 8, 14))
	var focus := _box(Color(0, 0, 0, 0), GOLD, 2, 8, 14)
	focus.set_border_width_all(2)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, EDGE, 1, 10, 12))
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
	row.add_child(brand)
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
	_wave = Label.new()
	_wave.add_theme_font_override("font", bold_font)
	row.add_child(_wave)

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
	_meteor = _button(brow, "Meteor 60", meteor_pressed)
	_speed = _button(brow, "1×", speed_pressed)
	_pause = _button(brow, "Pause", pause_pressed)
	_sound = sound_button(brow)
	_button(brow, "Map", map_pressed)
	for b in [_meteor]:
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
	ic.custom_minimum_size = Vector2(20, 20)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return ic


## Sound on -> Music off -> Muted. Also used on the level map.
func sound_button(parent: Control) -> Button:
	var b := Button.new()
	b.text = Sfx.label()
	b.custom_minimum_size = Vector2(0, 48)
	b.focus_mode = Control.FOCUS_NONE
	b.add_to_group("sound_buttons")
	b.pressed.connect(func() -> void:
		Sfx.cycle()
		refresh_sound())
	parent.add_child(b)
	return b


## Updates every sound button's label (the map has one too).
func refresh_sound() -> void:
	get_tree().call_group("sound_buttons", "set_text", Sfx.label())


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
	if not on:
		_overlay.visible = false
		_hint.visible = false
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
	_gold.text = str(sim.gold)
	_mana.text = str(int(sim.mana))
	_mana_bar.max_value = sim.mana_max
	_mana_bar.value = sim.mana
	_gems.text = "%d/%d" % [sim.gems_left(), sim.level.gems]
	_wave.text = "Wave %d/%d  ·  Threat ×%.1f" % [sim.wave, sim.level.waves.size(), sim.threat]
	if sim.wave < sim.level.waves.size():
		var s := int(ceil(sim.timer))
		_next.disabled = false
		_next.text = "%s %ds (+%dg)" % ["Next wave" if sim.wave > 0 else "First wave", s, s]
	else:
		_next.disabled = true
		_next.text = "Final wave"
	_meteor.disabled = not sim.can_meteor() and not armed
	_meteor.text = "Cancel meteor" if armed else "Meteor %d" % Defs.METEOR["cost"]
	_speed.text = "%d×" % speed
	_pause.text = "Resume" if paused else "Pause"
	for a in _popup_actions:
		var short: bool = (a["gold"] > 0 and sim.gold < a["gold"]) or (a["mana"] > 0 and sim.mana < a["mana"])
		var col := POOR if short else BONE
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			a["button"].add_theme_color_override(c, col)


# ---------------------------------------------------------------- tile panel

func _build_popup() -> void:
	_popup = PanelContainer.new()
	_popup.visible = false
	_popup.custom_minimum_size = Vector2(250, 0)
	add_child(_popup)
	_popup_box = VBoxContainer.new()
	_popup_box.add_theme_constant_override("separation", 8)
	_popup.add_child(_popup_box)


func popup_open() -> bool:
	return _popup.visible


## anchor is the selected tile's rectangle in screen coordinates.
func show_popup(info: Dictionary, anchor: Rect2) -> void:
	for c in _popup_box.get_children():
		_popup_box.remove_child(c)   # now, so the panel can shrink to the new contents
		c.queue_free()
	_popup_actions.clear()
	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = info["title"]
	title.add_theme_font_override("font", display_font)
	title.add_theme_font_size_override("font_size", 26)
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
	text.custom_minimum_size = Vector2(230, 0)
	text.add_theme_color_override("font_color", DIM)
	text.add_theme_font_override("font", body_font)
	_popup_box.add_child(text)
	for a in info["actions"]:
		var b := Button.new()
		if a["id"] == "sell":
			_add_sell_button(b, a)
			continue
		b.text = "%s    %s" % [a["label"], a["price"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 46)
		var id: String = a["id"]
		b.pressed.connect(func() -> void: action_pressed.emit(id))
		_popup_box.add_child(b)
		_popup_actions.append({"button": b, "gold": int(a.get("gold", 0)), "mana": int(a.get("mana", 0))})
	_popup.visible = true
	_popup.reset_size()
	var ps := _popup.get_combined_minimum_size()
	var p := Vector2(anchor.end.x + 6, anchor.position.y)
	if p.x + ps.x > map_area.end.x:
		p.x = anchor.position.x - ps.x - 6
	p.x = clampf(p.x, map_area.position.x, map_area.end.x - ps.x)
	p.y = clampf(p.y, map_area.position.y, map_area.end.y - ps.y)
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


func toast(msg: String) -> void:
	_toast_label.text = msg
	_toast.reset_size()
	_toast.position = Vector2(map_area.position.x + (map_area.size.x - _toast.size.x) / 2.0, map_area.position.y + 10)
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast.modulate.a = 1.0
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.3)


## The tutorial's tip panel, along the bottom of the map. Taps go through it to the map,
## except on its × button.
func _build_hint() -> void:
	_hint = PanelContainer.new()
	_hint.add_theme_stylebox_override("panel", _box(Color(PANEL, 0.94), GOLD, 1, 10, 14))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_child(row)
	_hint_text = RichTextLabel.new()
	_hint_text.bbcode_enabled = true
	_hint_text.fit_content = true
	_hint_text.scroll_active = false
	_hint_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_text.custom_minimum_size = Vector2(300, 0)
	row.add_child(_hint_text)
	var close := Button.new()
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(44, 40)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.add_theme_font_size_override("font_size", 24)
	close.pressed.connect(func() -> void: hint_closed.emit())
	row.add_child(close)
	add_child(_hint)


## Shows a tutorial tip (BBCode), or hides the panel for "".
func show_hint(bbcode: String) -> void:
	if bbcode == "":
		_hint.visible = false
		return
	if not _hint.visible or _hint_text.text != bbcode:
		_hint_text.text = bbcode
		var w := minf(620.0, map_area.size.x - 20.0)
		_hint.custom_minimum_size = Vector2(w, 0)
		_hint_text.custom_minimum_size = Vector2(w - 90.0, 0)
		_hint.visible = true
	_hint.reset_size()   # every frame: the text's height settles a frame after it changes
	_hint.position = Vector2(map_area.position.x + (map_area.size.x - _hint.size.x) / 2.0,
		map_area.end.y - _hint.size.y - 8.0)


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
	_card_box.custom_minimum_size = Vector2(520, 0)
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
	rt.custom_minimum_size = Vector2(520, 0)
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


## The first level teaches the rules; later ones show their own story text.
func show_intro(level: Level, number: int, best_rank: String, night_open := false, night_best := "") -> void:
	var txt: String
	if number == 1:
		txt = "You are the dark lord. Self-righteous heroes walk the roads to your cave to steal your %d gems. Keep them.\n\n" % level.gems
		txt += "[b]Each tower needs its own ground.[/b] Warband Huts on green moss, Bone Crypts on frost, Cinder Shrines on ash.\n"
		txt += "[b]Clear woods[/b] with mana to open more building spots and earn gold from the timber.\n"
		txt += "[b]Kill a gem carrier[/b] and the gem floats home. Other heroes can snatch it on the way.\n"
		txt += "[b]Call waves early[/b] for bonus gold. Spend mana on Meteor.\n\n"
	else:
		txt = "%s\n\nGuard all [b]%d gems[/b].\n\n" % [level.intro, level.gems]
	txt += "[color=#a8977c]Lair %d · %s · %d waves[/color]" % [number, level.title, level.waves.size()]
	if best_rank != "":
		txt += "   [color=#e8b84a]Best: %s[/color]" % best_rank
	txt += "\n[color=#a8977c]Stars (your skill points): ★ Survived (gems lost) · ★★ Wicked (none lost, but a hero touched one) · ★★★ Brilliant (no hero touched a gem)[/color]"
	var buttons := [["Defend the hoard", start_pressed]]
	if night_open:
		txt += "\n\n[color=#9fb4ff][b]Night mission unlocked.[/b] Same lair in darkness: build only where you can see. Earns its own stars.[/color]"
		if night_best != "":
			txt += "   [color=#e8b84a]Night best: %s[/color]" % night_best
		buttons.append(["Night mission", night_pressed])
	else:
		txt += "\n[color=#6f7aa8]Clear it Brilliant to unlock its night mission.[/color]"
	buttons.append(["Map", map_pressed])
	_show_card(level.title, txt, buttons)


func show_end(sim: GameSim, has_next: bool, new_best: bool, new_stars := 0, free_points := 0, night_opened := false) -> void:
	var kept := sim.level.gems - sim.lost
	var txt: String
	if sim.won:
		txt = "All %d waves beaten%s. You kept [b]%d of %d[/b] gems.\n\n" % [sim.level.waves.size(), " at night" if sim.level.night else "", kept, sim.level.gems]
	else:
		txt = "Heroes carried off every gem by wave %d.\n\n" % sim.wave
	var earned := maxi(0, SaveData.RANKS.find(sim.rank()))
	txt += "Rating: [b][color=#e8b84a]%s  %s[/color][/b][color=#5b4630]%s[/color]" % [sim.rank(), "★".repeat(earned), "★".repeat(3 - earned)]
	match sim.rank():
		"Survived":
			txt += "   [color=#a8977c]Lose no gems for Wicked.[/color]"
		"Wicked":
			txt += "   [color=#a8977c]Let no hero touch a gem for Brilliant.[/color]"
	if night_opened:
		txt += "\n[b][color=#9fb4ff]Night mission unlocked for this lair![/color][/b]"
	if new_best:
		txt += "\n[color=#e2683a]New best for this lair. Progress saved.[/color]"
	if new_stars > 0:
		txt += "\n[b][color=#e8b84a]+%d star%s! You have %d skill point%s to spend in Dark Arts on the map.[/color][/b]" % [new_stars, "" if new_stars == 1 else "s", free_points, "" if free_points == 1 else "s"]
	var buttons := []
	if sim.won and has_next:
		buttons.append(["Next lair", next_level_pressed])
	buttons.append(["Play again", restart_pressed])
	buttons.append(["Map", map_pressed])
	_show_card("The hoard holds" if sim.won else "The hoard is empty", txt, buttons)


## Small drawn icons for the stats bar.
class StatIcon extends Control:
	var kind := "coin"

	func _draw() -> void:
		var c := size / 2.0
		match kind:
			"coin":
				draw_circle(c, 9, Color("e8b84a"))
				draw_arc(c, 9, 0, TAU, 20, Color("8a6420"), 1.5, true)
				draw_circle(c, 4, Color("c9952e"))
			"drop":
				var pts := PackedVector2Array([c + Vector2(0, -9)])
				for i in 13:
					var a := -0.15 * PI + 1.3 * PI * i / 12.0
					pts.append(c + Vector2(0, 3) + Vector2(cos(a), sin(a)) * 6.0)
				draw_colored_polygon(pts, Color("7e6cf0"))
			"gem":
				Paint.gem(self, c, 9)
