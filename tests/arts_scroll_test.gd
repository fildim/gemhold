extends SceneTree
## Dark Arts: a drag that starts on a skill (bought, buyable or shut) reaches the list's scroll and
## buys nothing; a plain tap still buys. Runs on a scratch save, never the player's.
## Needs a window for input (not --headless): godot --script res://tests/arts_scroll_test.gd

const SAVE := "user://arts_scroll_test_save.json"
var main: Node
var frames := 0
var _ok := true
var _seen := 0
var _i := 0          # the skill button being dragged
var _spent := 0


func _check(cond: bool, what: String) -> void:
	if not cond:
		printerr("  FAIL: " + what)
		_ok = false


func _initialize() -> void:
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


func _move(pos: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	e.position = pos
	e.global_position = pos
	return e


func _process(_delta: float) -> bool:
	frames += 1
	var st: Control = main.skill_tree
	if frames > 3:
		for n in st.get_parent().get_children():   # tips and tutorial spotlights would sit over the list
			if n is Control and String(n.name).begins_with("@"):
				n.visible = false
	if frames == 3:
		main.save.path = SAVE   # never touch the real save file
		main.save.skills = {}
		main.save.best = {"level_01": {"rank": "Brilliant", "kept": 20}}
		main.save.unlocked = 2
		Prefs.path = "user://arts_scroll_test_settings.cfg"
		Prefs.set_value("arts_intro", true)
		st.refresh()
		st.visible = true
		var scroll: ScrollContainer = st.get_child(1)
		scroll.gui_input.connect(func(_e: InputEvent) -> void: _seen += 1)
	elif frames > 5 and frames % 4 == 0 and _i < st._buttons.size():
		# One drag every few frames: press, slide up, let go.
		var b: Button = st._buttons[_i]
		_i += 1
		var name := b.text.get_slice("\n", 0)
		_check(_seen > 0 or _i == 1, "the drag before %s reached the scroll" % name)
		_check(main.save.points_spent() == 0, "a drag buys nothing (before %s)" % name)
		_seen = 0
		var r := b.get_global_rect()
		var c := Vector2(r.get_center().x, clampf(r.get_center().y, 200.0, 680.0))
		root.push_input(_ev(c, true))
		root.push_input(_move(c + Vector2(0, -40)))
		root.push_input(_move(c + Vector2(0, -120)))
		root.push_input(_ev(c + Vector2(0, -120), false))
	elif _i >= st._buttons.size() and _spent == 0:
		_check(_seen > 0, "the last drag reached the scroll")
		_check(main.save.points_spent() == 0, "no drag bought anything")
		(st.get_child(1) as ScrollContainer).scroll_vertical = 0
		_spent = -10
	elif _spent < -3:
		_spent += 1
		if _spent == -5:
			_spent = -1
	elif _spent == -1:
		var r: Rect2 = st.first_buyable_rect()
		_check(r.has_area(), "a skill is buyable with 3 stars")
		var hover := _move(r.get_center())
		hover.button_mask = 0
		root.push_input(hover)
		root.push_input(_ev(r.get_center(), true))
		_spent = -2
	elif _spent == -2:
		root.push_input(_ev(main.skill_tree.first_buyable_rect().get_center(), false))
		_spent = -3
	elif _spent == -3:
		_check(main.save.points_spent() == 1, "a tap still buys a rank")
		DirAccess.remove_absolute(SAVE)
		print("arts_scroll_test: %d skills dragged, %s" % [_i, "all passed" if _ok else "FAILED"])
		quit(0 if _ok else 1)
	return false
