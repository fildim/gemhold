extends Node2D
## Shows the level map, boots the chosen level and wires the battle rules (GameSim) to the
## map views and the HUD. Handles taps on the map, spell targeting, speed and pause,
## and records results in the save file.

const T := 64.0
## Campaign order. Add new level files here. File numbers follow when each map was made, not its place in the campaign, so
## level ids (and the saved progress keyed by them) stay put when the campaign is reordered.
const LEVELS: Array[String] = ["res://levels/level_01.json", "res://levels/level_02.json", "res://levels/level_03.json", "res://levels/level_09.json", "res://levels/level_04.json", "res://levels/level_06.json", "res://levels/level_10.json", "res://levels/level_07.json", "res://levels/level_11.json", "res://levels/level_08.json", "res://levels/level_12.json", "res://levels/level_13.json", "res://levels/level_14.json", "res://levels/level_15.json", "res://levels/level_16.json", "res://levels/level_17.json", "res://levels/level_18.json", "res://levels/level_19.json", "res://levels/level_20.json", "res://levels/level_05.json"]
## Each lair's battle music, by level id (tracks in assets/music, credits in CREDITS.md there).
const MUSIC := {"level_01": "mountain", "level_02": "heroicage", "level_03": "curseofthescarab", "level_09": "preludeandaction",
	"level_04": "volatilereaction", "level_06": "crusade", "level_10": "firebrand", "level_07": "fate", "level_11": "killers",
	"level_08": "fivearmies", "level_12": "rynostheme", "level_13": "darkling", "level_14": "malicious", "level_15": "ossuary2_turn",
	"level_16": "unholyknight", "level_17": "blackvortex", "level_18": "orchestralbattle", "level_19": "finalbattleofthedarkwizards",
	"level_20": "finalbattle", "level_05": "valkyries"}

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
var tutorial: Tutorial        # tips on the first lair, or null
var spot: Control             # the tutorial spotlight, over everything
var _site_tip := ""           # building kind the tip on screen explains, or ""
var _hero_tip := ""           # hero code the tip on screen introduces, or ""
var guide: Control            # the player's guide, opened from the map
var _arts_spent := -1         # skill points spent when the Dark Arts tip opened
var _arts_intro := false      # the Dark Arts intro tip is up
var _race_intro := false      # a race walkthrough tip is up (Prefs "race_tip": the next one to show)
var online: Online            # the optional account and leaderboard
var hall: Control             # Hall of Fame: leaderboard, achievements, account
var _ids: Array = []          # every lair's level id, campaign order
var race := {}                # the online race being played (Online.race_get + "side"), or {}
var _race_t := 0.0            # seconds to the next progress report
var _race_busy := false

@onready var frame: Control = $MapFrame
@onready var ground: Node2D = $MapFrame/Ground
@onready var board: Node2D = $MapFrame/Board
@onready var hud: Control = $UI/HUD
@onready var select: Control = $UI/LevelSelect
@onready var skill_tree: Control = $UI/SkillTree


