class_name Screens
## Full-screen pages in the style of the Guide and the Hall of Fame: a dark background filling the
## screen, the title in the top left, a button back in the top right, and the content below in a
## scroll area so it fits on small phones.

const Hud := preload("res://scripts/ui/hud.gd")


## Builds the page into `host` (a full-rect Control) and returns the box to fill with content.
## `back` runs when the top-right button is pressed.
static func page(host: Control, hud: Control, title_text: String, back_text: String, back: Callable) -> VBoxContainer:
	host.theme = hud.theme
	var bg := ColorRect.new()
	bg.color = Hud.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	host.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	margin.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_override("font", hud.display_font)
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Hud.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var b := Button.new()
	b.text = back_text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(back)
	head.add_child(b)
	var scroll := ScrollContainer.new()
	TouchScroll.wire(scroll)   # drags that start on a button or card still scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box
