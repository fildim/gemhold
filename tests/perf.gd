extends SceneTree
## Frame-time benchmark of a heavy, deterministic battle in the real main scene. Run it in a window
## (not headless: headless renders nothing), with a scratch APPDATA so the real save is never touched:
##   godot --path . -s tests/perf.gd -- scen=day quality=detailed w=1720 h=720 secs=20
## Every option can also be given as an environment variable PERF_<NAME> (PERF_SCEN=day, ...).
##   scen     day | tide | siege | night | race       (see SCENES)
##   quality  detailed | light | auto                 (Prefs "graphics" for this run)
##   w, h     window size in pixels (default 1720x720); vsync is off, the frame rate uncapped
##   secs     length of the measured window (default 20), after `warm` seconds (default 3)
##   off      comma list of things not to draw, to see what each costs (Board.perf_off and below):
##            towers, sites, gems, overlays, heroes, shots, fx, ground_fx, fog, bursts, hud,
##            ripple, ground
##   shot     a PNG path: instead of timing, step the battle a fixed 5 s, freeze it and save one
##            picture (the same frame on every run, for before/after comparisons)
##   settings 1: with shot, open the Settings window over the battle first
##   ford     1: with shot, planks on every other ford and heroes standing on the fords (high tide in "tide")
##   out      a file to append the result line to
##   switch   detailed | light | auto: change the Graphics setting halfway through (the max frame shows the re-bake)
## It prints one line: PERF scen=.. avg=.. worst1%=.. max=.. dc=.. objects=.. primitives=..

const SCENES := {   # campaign index (main._choose) of each scenario's lair
	"day": 11,      # Frostfang Pass: all three grounds and raised tiles
	"tide": 27,     # Tidewrack Flats: tide, fords, rivers
	"siege": 39,    # The Iron Belfry: siege engines
	"night": 47,    # Eclipse: the battle is measured in the dark
	"race": 39,     # The Iron Belfry as an online race (no network: the race clock only)
	"fen": 25,      # Blackwater Fen: wide shallows
}
const HEROES := 60   # kept on the map all the time
const TOWERS := 28

var main: Node
var frames := 0
var opt := {}
var _t0 := 0
var _last := 0
var _times: PackedFloat32Array = []
var _dc := 0.0
var _obj := 0.0
var _prim := 0.0
var _cpu := 0.0
var _gpu := 0.0
var _proc := 0.0
var _n := 0
var _codes: Array[String] = []
var _spawned := 0
var _phase := "setup"
var _shot_t := 0
var _warm_max := 0.0   # slowest frame while the battle opens (the pictures bake then)
var _open_last := 0
var _switched := false


