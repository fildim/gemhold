class_name TouchScroll
## Lets a finger scroll a list from anywhere on it, also when the drag starts on a button, a card or
## a block of text. Those catch the touch by default (mouse filter Stop), so the ScrollContainer
## never saw the drag: a list full of buttons (Dark Arts, the Guide's topics) wouldn't move.
## wire() makes everything inside the scroll pass the touch on, now and whenever the content is
## rebuilt, and a button press that turned into a drag doesn't count as a tap.
## Sliders and text fields keep the touch: dragging them is their own job.

const DRAG_PX := 16.0   # a finger moving further than this is scrolling, not tapping


static func wire(scroll: ScrollContainer) -> void:
	_pass(scroll)


## `n` and everything under it, now and later.
static func _pass(n: Node) -> void:
	if not n is Control or n is Range or n is LineEdit or n is TextEdit:
		return
	var c := n as Control
	if c.mouse_filter == Control.MOUSE_FILTER_STOP:
		c.mouse_filter = Control.MOUSE_FILTER_PASS
	if c is BaseButton and not c.has_meta("touch_scroll"):
		c.set_meta("touch_scroll", true)
		c.gui_input.connect(_guard.bind(c))
	if not c.child_entered_tree.is_connected(_pass):
		c.child_entered_tree.connect(_pass)
	for k in c.get_children():
		_pass(k)


## The gui_input signal runs before the button's own input handling, so on the release of a press
## that was dragged, briefly disabling the button drops the press: no `pressed`, no toggle.
static func _guard(ev: InputEvent, b: BaseButton) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			b.set_meta("down", ev.global_position)
			b.set_meta("dragged", false)
		elif b.get_meta("dragged", false):
			b.set_meta("dragged", false)
			var was := b.disabled
			b.disabled = true
			b.disabled = was
	elif ev is InputEventMouseMotion and b.has_meta("down") and ev.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if ev.global_position.distance_to(b.get_meta("down")) > DRAG_PX:
			b.set_meta("dragged", true)
