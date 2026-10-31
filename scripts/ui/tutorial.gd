class_name Tutorial
extends RefCounted
## Tips for the first lair, one at a time. While a tip is up the battle is frozen and the screen
## dark except for the one thing it is about (see spotlight.gd), so the player does that and
## nothing else. Each tip waits for its moment (enough gold, loot on the ground, a hero with a
## gem...) and ends when the player does what it says, or taps "Got it" on tips that only explain.
## A tip whose lesson the player already learned is skipped. Once all are done (or the lair is
## won, or the player skips the tutorial) they never show again; Prefs remembers.

## [id, text, "Got it" button]. Checked in this order, so earlier tips come first.
const TIPS := [
	["build", "Heroes walk the road to steal your gems. Stop them with towers.\n[b]Tap the lit moss tile[/b], then build a [b]Warband Hut[/b] there. Each tower needs its own ground: moss for Huts, frost for Crypts, ash for Shrines.", false],
	["wave", "Heroes march when the timer runs out. [b]Tap First wave[/b] to call them now and earn the seconds left as gold.", false],
	["carrier", "[b]This hero has your gem![/b] Kill him before he gets off the map and the gem floats back home. Other heroes will go for it on the way, so keep killing.", true],
	["loot", "A slain hero dropped something. [b]Tap it[/b] to pick it up now; anything left lying around is gathered when the next wave starts.", true],
	["woods", "[b]Tap the woods[/b], then [b]Cut woods[/b]. Woods block good spots along the road. Cutting costs mana, pays gold for the timber and opens the ground for a tower. On later lairs the woods also hide [b]Gold Mines[/b] and [b]Mana Wells[/b] you can cut free the same way.", false],
	["more", "Kills pay gold. Build more towers along the road. A [b]Bone Crypt[/b] on frost slows heroes down; a [b]Cinder Shrine[/b] on ash burns through armour.", true],
	["upgrade", "You can afford an upgrade. [b]Tap your tower[/b], then [b]Upgrade[/b] for more damage and range.", false],
	["meteor", "Meteor is ready. [b]Tap Meteor[/b]...", false],
]

var done := {}                # tip id -> true
var current := -1             # index into TIPS, or -1
var target := {}              # what to light up: {"cell", "action"}, {"button"}, {"at"} or {"map"}
var _trees := -1
var _loot := 0               # loot on the map when the loot tip came up


## Whether the tips should run for this battle.
static func wanted(level_index: int, night: bool) -> bool:
	return level_index == 0 and not night and not Prefs.get_value("tutorial_done", false)


## Call every frame while the battle runs. armed: the meteor is waiting for a target.
func update(sim: GameSim, armed := false) -> void:
	if _trees < 0:
		_trees = sim.trees.size()
	if current >= 0 and _finished(_current_id(), sim):
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
				_loot = sim.loot.size()
				break
	if done.size() == TIPS.size():
		finish()
	target = _target(sim, armed) if current >= 0 else {}


## The tip to show, or "" for none.
func text(armed := false) -> String:
	if current < 0:
		return ""
	if _current_id() == "meteor" and armed:
		return "Now [b]tap a crowd of heroes[/b] on the map. The meteor lands a moment later."
	return TIPS[current][1]


## Whether the tip has a "Got it" button (it only explains; there is nothing to tap).
func has_ok() -> bool:
	return current >= 0 and TIPS[current][2]


## "Got it".
func dismiss() -> void:
	if current >= 0:
		_close()


## Never show tips again.
func finish() -> void:
	if not Prefs.get_value("tutorial_done", false):
		Prefs.set_value("tutorial_done", true)


func _close() -> void:
	done[_current_id()] = true
	current = -1
	target = {}


func _current_id() -> String:
	return TIPS[current][0] if current >= 0 else ""


func _ready(id: String, sim: GameSim) -> bool:
	match id:
		"build":
			return true
		"wave":
			return not sim.towers.is_empty()
		"carrier":
			return _carrier(sim) != null
		"loot":
			return not sim.loot.is_empty()
		"more":
			return sim.wave >= 1 and sim.gold >= sim.build_cost("moss")
		"upgrade":
			return sim.wave >= 2 and sim.gold >= int(Defs.TOWERS["moss"]["cost"][1]) and not sim.towers.is_empty()
		"woods":
			return sim.wave >= 1 and sim.mana >= Defs.CLEAR_MANA and _woods_spot(sim).x >= 0
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
			return id == _current_id() and _carrier(sim) == null
		"loot":
			return id == _current_id() and sim.loot.size() < _loot
		"upgrade":
			return sim.towers.values().any(func(t: GameSim.Tower) -> bool: return t.lvl >= 2)
		"woods":
			return sim.trees.size() < _trees
		"meteor":
			return sim.fx.any(func(f: GameSim.Fx) -> bool: return f.kind == "meteor")
	return false


func _target(sim: GameSim, armed: bool) -> Dictionary:
	match _current_id():
		"build":
			if not target.has("cell"):
				return {"cell": _best_hut_spot(sim), "action": "build:moss"}
			return target   # keep pointing at the same tile
		"wave":
			return {"button": "next"}
		"carrier":
			var e := _carrier(sim)
			return {"at": e.pos} if e else {}
		"loot":
			return {"at": sim.loot[0].pos}
		"upgrade":
			var tw: GameSim.Tower = sim.towers.values()[0]
			return {"cell": tw.cell, "action": "upgrade"}
		"woods":
			return {"cell": _woods_spot(sim), "action": "clear"}
		"meteor":
			return {"map": true} if armed else {"button": "meteor"}
	return {}


func _carrier(sim: GameSim) -> GameSim.Enemy:
	for e: GameSim.Enemy in sim.enemies:
		if e.carry > 0 and e.hp > 0.0:
			return e
	return null


## The woods tile nearest the lair (clearing it opens ground where it matters).
func _woods_spot(sim: GameSim) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for c: Vector2i in sim.trees:
		var d := (Vector2(c) + Vector2(0.5, 0.5)).distance_to(sim.level.lair_center)
		if d < best_d:
			best_d = d
			best = c
	return best


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
