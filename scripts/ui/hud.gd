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
signal next_level_pressed
signal night_pressed
signal map_pressed
signal send_pressed(code: String)   # online race: buy this hero for the rival

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
var _rival: Label          # the rival's progress during an online race, in a badge over the map corner
var _rival_box: PanelContainer
var _next: Button
var _meteor: Button
var _cut: Button
var _speed: Button
var _pause: Button
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
var _rating: Label
var _rating_was := ""


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
	_rating = Label.new()
	_rating.add_theme_font_override("font", bold_font)
	row.add_child(_rating)
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
	_meteor = _button(brow, "Meteor %d" % Defs.METEOR["cost"], meteor_pressed)
	_cut = _button(brow, "Cut woods 15", cut_pressed)
	_speed = _button(brow, "1×", speed_pressed)
	_pause = _button(brow, "Pause", pause_pressed)
	_send = Button.new()
	_send.text = "Send heroes"
	_send.custom_minimum_size = Vector2(0, 48)
	_send.focus_mode = Control.FOCUS_NONE
	_send.add_theme_color_override("font_color", Color("e2683a"))
	_send.visible = false
	_send.pressed.connect(_open_send)
	brow.add_child(_send)
	_send_menu = PopupMenu.new()
	_send_menu.add_theme_font_size_override("font_size", 28)
	_send_menu.add_theme_constant_override("v_separation", 14)
	_send_menu.index_pressed.connect(func(i: int) -> void: send_pressed.emit(_send_kinds[i]))
	add_child(_send_menu)
	_sound = sound_button(brow)
	_add_map_button(brow)
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


## Sound on / Sound off (music and effects together). Also used on the level map.
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


## Leaving mid-battle throws the battle away, so the bar's Map button needs a second tap
## within SELL_CONFIRM_TIME seconds, like Sell.
func _add_map_button(parent: Control) -> void:
	var b := _button(parent, "Map", map_pressed)
	for c in b.pressed.get_connections():
		b.pressed.disconnect(c["callable"])
	var armed := [0]   # 0 = not armed, else which arming this is (a stale timer leaves a newer one alone)
	b.pressed.connect(func() -> void:
		if armed[0] > 0:
			armed[0] = 0
			b.text = "Map"
			map_pressed.emit()
			return
		_map_arms += 1
		armed[0] = _map_arms
		var mine := _map_arms
		b.text = "Leave? Tap again"
		get_tree().create_timer(SELL_CONFIRM_TIME).timeout.connect(func() -> void:
			if armed[0] == mine:
				armed[0] = 0
				b.text = "Map"))


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
	for l: Label in [_gold, _mana, _gems, _rating, _wave]:
		l.add_theme_font_size_override("font_size", 30 if on else 23)
	_mana_bar.custom_minimum_size = Vector2(120 if on else 90, 14 if on else 12)
	for b: Button in _brow.get_children():
		b.add_theme_font_size_override("font_size", 28 if on else 22)
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL if on else Control.SIZE_FILL
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
	_wave.text = "Wave %d/%d" % [sim.wave, sim.level.waves.size()]
	_show_rating(sim.rating_now())
	if sim.wave < sim.level.waves.size():
		var s := int(ceil(sim.timer))
		_next.disabled = false
		_next.text = "%s %ds (+%dg)" % ["Next wave" if sim.wave > 0 else "First wave", s, s]
	else:
		_next.disabled = true
		_next.text = "Final wave"
	_meteor.disabled = not sim.can_meteor() and not armed
	_meteor.text = "Cancel meteor" if armed else "Meteor %d" % Defs.METEOR["cost"]
	_cut.disabled = sim.trees.is_empty() or sim.mana < Defs.CLEAR_MANA
	_cut.text = "Cut woods %d" % Defs.CLEAR_MANA
	_speed.text = "%d×" % speed
	_pause.text = "Resume" if paused else "Pause"
	for a in _popup_actions:
		var short: bool = (a["gold"] > 0 and sim.gold < a["gold"]) or (a["mana"] > 0 and sim.mana < a["mana"])
		var col := POOR if short else BONE
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			a["button"].add_theme_color_override(c, col)


## The rating the battle is heading for, as stars, with a message the moment it slips.
func _show_rating(r: String) -> void:
	var stars := maxi(1, SaveData.RANKS.find(r))
	_rating.text = "★".repeat(stars) + " " + r
	_rating.add_theme_color_override("font_color", {"Brilliant": GOLD, "Wicked": Color("e0a050"), "Survived": POOR}.get(r, BONE))
	if _rating_was != "" and SaveData.RANKS.find(r) < SaveData.RANKS.find(_rating_was):
		toast("A hero touched a gem: Brilliant is lost" if r == "Wicked" else "A gem was carried off: Wicked is lost")
	_rating_was = r


## Forget the last rating, so a fresh battle does not report a change.
func reset_rating() -> void:
	_rating_was = ""


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
	for t: Vector2 in tries:
		var q := Vector2(t.x, clampf(t.y, area.position.y, area.end.y - ps.y))
		if t.x == anchor.position.x:   # below or above: slide sideways, keep the vertical spot
			q = Vector2(clampf(t.x, area.position.x, area.end.x - ps.x), t.y)
		if Rect2(q, ps).grow(-1).intersects(keep) == false and area.encloses(Rect2(q, ps)):
			p = q
			break
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
	_toast.position = Vector2(map_area.position.x + (map_area.size.x - _toast.size.x) / 2.0, map_area.position.y + 10)
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast.modulate.a = 1.0
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.3)


## Where a HUD button is on screen, for the tutorial spotlight: "next" or "meteor".
func button_rect(button: String) -> Rect2:
	var b: Button = {"next": _next, "meteor": _meteor}.get(button)
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
func show_intro(level: Level, number: int, best_rank: String, night_open := false, night_best := "") -> void:
	var txt := "[b]Guard the gems!!![/b]\n\n"
	txt += "[color=#a8977c]Lair %d · %d waves[/color]" % [number, level.waves.size()]
	if best_rank != "":
		txt += "   [color=#e8b84a]Best: %s[/color]" % best_rank
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


## score is this battle's (GameSim.score), best_before the mission's best until now; earned lists new
## achievement ids.
func show_end(sim: GameSim, has_next: bool, new_best: bool, new_stars := 0, free_points := 0, night_opened := false,
		score := 0, best_before := 0, earned_ach: Array[String] = []) -> void:
	var txt := ""
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
	for id in earned_ach:
		var a := Achievements.find(id)
		txt += "\n[b][color=#c9c0ff]★ Achievement: %s[/color][/b] [color=#a8977c]%s[/color]" % [a["name"], a["text"]]
	var buttons := []
	if sim.won and has_next:
		buttons.append(["Next lair", next_level_pressed])
	buttons.append(["Play again", restart_pressed])
	buttons.append(["Map", map_pressed])
	_show_card("The hoard holds" if sim.won else "The hoard is empty", txt, buttons)


## The rival's badge in the map's top-left corner during an online race (Online.race_progress);
## "" hides it.
func set_rival(rival_name: String, p: Dictionary = {}) -> void:
	_rival_box.visible = rival_name != ""
	_send.visible = _rival_box.visible     # in a race, Send takes Pause's place: pausing would
	_pause.visible = not _rival_box.visible   # only lose time on the race clock
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
