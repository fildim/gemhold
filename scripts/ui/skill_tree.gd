extends Control
## The skill tree, opened from the level map: stars earned, then one column per tower type.
## Tap a skill to spend a point. Every star from a mission's best rating is one point.
## Builds its own nodes in code, like the HUD.

signal closed

const Hud := preload("res://scripts/ui/hud.gd")
const TREES := [["moss", "Warband Huts"], ["frost", "Bone Crypts"], ["ash", "Cinder Shrines"], ["den", "The Hoard"]]
## Shown as a tip the first time Dark Arts opens (see main.gd), instead of taking up the screen.
const INTRO := "[b]Dark Arts[/b] are your skills. [b]Every star is a skill point:[/b] each lair's best rating gives ★ Survived, ★★ Wicked or ★★★ Brilliant, and night missions earn their own.\n\nTap a skill to buy a rank; the dots show ranks bought and left. [b]Tower skills[/b] apply to towers you build from then on. [b]The Hoard[/b] column powers your den and gives every battle more starting gold or mana. [b]Refund all points[/b] gives them back to spend again."
const TREE_COLORS := {"moss": Color("8fb35a"), "frost": Color("9fd8f0"), "ash": Color("ff8a3a"), "den": Color("ff7a90")}

var _hud: Control
var _save: SaveData
var _stars: Label
var _points: Label
var _cols: HBoxContainer
var _reset: Button
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
	_stars.add_theme_font_size_override("font_size", 30)
	_stars.add_theme_color_override("font_color", Hud.GOLD)
	info.add_child(_stars)
	_points = Label.new()
	_points.add_theme_font_override("font", hud.bold_font)
	_points.add_theme_font_size_override("font_size", 32)
	_points.add_theme_color_override("font_color", Hud.EMBER)
	_points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_points)
	var back := Button.new()
	_back = back
	back.text = "Back to map"
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(0, 64)
	back.add_theme_font_size_override("font_size", 28)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: closed.emit())
	head.add_child(back)


	_cols = HBoxContainer.new()
	_cols.add_theme_constant_override("separation", 14)
	box.add_child(_cols)

	_reset = Button.new()
	_reset.text = "Refund all points"
	_reset.focus_mode = Control.FOCUS_NONE
	_reset.size_flags_horizontal = Control.SIZE_SHRINK_END
	_reset.add_theme_color_override("font_color", Hud.DIM)
	_reset.add_theme_font_size_override("font_size", 24)
	_reset.custom_minimum_size = Vector2(0, 56)
	_reset.pressed.connect(_on_reset)
	box.add_child(_reset)
	refresh()


func refresh() -> void:
	_stars.text = "★ %d star%s earned" % [_save.points_total(), "" if _save.points_total() == 1 else "s"]
	var free := _save.points_free()
	_points.text = "%d point%s to spend" % [free, "" if free == 1 else "s"]
	_points.add_theme_color_override("font_color", Hud.EMBER if free > 0 else Hud.DIM)
	_reset.disabled = _save.points_spent() == 0
	for c in _cols.get_children():
		_cols.remove_child(c)
		c.queue_free()
	for tree in TREES:
		_cols.add_child(_column(tree[0], tree[1]))


func _column(type: String, title: String) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	panel.custom_minimum_size = Vector2(0, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var h := Label.new()
	h.text = title
	h.add_theme_font_override("font", _hud.display_font)
	h.add_theme_font_size_override("font_size", 36)
	h.add_theme_color_override("font_color", TREE_COLORS[type])
	col.add_child(h)
	for sk: Dictionary in Defs.SKILLS[type]:
		var id: String = sk["id"]
		var r := _save.skill_rank(id)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 76)
		b.text = "%s   %s\n%s" % [sk["name"], "●".repeat(r) + "○".repeat(int(sk["max"]) - r), sk["text"]]
		b.add_theme_font_size_override("font_size", 27)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # wrap so four columns fit any screen
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not _save.can_buy(id)
		if r >= int(sk["max"]):
			b.add_theme_color_override("font_disabled_color", Hud.GOLD)
		elif r > 0:
			b.add_theme_color_override("font_disabled_color", Color(Hud.BONE, 0.8))
		b.pressed.connect(_on_buy.bind(id))
		col.add_child(b)
	return panel


func _on_buy(id: String) -> void:
	if _save.buy(id):
		_save.save()
		refresh()


func _on_reset() -> void:
	_save.reset_skills()
	_save.save()
	refresh()
	_hud.toast("Points refunded")


## For the tutorial spotlight: the first skill a point can buy now, and the way back.
func first_buyable_rect() -> Rect2:
	for col in _cols.get_children():
		for b in col.get_child(0).get_children():
			if b is Button and not b.disabled:
				return b.get_global_rect()
	return Rect2()


func back_rect() -> Rect2:
	return _back.get_global_rect()