func _ready() -> void:
	hud.next_wave_pressed.connect(_on_next_wave)
	hud.meteor_pressed.connect(_on_meteor)
	hud.cut_pressed.connect(_on_cut)
	hud.speed_pressed.connect(func() -> void: speed = 2 if speed == 1 else 1)
	hud.pause_pressed.connect(func() -> void: paused = not paused)
	hud.action_pressed.connect(_on_action)
	hud.popup_closed.connect(_deselect)
	hud.start_pressed.connect(func() -> void: started = true)
	hud.night_pressed.connect(_start_night)
	hud.restart_pressed.connect(_restart)
	hud.next_level_pressed.connect(func() -> void: _choose(level_index + 1))
	hud.map_pressed.connect(_show_map)
	spot = preload("res://scripts/ui/spotlight.gd").new()
	$UI.add_child(spot)
	spot.setup(hud)
	spot.ok_pressed.connect(_on_tip_ok)
	spot.skip_pressed.connect(_on_tip_skip)
	frame.gui_input.connect(_on_map_input)
	get_viewport().size_changed.connect(_layout)
	save = SaveData.load_from()
	online = Online.new()
	add_child(online)
	online.merged.connect(_on_account_merged)
	var infos := []
	for p in LEVELS:
		var lv := Level.load_from(p)
		infos.append({"id": lv.id, "title": lv.title, "waves": lv.waves.size()})
		_ids.append(lv.id)
	select.setup(hud, infos, save)
	select.level_chosen.connect(_choose)
	skill_tree.setup(hud, save)
	guide = preload("res://scripts/ui/guide_screen.gd").new()
	$UI.add_child(guide)
	guide.setup(hud)
	select.guide_pressed.connect(guide.open)
	hall = preload("res://scripts/ui/hall.gd").new()
	$UI.add_child(hall)
	hall.setup(hud, save, online, infos)
	select.hall_pressed.connect(hall.open)
	select.full_unlocked.connect(func() -> void: online.sync(save))   # remember it on the account
	hall.closed.connect(func() -> void: hall.visible = false)
	hall.race_ready.connect(_start_race)
	$UI.move_child(spot, -1)   # the spotlight stays over every screen, the Hall of Fame included
	hud.send_pressed.connect(_on_send)
	guide.closed.connect(func() -> void: guide.visible = false)
	select.skills_pressed.connect(func() -> void:
		skill_tree.refresh()
		skill_tree.visible = true)
	skill_tree.closed.connect(func() -> void:
		skill_tree.visible = false
		_announce(Achievements.check_progress(save, _ids))
		select.refresh())
	# Keep a level loaded behind the map so the views always have something to draw.
	_load_level(clampi(save.unlocked - 1, 0, LEVELS.size() - 1))
	_show_map()
	_layout.call_deferred()
	# Players from before achievements existed get the campaign ones they already earned.
	Achievements.check_progress(save, _ids)
	save.save()
	online.sync(save)


## Progress arrived from the player's other device: show it if the map is up.
func _on_account_merged() -> void:
	if not on_map:
		return
	_announce(Achievements.check_progress(save, _ids))
	select.refresh()
	if skill_tree.visible:
		skill_tree.refresh()


func _show_map() -> void:
	_leave_race()
	on_map = true
	started = false
	_deselect()
	frame.visible = false
	hud.set_battle_visible(false)
	select.refresh()
	select.visible = true
	Sfx.set_beams(0)
	Sfx.play_music("map")


func _choose(i: int) -> void:
	if i < 0 or i >= LEVELS.size() or not save.is_unlocked(i):
		return
	if Edition.locked(i):   # "Next" on the last demo lair
		_show_map()
		select.offer_full_game()
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
	sim = GameSim.new(level, save.skills if race.is_empty() else {})   # races are fair: no Dark Arts
	sim.toast.connect(hud.toast)
	sim.ended.connect(_on_ended)
	sim.sound.connect(Sfx.play)
	tutorial = Tutorial.new() if Tutorial.wanted(level_index, night) and race.is_empty() else null
	hud.reset_rating()
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
	if not race.is_empty():
		_race_t -= delta
		if _race_t <= 0.0 and not _race_busy:
			_race_tick()
	if on_map:
		_arts_tip()
		return
	# While a tutorial tip is up the battle stands still.
	var tip := ""
	if tutorial and started and not sim.over:
		tutorial.update(sim, armed)
		tip = tutorial.text(armed)
	var site_cell := Vector2i(-1, -1)
	var hero: GameSim.Enemy = null
	_site_tip = ""
	_hero_tip = ""
	if tip == "" and started and not sim.over and race.is_empty():   # tips freeze the battle: never in a race
		site_cell = _site_tip_cell()
		if site_cell.x >= 0:
			tip = _site_tip_text(sim.sites[site_cell])
		else:
			hero = _new_hero()
			if hero:
				tip = "[b]New hero: %s[/b]\n%s" % [hero.d["name"], Defs.HERO_TIPS.get(hero.code, "")]
	if site_cell.x >= 0:
		spot.show_tip(tip, _cell_rect(Vector2(site_cell)), true, "No more tips")
	elif hero:
		spot.show_tip(tip, _cell_rect(hero.pos - Vector2(0.75, 0.9), Vector2(1.5, 1.5)), true, "No more tips")
	elif tip != "":
		spot.show_tip(tip, _tip_rect(tutorial.target), tutorial.has_ok())
	else:
		spot.hide_tip()
	if started and not paused and not sim.over and tip == "":
		var dt := minf(delta, 0.05)
		for i in speed:
			sim.update(dt)
	var running := started and not paused and not sim.over and tip == ""
	var beams := 0
	if running:
		for tw: GameSim.Tower in sim.towers.values():
			if tw.beam != null:
				beams += 1
	Sfx.set_beams(beams)
	Sfx.play_music("" if sim.over else (MUSIC.get(level.id, "mountain") if started else "map"))
	board.armed = armed
	board.queue_redraw()
	hud.refresh(sim, armed, speed, paused)


