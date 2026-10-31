extends SceneTree
## Boots the real main scene, starts the battle, taps a few tiles and runs for a while.
## Catches errors in drawing and UI code. Run: godot --headless --script res://tests/scene_test.gd

var main: Node
var frames := 0
const SAVE := "user://scene_test_save.json"

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		assert(main.on_map and main.select.visible, "game should open on the level map")
		main.save.path = SAVE   # never touch the real save file
		Prefs.path = "user://scene_test_settings.cfg"
		main._choose(0)
	if frames == 5:
		main.started = true
		main._select(Vector2i(2, 2))      # free moss tile
		main._on_action("build")
		main._select(Vector2i(0, 0))      # woods
		main._on_action("clear")
		main._select(Vector2i(2, 2))
		main._on_action("upgrade")
		main._select(Vector2i(7, 4))      # ash
		main.sim.gold += 500
		main._on_action("build")
		main._select(Vector2i(6, 2))      # frost
		main._on_action("build")
		main.sim.call_early()
		main.speed = 2
	if frames == 400:
		main.sim.mana = 100
		main._on_meteor()
		var ev := InputEventMouseButton.new()
		ev.pressed = true
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = Vector2(5.5, 6.5) * 64
		main._on_map_input(ev)
	if frames == 900:
		print("frames=%d wave=%d enemies=%d towers=%d gems=%d" % [frames, main.sim.wave, main.sim.enemies.size(), main.sim.towers.size(), main.sim.gems_left()])
		main._show_map()
	if frames == 905:
		print("back on map: %s, frame hidden: %s" % [main.select.visible, not main.frame.visible])
		# Night mission on level 3: a raised tile, sites and loot. Unlocked in memory only.
		main.save.unlocked = 3
		main.save.best["level_03"] = {"rank": "Brilliant", "kept": 20}
		main._choose(2)
		assert(not main.sim.level.night, "level 3 is a day level")
		main._start_night()
		main.started = true
		main.speed = 2
	if frames == 910:
		var sim: GameSim = main.sim
		assert(sim.level.night and not sim.is_lit(Vector2i(0, 0)), "corner starts dark")
		sim.gold += 2000
		sim.mana = 100
		main._select(Vector2i(0, 0))
		main._on_action("build:moss")          # refused: too dark
		assert(not sim.towers.has(Vector2i(0, 0)))
		_build_toward(sim, Vector2i(12, 5), 2)
		main._select(Vector2i(1, 4))
		main._on_action("cut")                 # raze the barracks
		assert(sim.sites[Vector2i(1, 4)].owned)
		sim.call_early()
	if frames == 1500:
		var sim: GameSim = main.sim
		var high := Vector2i(12, 5)          # a raised ash tile
		var lit_before := sim.lit.size()
		_build_toward(sim, high, 6)
		print("light grew from %d to %d tiles" % [lit_before, sim.lit.size()])
		sim.lit[high] = true                  # woods block the light; lighting itself is checked above
		main._select(high)
		main._on_action("build:frost")         # raised ash tile, but any tower fits
		assert(is_equal_approx(sim.towers[high].stat("range"), float(Defs.TOWERS["frost"]["range"][0]) + float(Defs.TOWERS["frost"]["high_range"])), "height adds the Crypt's range")
		print("high ground lit=%s tower=%s loot=%d pools=%d" % [sim.is_lit(high), sim.towers.has(high), sim.loot.size(), sim.pools.size()])
		for l: GameSim.Loot in sim.loot.duplicate():
			var ev := InputEventMouseButton.new()
			ev.pressed = true
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.position = l.pos * 64
			main._on_map_input(ev)
		print("loot left after tapping: %d" % sim.loot.size())
	if frames == 1600:
		main.select.visible = true
		main.skill_tree.refresh()
		main.skill_tree.visible = true
	if frames == 1610:
		print("night level ran: wave=%d towers=%d" % [main.sim.wave, main.sim.towers.size()])
		DirAccess.remove_absolute(SAVE)
		return true
	return false


## Builds up to n towers on lit, buildable tiles, nearest to `goal` first, so the light creeps toward it.
func _build_toward(sim: GameSim, goal: Vector2i, n: int) -> void:
	for i in n:
		var best := Vector2i(-1, -1)
		for c: Vector2i in sim.lit:
			if c == goal or sim.towers.has(c):
				continue
			var acts: Array = sim.cell_info(c)["actions"]
			if acts.is_empty() or not String(acts[0]["id"]).begins_with("build"):
				continue
			if best.x < 0 or Vector2(c).distance_to(goal) < Vector2(best).distance_to(goal):
				best = c
		if best.x < 0:
			return
		main._select(best)
		main._on_action(sim.cell_info(best)["actions"][0]["id"])
