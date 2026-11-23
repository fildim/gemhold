extends Control
## The skill tree, opened from the level map: stars earned, then one tab per tree (Huts, Crypts,
## Shrines, The Hoard, and The Land once it has skills), each listing its skills as big buttons in tier
## sections. A tier still shut shows its header ("Opens in Chapter III") with its skills dimmed.
## Tap a skill to spend a point. Every star from a mission's best rating is one point.
## Builds its own nodes in code, like the HUD.

signal closed

const Hud := preload("res://scripts/ui/hud.gd")
const TAB_NAMES := {"moss": "Huts", "frost": "Crypts", "ash": "Shrines", "den": "The Hoard", "land": "The Land"}
const TIER_NAMES := {1: "Tier I", 2: "Tier II", 3: "Tier III"}
const ROMAN := ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
## Shown as a tip the first time Dark Arts opens (see main.gd), instead of taking up the screen.
const INTRO := "[b]Dark Arts[/b] are your skills. [b]Every star is a skill point:[/b] each lair's best rating gives ★ Survived, ★★ Wicked or ★★★ Brilliant, and night missions earn their own.\n\nTap a skill to buy a rank; the dots show ranks bought and left. [b]Tower skills[/b] apply to towers you build from then on. [b]The Hoard[/b] tab powers your den and gives every battle more starting gold or mana. [b]Refund all points[/b] gives them back to spend again."
const DRAG_PX := 16.0   # a finger moving further than this is scrolling, not tapping
const TREE_COLORS := {"moss": Color("8fb35a"), "frost": Color("9fd8f0"), "ash": Color("ff8a3a"), "den": Color("ff7a90"), "land": Color("c9a86a")}

var _hud: Control
var _save: SaveData
var _stars: Label
var _points: Label
var _tabs: HBoxContainer
var _list: VBoxContainer
var _tab := "moss"          # the tree shown
var _buttons: Array[Button] = []   # skill buttons on the shown tab
var _pads := {}             # state -> padded button stylebox (see _padded)
var _reset: Button
var _reset_armed := false   # first tap on Refund done, waiting for the second
var _reset_arms := 0        # counts armings, so a stale timer leaves a newer one alone
var _back: Button


func setup(hud: Control, save: SaveData) -> void:
	_hud = hud
	_save = save
	theme = hud.theme
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Hud.NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	box.add_child(head)
	var title := Label.new()
	title.text = "Dark Arts"
	title.add_theme_font_override("font", hud.display_font)
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Hud.GOLD)
	head.add_child(title)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(info)
	_stars = Label.new()
	_stars.add_theme_font_override("font", hud.bold_font)
	_stars.add_theme_font_size_override("font_size", 28)
	_stars.add_theme_color_override("font_color", Hud.GOLD)
	info.add_child(_stars)
	_points = Label.new()
	_points.add_theme_font_override("font", hud.bold_font)
	_points.add_theme_font_size_override("font_size", 28)
	_points.add_theme_color_override("font_color", Hud.EMBER)
	info.add_child(_points)   # under the stars, so the heading row stays narrow
	_reset = Button.new()
	_reset.text = "Refund all points"
	_reset.focus_mode = Control.FOCUS_NONE
	_reset.add_theme_color_override("font_color", Hud.DIM)
	_reset.add_theme_font_size_override("font_size", 28)
	_reset.custom_minimum_size = Vector2(0, 64)
	_reset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_reset.pressed.connect(_on_reset)
	head.add_child(_reset)
	var back := Button.new()
	_back = back
	back.text = "Back to map"
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(0, 64)
	back.add_theme_font_size_override("font_size", 28)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: closed.emit())
	head.add_child(back)


	# The tabs fill the width when they fit; on a narrow screen the row slides sideways instead.
	var strip := ScrollContainer.new()
	strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	strip.custom_minimum_size = Vector2(0, 76)
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(strip)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 10)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_child(_tabs)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	box.add_child(_list)
	refresh()


## The trees that have skills, in tab order.
static func trees() -> Array[String]:
	var out: Array[String] = []
	for t: String in Defs.SKILL_TREES:
		if Defs.SKILLS.has(t) and not Defs.SKILLS[t].is_empty():
			out.append(t)
	return out


func refresh() -> void:
	_stars.text = "★ %d star%s earned" % [_save.points_total(), "" if _save.points_total() == 1 else "s"]
	var free := _save.points_free()
	_points.text = "%d point%s to spend" % [free, "" if free == 1 else "s"]
	_points.add_theme_color_override("font_color", Hud.EMBER if free > 0 else Hud.DIM)
	_reset.disabled = _save.points_spent() == 0
	if not trees().has(_tab):
		_tab = trees()[0]
	for box: Container in [_tabs, _list]:
		for c in box.get_children():
			box.remove_child(c)
			c.queue_free()
	_buttons.clear()
	for t in trees():
		_tabs.add_child(_tab_button(t))
	_fill(_tab)