## The first time a hero of a kind walks onto the map, the battle stops and a tip introduces him
## (Prefs "hero_tip_<code>"). Returns that hero, or null.
func _new_hero() -> GameSim.Enemy:
	var bounds := Rect2(0.3, 0.3, level.cols - 0.6, level.rows - 0.6)
	for e: GameSim.Enemy in sim.enemies:
		if e.hp > 0.0 and bounds.has_point(e.pos) and not Prefs.get_value("hero_tip_" + e.code, false):
			_hero_tip = e.code
			return e
	return null


## The first time a lair has a barracks, mine or well, a tip explains it (Prefs "building_tip_<kind>").
## Returns the cell of a building still to explain, or (-1, -1).
func _site_tip_cell() -> Vector2i:
	for s: GameSim.Site in sim.sites.values():
		if not s.owned and not Prefs.get_value("building_tip_" + s.kind, false):
			_site_tip = s.kind
			return s.cell
	_site_tip = ""
	return Vector2i(-1, -1)


func _site_tip_text(s: GameSim.Site) -> String:
	var kind := s.kind
	var d: Dictionary = Defs.SITES[kind]
	var t := ""
	match kind:
		"camp":
			t = "[b]Hero Barracks![/b] It sends extra heroes onto the road while waves are coming. [b]Tap it and Raze it[/b] with mana to stop them and win %d gold." % d["bounty"]
		"mine":
			t = "[b]A Gold Mine[/b], overgrown. [b]Tap it and Cut it free[/b] with mana; then it pays %d gold every %d s for the rest of the battle." % [d["gold"], int(d["every"])]
		"well":
			t = "[b]A Mana Well[/b], choked with roots. [b]Tap it and Cut it free[/b] with mana for +%.1f mana per second, so you can cast and cut more." % d["regen"]
	if s.cuts > 1:
		t += " This one takes [b]%d cuts[/b] (the dots under it)." % s.cuts
	return t


## Screen rectangle for what a tutorial tip points at (see Tutorial.target).
func _tip_rect(t: Dictionary) -> Rect2:
	if t.has("cell"):
		var c: Vector2i = t["cell"]
		if hud.popup_open() and selected != c:
			_deselect()   # a panel for some other tile: close it so the right one can open
		var r: Rect2 = hud.action_rect(t["action"]) if selected == c else Rect2()
		return r if r.has_area() else _cell_rect(c)
	if t.has("button"):
		return hud.button_rect(t["button"])
	if t.has("at"):
		var p: Vector2 = t["at"]
		return _cell_rect(Vector2(p.x - 0.75, p.y - 0.9), Vector2(1.5, 1.5))
	if t.has("map"):
		return _cell_rect(Vector2.ZERO, Vector2(level.cols, level.rows))
	return Rect2()


## A rectangle in tiles (a tile by default) as a rectangle on screen.
func _cell_rect(c: Vector2, tiles := Vector2.ONE) -> Rect2:
	var xf := frame.get_global_transform_with_canvas()
	return Rect2(xf * (c * T), tiles * T * frame.scale)


func _on_tip_ok() -> void:
	if not on_map and _site_tip != "":
		Prefs.set_value("building_tip_" + _site_tip, true)
		_site_tip = ""
		spot.hide_tip()
		return
	if not on_map and _hero_tip != "":
		Prefs.set_value("hero_tip_" + _hero_tip, true)
		_hero_tip = ""
		spot.hide_tip()
		return
	if not on_map and tutorial:
		tutorial.dismiss()
	elif _race_intro:
		Prefs.set_value("race_tip", int(Prefs.get_value("race_tip", 0)) + 1)
	elif _arts_intro:
		Prefs.set_value("arts_intro", true)
	else:
		Prefs.set_value("arts_tip", 2)
	spot.hide_tip()