func _o(k: String, d: String) -> String:
	return str(opt.get(k, OS.get_environment("PERF_" + k.to_upper()) if OS.get_environment("PERF_" + k.to_upper()) != "" else d))


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.contains("="):
			opt[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var w := int(_o("w", "1720"))
	var h := int(_o("h", "720"))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_size(Vector2i(w, h))
	DisplayServer.window_set_position(Vector2i(0, 0))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	var now := Time.get_ticks_usec()
	if frames > 4 and _times.is_empty():   # from the lair opening until timing starts
		_warm_max = maxf(_warm_max, (now - _open_last) / 1000.0)
	_open_last = now
	if frames == 3:
		_prepare()
	elif frames == 6:
		_build_battle()
	elif frames > 6:
		_keep_busy()
		if _o("shot", "") != "":
			return _shot_step()
		_measure()
	return false


func _prepare() -> void:
	main.save.path = "user://perf_save.json"
	Prefs.path = "user://perf_settings.cfg"
	Prefs.set_value("tutorial_done", true)
	Prefs.set_value("arts_tip", 2)
	Prefs.set_value("arts_intro", true)
	Prefs.set_value("race_tip", 99)
	for gate in [10, 20, 40]:
		Prefs.set_value("tier_tip_%d" % gate, true)
	for k in Defs.SITES:
		Prefs.set_value("building_tip_" + k, true)
	for k in Defs.ENEMIES:
		Prefs.set_value("hero_tip_" + k, true)
	for k in main.RULE_TIPS:
		Prefs.set_value("rule_tip_" + k, true)
	Prefs.set_value("graphics", _o("quality", "detailed"))
	Prefs.set_value("show_fps", false)
	main.save.unlocked = 50
	seed(1234)
	var scen := _o("scen", "day")
	var idx: int = SCENES.get(scen, 11)
	if scen == "race":   # what main._start_race does, without the network
		main.race = {"code": "PERF", "side": "h", "rival": Online.race_progress(), "t0": Time.get_ticks_msec(), "got": 0}
		main._race_busy = true   # no reports or polls
		main._race_t = INF
		main.on_map = false
		main.select.visible = false
		main.frame.visible = true
		main.hud.set_battle_visible(true)
		main.night = false
		main._load_level(idx)
		main.sim.set_race()
		main._layout()
		main.hud.set_rival("Rival", main.race["rival"])
	else:
		main._choose(idx)


func _build_battle() -> void:
	main.started = true
	main.hud._overlay.visible = false
	if _o("shot", "") != "":
		main.paused = true   # the shot steps the battle itself, at a fixed rate
	var sim: GameSim = main.sim
	var lv: Level = sim.level
	sim.rng.seed = 99
	sim.gold = 999999
	sim.mana = sim.mana_max
	# Legal tower cells, nearest the roads first.
	var cells: Array = []
	for c: Vector2i in lv.terrain:
		if lv.road.has(c) or lv.is_lair(c) or sim.trees.has(c) or sim.sites.has(c) or lv.is_water(c):
			continue
		var t := lv.terrain_at(c)
		if not Defs.TOWERS.has(t) and not lv.high.has(c):
			continue
		var best := 99.0
		for r: Vector2i in lv.road:
			best = minf(best, Vector2(c - r).length())
		cells.append([best, c.y, c.x, c])
	cells.sort()
	var types := ["moss", "frost", "ash"]
	# Taken in turn from each kind of ground, nearest the roads first, so all three towers show.
	var by_type := {"moss": [], "frost": [], "ash": []}
	for e: Array in cells:
		var c: Vector2i = e[3]
		var t := lv.terrain_at(c)
		by_type[types[by_type["moss"].size() % 3] if lv.high.has(c) else t].append(c)
	var picks: Array = []
	var ti := 0
	while picks.size() < TOWERS and (by_type["moss"].size() + by_type["frost"].size() + by_type["ash"].size()) > 0:
		var list: Array = by_type[types[ti % 3]]
		ti += 1
		if not list.is_empty():
			picks.append([list.pop_front(), types[(ti - 1) % 3]])
	var n := 0
	for pk: Array in picks:
		var c: Vector2i = pk[0]
		var type: String = pk[1]
		if sim.do_action("build:" + type, c) != "":
			continue
		var tw: GameSim.Tower = sim.towers[c]
		tw.lvl = n % 4 + 1
		if tw.lvl == 4:
			tw.mastery = Defs.MASTERIES[type][(n / 4) % 2]["id"]
		if tw.lvl >= 3 and n % 2 == 0:
			tw.rank = 3   # its ability learned: the violet ring
		tw.born = -10.0
		n += 1
	# Half the buildings taken.
	var k := 0
	for s: GameSim.Site in sim.sites.values():
		if k % 2 == 0 and s.kind != "sluice":
			s.owned = true
			s.cuts_left = 0
		k += 1
	sim._relight()
	for w: Array in lv.waves:
		for code: String in w:
			if not _codes.has(code):
				_codes.append(code)
	sim.call_early()
	sim.call_early()
	if _o("scen", "") == "night" and sim.eclipse.x > 0.0:
		sim.time = sim.eclipse.x - sim.eclipse.y - 0.8   # the eclipse starts in a moment and lasts the run
	if _o("scen", "") == "tide" and sim.tide.x > 0.0:
		sim.time = sim.tide.x - sim.tide.y - 0.5         # high tide for the run
	var counts := {}
	for tw: GameSim.Tower in sim.towers.values():
		counts[tw.type] = int(counts.get(tw.type, 0)) + 1
	print("battle: lair %s, towers %s, sites %d" % [lv.title, counts, sim.sites.size()])
	_apply_off()
	_t0 = Time.get_ticks_msec()
	_last = Time.get_ticks_usec()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)


## Switches whole kinds of drawing off, to see what each costs.
func _apply_off() -> void:
	var off := _o("off", "")
	if off == "":
		return
	var board: Node2D = main.board
	for k in off.split(","):
		match k:
			"hud":
				main.hud.visible = false
				main.get_node("UI").visible = false
			"ripple":
				if main.ground._ripples:
					main.ground._ripples.visible = false
			"ground":
				main.ground.visible = false
			"bursts":
				board._bursts.visible = false
			_:
				board.perf_off[k] = true
	print("off: ", off)


