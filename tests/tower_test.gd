extends SceneTree
## Puts two towers on the same stretch of road and sends set groups of heroes past them, for
## each tower type and level. Prints the share of hero health that got through (lower is
## better): first two towers of one type, then that type paired with a Warband Hut, which
## credits the Crypt's slow. Heroes get tougher with the tower level so the numbers stay apart.
## Run: godot --headless --script res://tests/tower_test.gd

const GROUPS := {
	"swarm": "16p", "footmen": "10f", "scouts": "10s", "knights": "3k", "mixed": "6p,4f,3s,1k,2c",
}
const HP_BY_LEVEL := [1.0, 1.8, 3.0]


func _init() -> void:
	var lv := Level.load_from("res://levels/level_01.json")
	var spots := _spots(lv)
	for lvl in [1, 2, 3]:
		for type in ["moss", "frost", "ash"]:
			var cells := []
			var total := 0.0
			var paired := 0.0
			for g: String in GROUPS:
				var leak := _run(lv, spots, [type, type], lvl, GROUPS[g])
				total += leak
				paired += _run(lv, spots, ["moss", type], lvl, GROUPS[g])
				cells.append("%s %3d%%" % [g, roundi(leak * 100.0)])
			print("level %d %-5s alone %3d%%  with hut %3d%% | %s" % [lvl, type, roundi(total / GROUPS.size() * 100.0),
				roundi(paired / GROUPS.size() * 100.0), " ".join(cells)])
	quit(0)


## Two free tiles next to the middle of the first road.
func _spots(lv: Level) -> Array[Vector2i]:
	var mid := lv.path_pos(0, float(lv.paths[0]["total"]) * 0.5)
	var out: Array[Vector2i] = []
	for c in lv.cols:
		for r in lv.rows:
			var v := Vector2i(c, r)
			if not lv.road.has(v) and not lv.is_lair(v):
				out.append(v)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (Vector2(a) + Vector2(0.5, 0.5)).distance_to(mid) < (Vector2(b) + Vector2(0.5, 0.5)).distance_to(mid))
	return out.slice(0, 2)


func _run(lv: Level, spots: Array[Vector2i], types: Array, lvl: int, group: String) -> float:
	var sim := GameSim.new(lv)
	sim.trees.clear()
	sim.timer = 1e9
	sim.home = 1000
	for i in spots.size():
		var tw := GameSim.Tower.new()
		tw.type = types[i]
		tw.lvl = lvl
		tw.cell = spots[i]
		tw.pos = Vector2(spots[i]) + Vector2(0.5, 0.5)
		sim.towers[spots[i]] = tw
	var list: Array[String] = []
	for part in group.split(","):
		for i in int(part.left(-1)):
			list.append(part.right(1))
	var max_total := 0.0
	var leaked := 0.0
	var spawn_t := 0.0
	var t := 0.0
	while t < 300.0:
		spawn_t -= 0.05
		if not list.is_empty() and spawn_t <= 0.0:
			spawn_t = Defs.SPAWN_INTERVAL
			sim._spawn(list.pop_front(), 0)
			var e: GameSim.Enemy = sim.enemies.back()
			e.hp *= HP_BY_LEVEL[lvl - 1]
			e.max_hp = e.hp
			max_total += e.max_hp
		sim.update(0.05)
		for e: GameSim.Enemy in sim.enemies:
			if e.dir == -1 and not e.gone:
				leaked += e.hp
				e.gone = true
		if list.is_empty() and sim.enemies.is_empty():
			break
		t += 0.05
	return leaked / max_total