## "Skip tutorial" ends the first lair's lessons and the Dark Arts tips; "No more tips" on a
## building or hero tip stops those. Each leaves the other kind alone.
func _on_tip_skip() -> void:
	if on_map and _race_intro:
		Prefs.set_value("race_tip", RACE_TIPS.size())
		spot.hide_tip()
		return
	if not on_map and (_site_tip != "" or _hero_tip != ""):
		for k in Defs.SITES:
			Prefs.set_value("building_tip_" + k, true)
		for k in Defs.ENEMIES:
			Prefs.set_value("hero_tip_" + k, true)
		_site_tip = ""
		_hero_tip = ""
		spot.hide_tip()
		return
	if tutorial:
		tutorial.finish()
		tutorial = null
	Prefs.set_value("tutorial_done", true)
	Prefs.set_value("arts_tip", 2)
	Prefs.set_value("arts_intro", true)
	Prefs.set_value("race_tip", RACE_TIPS.size())
	spot.hide_tip()


## The Dark Arts tips, on the level map. The first time Dark Arts opens, a tip explains it
## (arts_intro in Prefs). Once there is a point to spend: open Dark Arts, buy a skill, then a
## word on refunds (arts_tip: 0 not yet, 1 a skill was bought, 2 done).
func _arts_tip() -> void:
	var stage: int = Prefs.get_value("arts_tip", 0)
	_arts_intro = false
	if _race_tip():
		return
	if not select.visible or guide.visible or hall.visible:
		spot.hide_tip()
		return
	if skill_tree.visible and not Prefs.get_value("arts_intro", false):
		_arts_intro = true
		spot.show_tip(skill_tree.INTRO, Rect2(), true)
		return
	if stage >= 2:
		spot.hide_tip()
		return
	if not skill_tree.visible:
		if stage == 1:
			Prefs.set_value("arts_tip", 2)   # closed the tree after buying: done
		if stage == 0 and save.points_free() > 0:
			spot.show_tip("[b]You earned stars![/b] Every star is a skill point for your dark powers. [b]Tap Dark Arts[/b] to spend them.", select.skills_rect(), false)
		else:
			spot.hide_tip()
		return
	if stage == 0:
		if _arts_spent < 0:
			_arts_spent = save.points_spent()
		if save.points_spent() > _arts_spent:
			Prefs.set_value("arts_tip", 1)
			return
		var r: Rect2 = skill_tree.first_buyable_rect()
		if r.has_area():
			spot.show_tip("[b]Tap a skill[/b] to buy a rank with one of your points.", r, false)
		else:
			spot.hide_tip()
	else:
		spot.show_tip("Skills work in every battle from now on. Not happy with your choice? [b]Refund all points[/b] (top right) and spend them again. Earn more stars by beating lairs with better ratings and at night.", skill_tree.reset_rect(), true)


## Fit the map into the space the HUD leaves free, keeping its proportions.
func _layout() -> void:
	var map_px := Vector2(level.cols, level.rows) * T
	hud.map_aspect = map_px.x / map_px.y
	hud.relayout()
	var area: Rect2 = hud.map_area
	var s := minf(area.size.x / map_px.x, area.size.y / map_px.y)
	frame.scale = Vector2(s, s)
	frame.position = area.position + (area.size - map_px * s) / 2.0


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
	if level.in_bounds(c) and level.road.has(c) and not sim.sites.has(c):
		hud.toast("Nothing can be built on the hero road")   # a passing note, no panel to close
	elif level.in_bounds(c):
		_select(c)


func _select(c: Vector2i) -> void:
	selected = c
	board.selected = c
	var xf := frame.get_global_transform_with_canvas()
	var rect := Rect2(xf * (Vector2(c) * T), Vector2(T, T) * frame.scale)
	var rg := sim.preview_range(c)
	var circle := _cell_rect(Vector2(c) + Vector2(0.5 - rg, 0.5 - rg), Vector2(rg, rg) * 2.0) if rg > 0.0 else Rect2()
	hud.show_popup(sim.cell_info(c), rect, circle)


func _deselect() -> void:
	selected = Vector2i(-1, -1)
	board.selected = selected
	hud.hide_popup()