func _tab_button(tree: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = true
	b.button_pressed = tree == _tab
	var spent := 0
	var room := 0
	for sk: Dictionary in Defs.SKILLS[tree]:
		spent += _save.skill_rank(sk["id"])
		room += int(sk["max"])
	b.text = "%s  %d/%d" % [TAB_NAMES.get(tree, tree), spent, room]
	b.add_theme_font_override("font", _hud.bold_font)
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", Color(TREE_COLORS[tree], 0.75))
	b.add_theme_color_override("font_pressed_color", TREE_COLORS[tree])
	b.add_theme_color_override("font_hover_pressed_color", TREE_COLORS[tree])
	b.custom_minimum_size = Vector2(0, 72)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tap(b, func() -> void:
		_tab = tree
		refresh())
	return b


## One tree: its skills grouped by tier. Tier headers only show when the tree has more than one
## tier or a tier is still shut, so a plain tree is just its skills.
func _fill(tree: String) -> void:
	var beaten := _save.lairs_beaten()
	var tiers := {}
	for sk: Dictionary in Defs.SKILLS[tree]:
		var t := Defs.skill_tier(sk)
		if not tiers.has(t):
			tiers[t] = []
		tiers[t].append(sk)
	var order := tiers.keys()
	order.sort()
	var tree_gate := int(Defs.TREE_BEATEN.get(tree, 0))
	for t: int in order:
		var gate := maxi(int(Defs.TIER_BEATEN.get(t, 0)), tree_gate)
		var shut := beaten < gate
		if order.size() > 1 or shut:
			var h := Label.new()
			h.text = TIER_NAMES.get(t, "Tier %d" % t) + ("   Opens in Chapter %s" % ROMAN[Defs.gate_chapter(gate)] if shut else "")
			h.add_theme_font_override("font", _hud.display_font)
			h.add_theme_font_size_override("font_size", 34)
			h.add_theme_color_override("font_color", Hud.DIM if shut else TREE_COLORS[tree])
			_list.add_child(h)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 10)
		_list.add_child(grid)
		for sk: Dictionary in tiers[t]:
			var b := _skill_button(sk)
			if shut:
				b.modulate = Color(1, 1, 1, 0.45)
			grid.add_child(b)
			_buttons.append(b)


func _skill_button(sk: Dictionary) -> Button:
	var id: String = sk["id"]
	var r := _save.skill_rank(id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 96)
	var top := int(sk["max"])
	var dots := "●".repeat(r) + "○".repeat(top - r) if top <= 5 else "%d/%d" % [r, top]   # deep skills: a count
	b.text = "%s   %s\n%s" % [sk["name"], dots, sk["text"]]
	# A skill about something that turns up later than its tier: when it opens, under its text.
	var own := Defs.skill_gate(id)
	if own > Defs.group_gate(Defs.skill_def(id)) and _save.lairs_beaten() < own:
		b.text += "\nOpens in Chapter %s" % ROMAN[Defs.gate_chapter(own)]
		b.modulate = Color(1, 1, 1, 0.45)
	b.add_theme_font_size_override("font_size", 34)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var can := _save.can_buy(id)
	b.set_meta("buyable", can)
	# A mastery stays tappable even when it can't be bought: the tap opens its details first.
	var info := id.begins_with("mastery_")
	b.disabled = not can and not info
	for c: String in (["font_disabled_color"] if not info else ["font_color", "font_hover_color", "font_pressed_color"]):
		if r >= int(sk["max"]):
			b.add_theme_color_override(c, Hud.GOLD)
		elif r > 0:
			b.add_theme_color_override(c, Color(Hud.BONE, 0.8))
		elif info and not can:
			b.add_theme_color_override(c, Color(Hud.BONE, 0.4))
	# Its picture on the left, with the text moved over to make room.
	for st: String in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, _padded(st))
	var ic := GameIcon.make("skill:" + id, 78)
	ic.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	ic.offset_left = 10
	ic.offset_right = 88
	ic.offset_top = -39
	ic.offset_bottom = 39
	b.add_child(ic)
	_tap(b, _show_mastery.bind(sk) if info else _on_buy.bind(id))
	return b


## Makes a button in a scrolling list tappable without blocking the scroll: a drag that starts on
## it (even a disabled one) still slides the list, and a press that turned into a drag doesn't count.
func _tap(b: Button, on_tap: Callable) -> void:
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			b.set_meta("down", ev.global_position)
			b.set_meta("dragged", false)
		elif ev is InputEventMouseMotion and b.has_meta("down"):
			if ev.global_position.distance_to(b.get_meta("down")) > DRAG_PX:
				b.set_meta("dragged", true))
	b.pressed.connect(func() -> void:
		if b.get_meta("dragged", false):
			b.set_meta("dragged", false)
			if b.toggle_mode:
				b.set_pressed_no_signal(not b.button_pressed)
			return
		on_tap.call())


