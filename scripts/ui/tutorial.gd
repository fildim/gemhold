class_name Tutorial
extends RefCounted
## Tips for the first lair, shown one at a time over the map while you play. Each tip waits for
## its moment (enough gold, loot on the ground, a hero with a gem...) and goes away once you do
## what it says, or when you tap it away. A tip whose lesson you already learned is skipped.
## Once all are done (or the lair is won) they never show again; Prefs remembers.

## [id, text]. Checked in this order, so earlier tips come first when several are ready.
const TIPS := [
	["build", "Tap the glowing green moss tile beside the road and build a [b]Warband Hut[/b]. Towers need their own ground: moss for Huts, frost for Crypts, ash for Shrines."],
	["wave", "Heroes march when the timer runs out. Tap [b]First wave[/b] to call them now and earn the seconds left as gold."],
	["carrier", "A hero has your gem! Kill him before he gets off the map and the gem floats back home."],
	["loot", "A slain hero dropped something. [b]Tap coins and potions[/b] to pick them up, or call the next wave early to gather them all."],
	["more", "Kills pay gold. Build more towers along the road; a [b]Bone Crypt[/b] on frost slows heroes down."],
	["upgrade", "You can afford an upgrade. [b]Tap a tower[/b] and upgrade it for more damage and range."],
	["woods", "[b]Tap the woods[/b] to clear them with mana. You get gold for the timber and a new place to build."],
	["meteor", "Meteor is ready. Tap [b]Meteor[/b], then tap a crowd of heroes."],
]
const CARRIER_TIME := 7.0     # the gem warning stays this long
const MORE_TIME := 14.0

var done := {}                # tip id -> true
var current := -1             # index into TIPS, or -1
var cell := Vector2i(-1, -1)  # a tile to point at, or (-1, -1)
var _shown := 0.0
var _trees := -1


## Whether the tips should run for this battle.
static func wanted(level_index: int, night: bool) -> bool:
	return level_index == 0 and not night and not Prefs.get_value("tutorial_done", false)


## Call every frame. Returns the tip to show (BBCode), or "" for none.
func update(sim: GameSim, dt: float) -> String:
	if _trees < 0:
		_trees = sim.trees.size()
	if current >= 0:
		_shown += dt
		if _finished(TIPS[current][0], sim):
			_close()
	if current < 0:
		for i in TIPS.size():
			var id: String = TIPS[i][0]
			if done.has(id):
				continue
			if _finished(id, sim):
				done[id] = true   # learned it without being told
			elif _ready(id, sim):
				current = i
				_shown = 0.0
				break
	if done.size() == TIPS.size() and not Prefs.get_value("tutorial_done", false):
		Prefs.set_value("tutorial_done", true)
	if _current_id() != "build":
		cell = Vector2i(-1, -1)
	elif cell.x < 0:
		cell = _best_hut_spot(sim)
	return TIPS[current][1] if current >= 0 else ""


## The tip's × button.
func dismiss() -> void:
	if current >= 0:
		_close()


func _close() -> void:
	done[TIPS[current][0]] = true
	current = -1
	cell = Vector2i(-1, -1)


func _ready(id: String, sim: GameSim) -> bool:
	match id:
		"build":
			return true
		"wave":
			return not sim.towers.is_empty()
		"carrier":
			return sim.enemies.any(func(e: GameSim.Enemy) -> bool: return e.carry > 0)
		"loot":
			return not sim.loot.is_empty()
		"more":
			return sim.wave >= 1 and sim.gold >= sim.build_cost("moss")
		"upgrade":
			return sim.wave >= 2 and sim.gold >= int(Defs.TOWERS["moss"]["cost"][1])
		"woods":
			return sim.wave >= 2 and sim.mana >= Defs.CLEAR_MANA and not sim.trees.is_empty()
		"meteor":
			return sim.wave >= 3 and sim.can_meteor()
	return false


func _finished(id: String, sim: GameSim) -> bool:
	match id:
		"build":
			return not sim.towers.is_empty()
		"wave":
			return sim.wave > 0
		"carrier":
			return id == _current_id() and _shown >= CARRIER_TIME
		"loot":
			return id == _current_id() and sim.loot.is_empty()
		"more":
			return sim.towers.size() >= 3 or (id == _current_id() and _shown >= MORE_TIME)
		"upgrade":
			return sim.towers.values().any(func(t: GameSim.Tower) -> bool: return t.lvl >= 2)
		"woods":
			return sim.trees.size() < _trees
		"meteor":
			return sim.fx.any(func(f: GameSim.Fx) -> bool: return f.kind == "meteor")
	return false


func _current_id() -> String:
	return TIPS[current][0] if current >= 0 else ""


## The free moss tile whose Hut would cover the most road.
func _best_hut_spot(sim: GameSim) -> Vector2i:
	var lv := sim.level
	var best := Vector2i(-1, -1)
	var best_n := 0
	for c: Vector2i in lv.terrain:
		if lv.terrain_at(c) != "moss" or sim.preview_range(c) <= 0.0 or sim.towers.has(c):
			continue
		var rg := float(Defs.TOWERS["moss"]["range"][0]) + sim._range_bonus("moss", c)
		var p := Vector2(c) + Vector2(0.5, 0.5)
		var n := 0
		for i in lv.paths.size():
			var total: float = lv.paths[i]["total"]
			var d := 0.0
			while d < total:
				if lv.path_pos(i, d).distance_to(p) <= rg:
					n += 1
				d += 0.25
		if n > best_n:
			best_n = n
			best = c
	return best