func _on_action(id: String) -> void:
	var c := selected
	var err := sim.do_action(id, c)
	if err != "":
		hud.toast(err)
		Sfx.play("error")
		return
	if id.begins_with("build") or id == "sell" or id == "clear":
		_deselect()
	else:
		_select(c)


func _on_next_wave() -> void:
	if started and not sim.over:
		sim.call_early()


## Cuts a random patch of woods for mana (and timber gold).
func _on_cut() -> void:
	if not started or sim.over:
		return
	var err := sim.cut_random_woods()
	if err != "":
		hud.toast(err)
		Sfx.play("error")


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
	Sfx.set_beams(0)
	Sfx.play("win" if won else "lose")
	if won and tutorial:
		tutorial.finish()   # beat the first lair: no more tips
		tutorial = null
	spot.hide_tip()
	_deselect()
	if not race.is_empty():
		race["t_end"] = Time.get_ticks_msec()   # the race clock stops
		_race_t = 0.0   # report the finish now; the race card shows when the rival's answer is in
		hud.show_race_end(Online.race_progress(sim, false, _race_secs()), race.get("rival", Online.race_progress()), _rival_name())
		return
	var had_night := save.night_unlocked(level.id)
	var mission := SaveData.mission_id(level.id, night)
	var stars_before := save.stars(mission)
	var new_best := save.record(level_index, mission, sim.rank(), level.gems - sim.lost, won)
	var score := sim.score(level_index + 1)
	var old_score := int(save.scores.get(mission, 0))
	save.record_score(mission, score)
	Achievements.record(save, sim)
	var got := Achievements.check_battle(save, sim, level_index + 1)
	got.append_array(Achievements.check_progress(save, _ids))
	save.save()
	online.sync(save)
	var night_opened := not had_night and save.night_unlocked(level.id)
	hud.show_end(sim, level_index + 1 < LEVELS.size(), new_best, save.stars(mission) - stars_before, save.points_free(), night_opened,
		score, old_score, got)


## Android back button: close the panel, cancel the meteor, or pause. On the map it closes the
## Guide or Dark Arts, or quits.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if on_map and hall.visible:
			hall.visible = false
		elif on_map and guide.visible:
			guide.visible = false
		elif on_map and skill_tree.visible:
			skill_tree.closed.emit()
		elif on_map:
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


## Newly earned achievements outside a battle (the end card lists those from battles).
func _announce(ids: Array[String]) -> void:
	if ids.is_empty():
		return
	save.save()
	online.sync(save)
	var names := ids.map(func(id: String) -> String: return Achievements.find(id)["name"])
	hud.toast("Achievement: " + ", ".join(names))
	Sfx.play("rank")


# ---------------------------------------------------------------- online race

## A race has begun (from the Hall of Fame): play its lair (by day or night) at once, without Dark Arts.
func _start_race(r: Dictionary, side: String) -> void:
	var i := _ids.find(r["level"])
	if i < 0:
		hud.toast("That lair is not in this version of the game: update it")
		return
	if Edition.locked(i):
		hud.toast("That lair is only in the full game")
		return
	race = r.duplicate()
	race["side"] = side
	race["rival"] = r["g" if side == "h" else "h"]
	race["t0"] = Time.get_ticks_msec()
	race["got"] = 0   # how many of the rival's sent heroes have marched in here
	_race_t = 0.0
	hall.visible = false
	on_map = false
	select.visible = false
	frame.visible = true
	hud.set_battle_visible(true)
	night = bool(r.get("night", false))
	_load_level(i)
	sim.race_on = true
	_layout()
	started = true
	hud.set_rival(_rival_name(), race["rival"])
	hud.toast("Race against %s: go!" % _rival_name())
	Sfx.play("horn")


func _rival_name() -> String:
	return str(race.get("guest_name" if race.get("side") == "h" else "host_name", "Rival"))