## The level IV tower a mastery skill opens, explained, with Learn and Cancel.
func _show_mastery(sk: Dictionary) -> void:
	var id: String = sk["id"]
	var mid := id.trim_prefix("mastery_")
	var tower := ""
	var m := {}
	for t: String in Defs.MASTERIES:
		for e: Dictionary in Defs.MASTERIES[t]:
			if e["id"] == mid:
				tower = t
				m = e
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.6)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			veil.queue_free())
	add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(900.0, size.x - 40.0), 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	box.add_child(head)
	head.add_child(GameIcon.make("skill:" + id, 78))
	var title := Label.new()
	title.text = "%s (level IV %s)" % [m.get("name", sk["name"]), Defs.TOWERS[tower]["name"] if tower != "" else "tower"]
	title.add_theme_font_override("font", _hud.display_font)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", TREE_COLORS.get(tower, Hud.GOLD))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.add_theme_font_size_override("normal_font_size", 32)
	text.add_theme_font_size_override("bold_font_size", 32)
	text.text = mastery_text(mid) + "

In battle, a level III %s that has learned its ability can become a %s for %d gold. Learn both masteries of a tower to choose for each one you build." % [Defs.TOWERS[tower]["name"] if tower != "" else "tower", m.get("name", ""), int(Defs.TOWERS[tower]["cost"][3]) if tower != "" else 0]
	box.add_child(text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(row)
	var have := _save.skill_rank(id) >= int(sk["max"])
	var learn := Button.new()
	learn.focus_mode = Control.FOCUS_NONE
	learn.custom_minimum_size = Vector2(260, 80)
	learn.add_theme_font_size_override("font_size", 32)
	if have:
		learn.text = "Learned"
		learn.disabled = true
	elif _save.can_buy(id):
		learn.text = "Learn (1 point)"
	else:
		learn.disabled = true
		learn.text = "No point to spend" if _save.points_free() <= 0 else "Not open yet"
	learn.pressed.connect(func() -> void:
		veil.queue_free()
		_on_buy(id))
	var cancel := Button.new()
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.text = "Close" if learn.disabled else "Cancel"
	cancel.custom_minimum_size = Vector2(200, 80)
	cancel.add_theme_font_size_override("font_size", 32)
	cancel.pressed.connect(func() -> void: veil.queue_free())
	row.add_child(cancel)
	row.add_child(learn)


## What a level IV mastery does, in full (the same words as the Guide).
static func mastery_text(mid: String) -> String:
	match mid:
		"longhouse":
			return "Every shot is [b]three arrows at up to three heroes[/b]. For crowds."
		"lodge":
			return "One heavy javelin that [b]ignores armour[/b], aimed at the healthiest hero, and [b]marks[/b] him for %d seconds: everything hits him %d%% harder. For Knights and bosses." % [roundi(Defs.LODGE["mark"]), roundi(Defs.LODGE["mark_dmg"] * 100)]
		"ossuary":
			return "[b]Stores a bolt every reload[/b] even with no hero in sight, up to %d (the skulls on its roof light up), then looses them in a quick burst at its target (its Aim): for Knights and bosses." % Defs.OSSUARY["charges"]
		"mausoleum":
			return "Each bolt [b]bursts[/b], chilling and hurting every hero within %.1f tiles, and Dread rolls for each of them." % Defs.MAUSOLEUM["r"]
		"twin":
			return "[b]Two beams on two heroes[/b], each heating up on its own."
		"sunlance":
			return "The beam [b]burns on through its hero and every hero on the line behind him[/b], and keeps part of its heat when it changes target."
	return ""


## The theme's button look with room on the left for a skill's picture.
func _padded(state: String) -> StyleBox:
	if not _pads.has(state):
		var sb: StyleBox = _hud.theme.get_stylebox(state, "Button").duplicate()
		sb.content_margin_left = 100
		_pads[state] = sb
	return _pads[state]


func _on_buy(id: String) -> void:
	if _save.buy(id):
		_save.save()
		refresh()


## Needs a second tap within Hud.SELL_CONFIRM_TIME seconds, like Sell.
func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset.text = "Refund all? Tap again"
		_reset.add_theme_color_override("font_color", Hud.POOR)
		_reset_arms += 1
		var mine := _reset_arms
		get_tree().create_timer(Hud.SELL_CONFIRM_TIME).timeout.connect(func() -> void:
			if _reset_armed and mine == _reset_arms:
				_disarm_reset())
		return
	_disarm_reset()
	_save.reset_skills()
	_save.save()
	refresh()
	_hud.toast("Points refunded")


func _disarm_reset() -> void:
	_reset_armed = false
	_reset.text = "Refund all points"
	_reset.add_theme_color_override("font_color", Hud.DIM)


## For the tutorial spotlight: the first skill a point can buy now, and the way back.
func first_buyable_rect() -> Rect2:
	for b in _buttons:
		if b.get_meta("buyable", false):
			return b.get_global_rect()
	return Rect2()


func back_rect() -> Rect2:
	return _back.get_global_rect()


func reset_rect() -> Rect2:
	return _reset.get_global_rect()
