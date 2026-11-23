extends SceneTree
## Lists scroll by finger from anywhere (TouchScroll): a drag that starts on a Dark Arts skill (bought,
## buyable or shut), a Guide topic or the Guide's text reaches the list's scroll and taps nothing;
## a plain tap still works. Runs on a scratch save, signed out.
## Needs a window for input (not --headless): godot --resolution 1280x720 --script res://tests/touch_scroll_test.gd

const SAVE := "user://touch_scroll_test_save.json"
var main: Node
var frames := 0
var _ok := true
var _seen := 0          # events that reached the watched scroll since the last drag began
var _steps: Array[Callable] = []   # one per few frames


func _check(cond: bool, what: String) -> void:
	if not cond:
		printerr("  FAIL: " + what)
		_ok = false


func _initialize() -> void:
	# Never the live account: the game signs in and syncs as it starts.
	node_added.connect(func(n: Node) -> void:
		if n is Online:
			n.path = "user://test_account_none.cfg")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _ev(pos: Vector2, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	e.position = pos
	e.global_position = pos
	return e


func _move(pos: Vector2, held := true) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	e.position = pos
	e.global_position = pos
	return e


## Press on `at`, slide up, let go.
func _drag(at: Vector2) -> void:
	_seen = 0
	root.push_input(_move(at, false))
	root.push_input(_ev(at, true))
	root.push_input(_move(at + Vector2(0, -40)))
	root.push_input(_move(at + Vector2(0, -120)))
	root.push_input(_ev(at + Vector2(0, -120), false))


func _tap_down(at: Vector2) -> void:
	root.push_input(_move(at, false))
	root.push_input(_ev(at, true))


func _watch(scroll: ScrollContainer) -> void:
	scroll.gui_input.connect(func(_e: InputEvent) -> void: _seen += 1)


func _mid(c: Control) -> Vector2:
	var r := c.get_global_rect()
	return Vector2(r.get_center().x, clampf(r.get_center().y, 200.0, 680.0))


func _process(_delta: float) -> bool:
	frames += 1
	if frames > 3:
		for n in main.get_node("UI").get_children():   # tips and tutorial spotlights would sit over the lists
			if n is Control and String(n.name).begins_with("@") and n != main.guide:
				n.visible = false
	if frames == 3:
		main.save.path = SAVE   # never touch the real save file
		main.save.skills = {}
		main.save.best = {"level_01": {"rank": "Brilliant", "kept": 20}}
		main.save.unlocked = 2
		Prefs.path = "user://touch_scroll_test_settings.cfg"
		Prefs.set_value("arts_intro", true)
		_plan()
	elif frames > 5 and frames % 4 == 0:
		if _steps.is_empty():
			DirAccess.remove_absolute(SAVE)
			print("touch_scroll_test: " + ("all passed" if _ok else "FAILED"))
			quit(0 if _ok else 1)
		else:
			_steps.pop_front().call()
	return false


func _plan() -> void:
	var st: Control = main.skill_tree
	var arts: ScrollContainer = st.get_child(1)
	_steps.append(func() -> void:
		st.refresh()
		st.visible = true
		_watch(arts))
	_steps.append(func() -> void: pass)
	# Dark Arts: every skill on the first tab.
	for i in 11:
		_steps.append(func() -> void:
			if i < st._buttons.size():
				_drag(_mid(st._buttons[i])))
		_steps.append(func() -> void:
			if i < st._buttons.size():
				_check(_seen > 0, "Dark Arts: a drag on skill %d reaches the scroll" % i)
				_check(main.save.points_spent() == 0, "Dark Arts: a drag on skill %d buys nothing" % i))
	_steps.append(func() -> void: arts.scroll_vertical = 0)
	_steps.append(func() -> void: pass)
	_steps.append(func() -> void: _tap_down(st.first_buyable_rect().get_center()))
	_steps.append(func() -> void: root.push_input(_ev(st.first_buyable_rect().get_center(), false)))
	_steps.append(func() -> void:
		_check(main.save.points_spent() == 1, "Dark Arts: a tap still buys a rank")
		st.visible = false
		main.guide.open())
	# The Guide: topics down the left, then the text.
	var g: Control = main.guide
	_steps.append(func() -> void:
		_watch(g._buttons[0].get_parent().get_parent()))
	for i in [1, 3, 5, 7]:
		_steps.append(func() -> void: _drag(_mid(g._buttons[i])))
		_steps.append(func() -> void:
			_check(_seen > 0, "Guide: a drag on topic %d reaches the list's scroll" % i)
			_check(g._title.text == g._topics[0]["name"], "Guide: a drag on topic %d doesn't open it" % i))
	_steps.append(func() -> void:
		_watch(g._body_scroll)
		_drag(_mid(g._body)))
	_steps.append(func() -> void: _check(_seen > 0, "Guide: a drag on the text reaches its scroll"))
	_steps.append(func() -> void:
		(g._buttons[0].get_parent().get_parent() as ScrollContainer).scroll_vertical = 0)
	_steps.append(func() -> void: pass)
	_steps.append(func() -> void: _tap_down(_mid(g._buttons[2])))
	_steps.append(func() -> void: root.push_input(_ev(_mid(g._buttons[2]), false)))
	_steps.append(func() -> void:
		_check(g._title.text == g._topics[2]["name"], "Guide: a tap still opens a topic"))