## Keeps the map full: tops the heroes up to HEROES, keeps the hoard full and the battle from ending.
func _keep_busy() -> void:
	var sim: GameSim = main.sim
	if sim.over:
		return
	sim.lost = 0
	sim.home = sim.level.gems
	sim.gold = maxi(sim.gold, 5000)
	sim.timer = maxf(sim.timer, 5.0)
	var guard := 0
	while sim.enemies.size() < HEROES and guard < 20:
		guard += 1
		var code: String = _codes[_spawned % _codes.size()]
		var d: Dictionary = Defs.ENEMIES[code]
		_spawned += 1
		if d.has("boss"):
			continue
		var w := clampi(sim.wave, 1, sim.level.waves.size())
		var path := -1
		if not d.has("boat") and not d.has("fly"):
			var roads: Array[int] = sim.level.land_roads
			path = roads[_spawned % roads.size()]
		var dist := 0.0
		if path >= 0:
			dist = fmod(_spawned * 0.618, 1.0) * float(sim.level.paths[path]["total"]) * 0.7
		sim._spawn(code, path, dist, w)
		sim.enemies[-1].wave = 0   # outside the wave bookkeeping, like barracks troops


func _measure() -> void:
	var now := Time.get_ticks_usec()
	var dt := (now - _last) / 1000.0
	_last = now
	var el := (Time.get_ticks_msec() - _t0) / 1000.0
	var warm := float(_o("warm", "3"))
	var secs := float(_o("secs", "20"))
	if el < warm:
		return
	if _o("switch", "") != "" and el > warm + secs * 0.5 and not _switched:   # change quality mid-battle
		_switched = true
		Quality.set_choice(_o("switch", ""))
	if el > warm + secs:
		_report()
		quit(0)
		return
	_times.append(dt)
	_dc += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	_obj += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	_prim += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var vp := root.get_viewport_rid()
	_cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
	_gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	_proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_n += 1


func _report() -> void:
	var sorted := _times.duplicate()
	sorted.sort()
	var total := 0.0
	for t in sorted:
		total += t
	var cnt := sorted.size()
	var k := maxi(1, cnt / 100)
	var worst := 0.0
	for i in k:
		worst += sorted[cnt - 1 - i]
	worst /= k
	var sim: GameSim = main.sim
	var line := "PERF scen=%s quality=%s size=%sx%s off=%s frames=%d avg=%.2f worst1%%=%.2f max=%.2f dc=%d objects=%d primitives=%d cpu=%.2f gpu=%.2f process=%.2f heroes=%d towers=%d opening_max=%.1f atlas=%dx%.1fMpx bake=%.0fms" % [
		_o("scen", "day"), _o("quality", "detailed"), _o("w", "1720"), _o("h", "720"), _o("off", "-"), cnt,
		total / cnt, worst, sorted[cnt - 1], int(_dc / _n), int(_obj / _n), int(_prim / _n), _cpu / _n, _gpu / _n, _proc / _n,
		sim.enemies.size(), sim.towers.size(), _warm_max, SpriteCache.pages, SpriteCache.pixels / 1e6, SpriteCache.bake_ms]
	print(line)
	var out := _o("out", "")
	if out != "":
		var f := FileAccess.open(out, FileAccess.READ_WRITE if FileAccess.file_exists(out) else FileAccess.WRITE)
		f.seek_end()
		f.store_line(line)
		f.close()


## Screenshot mode: step the battle 5 s at a fixed rate (same picture on every run), freeze it and
## save one PNG once the pictures have had time to bake.
func _shot_step() -> bool:
	var sim: GameSim = main.sim
	if _phase == "setup":
		seed(4321)
		main.paused = true
		for i in 300:
			sim.update(1.0 / 60.0)
			_keep_busy()
		for e: GameSim.Enemy in sim.enemies:   # no hit flash mid-blink
			e.hit = 0.0
		if _o("ford", "") == "1":
			_on_fords()
		if _o("settings", "") == "1":
			SoundWindow.open(main.hud, main.hud)
		_phase = "wait"
		_shot_t = Time.get_ticks_msec()
		return false
	if Time.get_ticks_msec() - _shot_t > 2500:
		var img := root.get_texture().get_image()
		img.save_png(_o("shot", ""))
		print("saved ", _o("shot", ""))
		quit(0)
	return false


## Planks on every other ford, and two heroes on each ford stretch of the land roads.
func _on_fords() -> void:
	var sim: GameSim = main.sim
	var lv: Level = sim.level
	for i in lv.crossing_cells.size():
		if lv.crossing_kind[i] == "ford" and i % 2 == 0:
			sim.planks[i] = sim.time + 60.0
	var codes := ["f", "p", "k", "s"]
	var n := 0
	for p in lv.paths.size():
		for z: Dictionary in lv.zones[p]:
			if z["kind"] != "ford":
				continue
			for k in 2:
				sim._spawn(codes[n % codes.size()], p, lerpf(float(z["from"]), float(z["to"]), 0.3 + 0.4 * k), 0)
				sim.enemies[-1].wave = 0
				n += 1
