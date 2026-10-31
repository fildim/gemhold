extends Control
## The Guide, opened from the level map: every topic down the left, grouped, and the chosen
## topic as a card on the right. Content lives in scripts/data/guide.gd.
## Builds its own nodes in code, like the HUD.

signal closed

const Hud := preload("res://scripts/ui/hud.gd")
const GROUP_COLORS := {"The basics": Color("e8b84a"), "Towers": Color("8fb35a"), "Heroes": Color("ff7a90"),
	"Your powers": Color("c9c0ff"), "Progress": Color("ff8a3a")}

var _hud: Control
var _topics: Array = []
var _buttons: Array[Button] = []
var _title: Label
var _group: Label
var _body: RichTextLabel
var _body_scroll: ScrollContainer
var _accent: ColorRect


func setup(hud: Control) -> void:
	_hud = hud
	_topics = Guide.topics()
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
	box.add_child(head)
	var title := Label.new()
	title.text = "Guide"
	title.add_theme_font_override("font", hud.display_font)
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Hud.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var back := Button.new()
	back.text = "Back to map"
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(0, 64)
	back.add_theme_font_size_override("font_size", 28)
	back.pressed.connect(func() -> void: closed.emit())
	head.add_child(back)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 18)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(split)

	# Left: the topics, grouped.
	var list_scroll := ScrollContainer.new()
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_stretch_ratio = 0.36
	split.add_child(list_scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list)
	var group := ""
	for i in _topics.size():
		var tp: Dictionary = _topics[i]
		if tp["group"] != group:
			group = tp["group"]
			var gl := Label.new()
			gl.text = group
			gl.add_theme_font_override("font", hud.display_font)
			gl.add_theme_font_size_override("font_size", 30)
			gl.add_theme_color_override("font_color", GROUP_COLORS.get(group, Hud.GOLD))
			if i > 0:
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(0, 8)
				list.add_child(gap)
			list.add_child(gl)
		var b := Button.new()
		b.text = tp["name"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 58)
		b.add_theme_font_size_override("font_size", 26)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_show.bind(i))
		list.add_child(b)
		_buttons.append(b)

	# Right: the card.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", hud._box(Hud.PANEL, Hud.EDGE, 1, 14, 26))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 0.64
	split.add_child(card)
	var cbox := VBoxContainer.new()
	cbox.add_theme_constant_override("separation", 10)
	card.add_child(cbox)
	_group = Label.new()
	_group.add_theme_font_override("font", hud.bold_font)
	_group.add_theme_font_size_override("font_size", 22)
	cbox.add_child(_group)
	_title = Label.new()
	_title.add_theme_font_override("font", hud.display_font)
	_title.add_theme_font_size_override("font_size", 46)
	_title.add_theme_color_override("font_color", Hud.GOLD)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cbox.add_child(_title)
	_accent = ColorRect.new()
	_accent.custom_minimum_size = Vector2(0, 3)
	cbox.add_child(_accent)
	_body_scroll = ScrollContainer.new()
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cbox.add_child(_body_scroll)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in ["normal_font_size", "bold_font_size"]:
		_body.add_theme_font_size_override(k, 28)
	_body.add_theme_constant_override("line_separation", 6)
	_body_scroll.add_child(_body)
	_show(0)


## Opens the guide on its first topic.
func open() -> void:
	_show(0)
	visible = true


func _show(i: int) -> void:
	var tp: Dictionary = _topics[i]
	var col: Color = GROUP_COLORS.get(tp["group"], Hud.GOLD)
	_group.text = tp["group"].to_upper()
	_group.add_theme_color_override("font_color", col)
	_title.text = tp["name"]
	_accent.color = Color(col, 0.6)
	_body.text = tp["text"]
	_body_scroll.scroll_vertical = 0
	for k in _buttons.size():
		var on := k == i
		var b := _buttons[k]
		if on:
			b.add_theme_stylebox_override("normal", _hud._box(Color("5a2414"), Hud.EMBER, 4, 8, 14))
			b.add_theme_stylebox_override("hover", _hud._box(Color("6e2c18"), Hud.EMBER, 4, 8, 14))
		else:
			b.remove_theme_stylebox_override("normal")
			b.remove_theme_stylebox_override("hover")