## Every couple of seconds: send this player's progress (when it changed) and fetch the rival's.
func _race_tick() -> void:
	_race_busy = true
	_race_t = 2.5
	var code: String = race["code"]
	var side: String = race["side"]
	var me := Online.race_progress(sim, false, _race_secs())
	if me != race.get("sent", {}):
		if await online.race_report(code, side, me) == "" and race.get("code") == code:
			race["sent"] = me
	var r := await online.race_get(code)
	_race_busy = false
	if race.get("code") != code or r.has("error"):
		return
	var rival: Dictionary = r["g" if side == "h" else "h"]
	var out := str(rival.get("out", ""))
	var fresh := out.substr(int(race["got"]))
	race["got"] = out.length()
	if fresh != "" and not sim.over:
		var names := []
		for c in fresh:
			sim.race_receive(c)
			if Defs.ENEMIES.has(c):
				names.append(Defs.ENEMIES[c]["name"])
		hud.toast("%s sent you: %s" % [_rival_name(), ", ".join(names)])
	if rival.get("done", false) and not sim.over:
		# The race is over for both the moment one finishes or falls.
		race["rival"] = rival
		hud.set_rival(_rival_name(), rival)
		hud.toast("%s %s: the race is over" % [_rival_name(), "finished first" if rival.get("won", false) else "fell"])
		sim.race_stop()   # ends the battle here (_on_ended); the next tick tells the rival
		return
	race["rival"] = rival
	hud.set_rival(_rival_name(), rival)
	if sim.over:
		hud.show_race_end(me, rival, _rival_name())
		if rival.get("done", false) and race.get("sent", {}) == me:
			_record_race(Online.race_compare(me, rival))
			_race_t = INF   # both finished and told: nothing more to send or fetch


## Counts a decided race once in the record (1 won, -1 lost, 0 drawn) and puts it online.
func _record_race(result: int) -> void:
	if race.get("recorded", false):
		return
	race["recorded"] = true
	save.add_stat({1: "race_wins", -1: "race_losses"}.get(result, "race_draws"), 1)
	save.add_stat("races", 1)
	_announce(Achievements.check_progress(save, _ids))
	save.save()
	online.sync(save)


## Leaving a race before it is over gives it up: the rival is told this player fell, and it counts
## as lost. Leaving after finishing while the rival's answer is still on its way records the result
## it must have: the rival is stopped where they stand.
func _leave_race() -> void:
	if race.is_empty():
		return
	var p := Online.race_progress(sim, true, _race_secs())   # unfinished counts as fallen (sim.won is false)
	if p != race.get("sent", {}):
		online.race_report(race["code"], race["side"], p)
	if not sim.over:
		_record_race(-1)
	else:
		var rival: Dictionary = race.get("rival", Online.race_progress()).duplicate()
		if not rival.get("done", false):
			rival["done"] = true
			rival["stopped"] = true
		_record_race(Online.race_compare(p, rival))
	race = {}
	hud.set_rival("")


## Seconds on the race clock: from the start until this player finished (or now).
func _race_secs() -> int:
	return int((int(race.get("t_end", Time.get_ticks_msec())) - int(race.get("t0", 0))) / 1000)


func _on_send(code: String) -> void:
	if race.is_empty() or not started:
		return
	var err := sim.race_buy(code)
	if err != "":
		hud.toast(err)
		Sfx.play("error")
		return
	hud.toast("%s sent to %s" % [Defs.ENEMIES[code]["name"], _rival_name()])
	_race_t = 0.0   # tell the rival now


## The race walkthrough: the first time the Race page opens (signed in), three tips show how to host,
## how to join and how a race goes. Each OK moves on (Prefs "race_tip"); "No more tips" ends it.
const RACE_TIPS := [
	["host", "[b]Race a friend![/b] Pick a lair (night missions you have opened are there too) and tap [b]Host a race[/b]. You get a 5-letter code to give your friend."],
	["join", "Got a code from a friend? Type it here and tap [b]Join[/b]. The race starts for both of you at once."],
	["", "[b]In the race[/b] you both play the same lair with no Dark Arts. Every %d heroes you slay sends one to your rival, and [b]Send heroes[/b] (where Pause was) buys more with gold. The moment one of you clears the last wave or falls, the race is over: clear it first to win. Leaving counts as a loss." % Defs.RACE_KILL_SEND],
]


func _race_tip() -> bool:
	_race_intro = false
	var stage: int = Prefs.get_value("race_tip", 0)
	if stage >= RACE_TIPS.size() or not hall.race_page_open():
		return false
	var t: Array = RACE_TIPS[stage]
	_race_intro = true
	spot.show_tip(t[1], hall.race_rect(t[0]) if t[0] != "" else Rect2(), true, "No more tips")
	return true
