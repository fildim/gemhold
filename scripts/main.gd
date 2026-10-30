extends Node2D
## Shows the level map, boots the chosen level and wires the battle rules (GameSim) to the
## map views and the HUD. Handles taps on the map, spell targeting, speed and pause,
## and records results in the save file.

const T := 64.0
## Campaign order. Add new level files here.
const LEVELS: Array[String] = ["res://levels/level_01.json", "res://levels/level_02.json", "res://levels/level_03.json", "res://levels/level_04.json", "res://levels/level_05.json"]

var level_index := 0
var night := false            # playing the level's night mission
var save: SaveData
var on_map := true
var level: Level
var sim: GameSim
var speed := 1
var paused := false
var started := false
var armed := false            # meteor waiting for a target
var selected := Vector2i(-1, -1)

@onready var frame: Control = $MapFrame
@onready var ground: Node2D = $MapFrame/Ground
@onready var board: Node2D = $MapFrame/Board
@onready var hud: Control = $UI/HUD
@onready var select: Control = $UI/LevelSelect
@onready var skill_tree: Control = $UI/SkillTree


func _ready() -> void:
	hud.next_wave_pressed.connect(_on_next_wave)
	hud.meteor_pressed.connect(_on_meteor)
	hud.speed_pressed.connect(func() -> void: speed = 2 if speed == 1 else 1)
	hud.pause_pressed.connect(func() -> void: paused = not paused)
	hud.action_pressed.connect(_on_action)
	hud.popup_closed.connect(_deselect)
	hud.start_pressed.connect(func() -> void: started = true)
	hud.night_pressed.connect(_start_night)
	hud.restart_pressed.connect(_restart)
	hud.next_level_pressed.connect(func() -> void: _choose(level_index + 1))
	hud.map_pressed.connect(_show_map)
	frame.gui_input.connect(_on_map_input)
	get_viewport().size_changed.connect(_layout)
	save = SaveData.load_from()
	var infos := []
	for p in LEVELS:
		var lv := Level.load_from(p)
		infos.append({"id": lv.id, "title": lv.title, "waves": lv.waves.size()})
	select.setup(hud, infos, save)
	select.level_chosen.connect(_choose)
	skill_tree.setup(hud, save)
	select.skills_pressed.connect(func() -> void:
		skill_tree.refresh()
		skill_tree.visible = true)
	skill_tree.closed.connect(func() -> void:
		skill_tree.visible = false
		select.refresh())
	# Keep a level loaded behind the map so the views always have something to draw.
	_load_level(clampi(save.unlocked - 1, 0, LEVELS.size() - 1))
	_show_map()
	_layout.call_deferred()


func _show_map() -> void:
	on_map = true
	started = false
	_deselect()
	frame.visible = false
	hud.set_battle_visible(false)
	select.refresh()
	select.visible = true


func _choose(i: int) -> void:
	if i < 0 or i >= LEVELS.size() or not save.is_unlocked(i):
		return
	on_map = false
	started = false
	select.visible = false
	frame.visible = true
	hud.set_battle_visible(true)
	night = false
	_load_level(i)
	_layout()
	hud.show_intro(level, i + 1, save.best_rank(level.id), save.night_unlocked(level.id),
		save.best_rank(SaveData.mission_id(level.id, true)))


## Chosen on the start card: reload the same level in darkness and begin.
func _start_night() -> void:
	if not save.night_unlocked(level.id):
		return
	night = true
	_load_level(level_index)
	started = true


func _load_level(i: int) -> void:
	level_index = i
	level = Level.load_from(LEVELS[i])
	level.night = night
	_new_battle()


func _new_battle() -> void:
	sim = GameSim.new(level, save.skills)
	sim.toast.connect(hud.toast)
	sim.ended.connect(_on_ended)
	ground.setup(level, sim)
	board.setup(level, sim, hud.bold_font)
	frame.size = Vector2(level.cols, level.rows) * T
	speed = 1
	paused = false
	armed = false
	_deselect()


func _restart() -> void:
	_new_battle()
	started = true


func _process(delta: float) -> void:
	if on_map:
		return
	if started and not paused and not sim.over:
		var dt := minf(delta, 0.05)
		for i in speed:
			sim.update(dt)
	board.armed = armed
	board.queue_redraw()
	hud.refresh(sim, armed, speed, paused)


## Fit the map between the top and bottom bars, keeping its proportions.
func _layout() -> void:
	var vs := get_viewport_rect().size
	var map_px := Vector2(level.cols, level.rows) * T
	var avail := Vector2(vs.x - 16, vs.y - hud.top_h - hud.bottom_h - 8)
	var s := minf(avail.x / map_px.x, avail.y / map_px.y)
	frame.scale = Vector2(s, s)
	frame.position = Vector2((vs.x - map_px.x * s) / 2.0, hud.top_h + 4 + (avail.y - map_px.y * s) / 2.0)


func _on_map_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not started or sim.over:
		return
	var p: Vector2 = event.position / T   # tile units
	if armed:
		sim.cast_meteor(p)
		armed = false
		_deselect()
		return
	if sim.collect_loot(p):
		return        # loot takes the tap before tiles do
	if hud.popup_open():
		_deselect()   # a map tap while a panel is open just closes it
		return
	var c := Vector2i(floori(p.x), floori(p.y))
	if level.in_bounds(c):
		_select(c)


func _select(c: Vector2i) -> void:
	selected = c
	board.selected = c
	var xf := frame.get_global_transform_with_canvas()
	var rect := Rect2(xf * (Vector2(c) * T), Vector2(T, T) * frame.scale)
	hud.show_popup(sim.cell_info(c), rect)


func _deselect() -> void:
	selected = Vector2i(-1, -1)
	board.selected = selected
	hud.hide_popup()


func _on_action(id: String) -> void:
	var c := selected
	var err := sim.do_action(id, c)
	if err != "":
		hud.toast(err)
		return
	if id.begins_with("build") or id == "sell" or id == "clear":
		_deselect()
	else:
		_select(c)


func _on_next_wave() -> void:
	if started and not sim.over:
		sim.call_early()


func _on_meteor() -> void:
	if armed:
		armed = false
		return
	if not sim.can_meteor():
		return
	_deselect()
	armed = true
	hud.toast("Tap the map to drop the meteor")


func _on_ended(won: bool) -> void:
	_deselect()
	var had_night := save.night_unlocked(level.id)
	var mission := SaveData.mission_id(level.id, night)
	var stars_before := save.stars(mission)
	var new_best := save.record(level_index, mission, sim.rank(), level.gems - sim.lost, won)
	save.save()
	var night_opened := not had_night and save.night_unlocked(level.id)
	hud.show_end(sim, level_index + 1 < LEVELS.size(), new_best, save.stars(mission) - stars_before, save.points_free(), night_opened)


## Android back button: close the panel, cancel the meteor, or pause. On the map it quits.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if on_map:
			get_tree().quit()
		elif hud.popup_open():
			_deselect()
		elif armed:
			armed = false
		else:
			paused = not paused
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		paused = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_deselect()
		armed = false
