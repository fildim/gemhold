class_name GameSim
extends RefCounted
## The rules of one battle: heroes, towers, spells, waves, gems, map buildings and loot.
## No drawing code lives here, so battles can run headless in tests.

const COVER_STEP := 0.25   # tiles between samples when measuring how much of a road is defended

signal toast(text: String)
signal ended(won: bool)
signal ground_changed
signal light_changed
## A sound effect to play (see Sfx.SFX): the rules say what happened, the view decides how it sounds.
signal sound(name: String)


class Enemy:
	var code := ""
	var d: Dictionary
	var path := 0
	var hp := 0.0
	var max_hp := 0.0
	var dist := 0.0
	var dir := 1          # 1 = walking to the lair, -1 = running away
	var carry := 0
	var slow := 0.0       # seconds of slow left
	var slow_amt := 0.0
	var fear := 0.0       # seconds of terror left (Dread)
	var pos := Vector2.ZERO
	var face := 1
	var bob := 0.0
	var gone := false
	var wave := 0         # which wave it marched with, 0 for barracks troops


class Tower:
	var type := ""
	var lvl := 1
	var cd := 0.0
	var cell := Vector2i.ZERO
	var pos := Vector2.ZERO
	var spent := 0
	var flash := 0.0
	var xp := 0.0
	var rank := 0         # veterancy, 0..3
	var beam: Enemy       # Cinder Shrine: the hero it is burning, or null
	var heat := 0.0       # Cinder Shrine: 0..1, see Defs.HEAT_TIME
	# Permanent bonuses from the skill tree, filled in when the tower is built.
	var dmg_mul := 1.0
	var rate_mul := 1.0
	var range_add := 0.0
	var xp_mul := 1.0
	var ability_rank := 0

	func stat(key: String) -> float:
		var v := float(Defs.TOWERS[type][key][lvl - 1])
		match key:
			"dmg":
				return v * dmg_mul * (1.0 + Defs.RANK_DMG * rank)
			"rate":
				return v / rate_mul
			"range":
				return v + range_add
		return v

	func has_ability() -> bool:
		return rank >= Defs.ABILITY_RANK and lvl >= Defs.ABILITY_LEVEL

	## Ability strength: Volley damage share, Dread chance, or Lava damage per second as a share of
	## the beam at full heat.
	func ability_power() -> float:
		var a: Dictionary = Defs.ABILITIES[type]
		return a["base"] + a["per_rank"] * ability_rank


class Shot:
	var kind := ""
	var pos := Vector2.ZERO
	var target: Enemy
	var tpos := Vector2.ZERO
	var dmg := 0.0
	var slow := 0.0
	var fear := 0.0       # chance to terrify on hit
	var pierce := false   # ignores armour (den bolts)
	var src: Tower        # gets the XP for damage dealt
	var spd := 8.0
	var done := false


## Gems dropped by a slain carrier. They roll back to the lair along the road they fell on.
class Drop:
	var pos := Vector2.ZERO
	var n := 0
	var path := 0
	var dist := 0.0


class Loot:
	var kind := ""        # "coin" | "potion"
	var pos := Vector2.ZERO
	var amount := 0
	var t := 0.0


class Pool:
	var pos := Vector2.ZERO
	var r := 0.0
	var dps := 0.0
	var t := 0.0
	var dur := 3.0
	var src: Tower


class Site:
	var kind := ""        # "mine" | "well" | "camp"
	var cell := Vector2i.ZERO
	var pos := Vector2.ZERO
	var owned := false    # mines and wells: cut free; camps: razed
	var t := 0.0
	var path := 0
	var spawn: Array[String] = []
	var every := 25.0
	var dist := 0.0       # where camp troops join their road


class Fx:
	var kind := ""        # "boom" | "meteor" | "text"
	var pos := Vector2.ZERO
	var r := 0.0
	var t := 0.0
	var dur := 1.0
	var text := ""
	var color := Color.WHITE
	var hit := false


var level: Level
var skills := {}          # skill id -> rank, from the save file
var gold := 0
var mana := 0.0
var mana_max := 100.0     # base plus Dark Arts points
var home := 0
var lost := 0
var wave := 0
var timer := 0.0
var queue: Array[String] = []
var queue_wave: Array[int] = []   # the wave each queued hero belongs to
var threat := 1.0         # dynamic difficulty: multiplies hero health, see _judge_wave
var wave_left := {}       # wave -> its heroes still queued or on the map
var wave_peak := {}       # wave -> most of the defended road any of its heroes got through
var _cover := {}          # road -> defended length up to each COVER_STEP along it; empty = rebuild
var spawn_t := 0.0
var lane := 0
var enemies: Array = []
var towers := {}          # Vector2i -> Tower
var shots: Array = []
var drops: Array = []
var loot: Array = []
var pools: Array = []
var sites := {}           # Vector2i -> Site
var fx: Array = []
var trees := {}           # Vector2i -> true (woods still standing)
var lit := {}             # Vector2i -> true, night levels only
var den_max := 0          # den charges when full: base plus one per Den skill point
var den_charges := 0
var den_refill := 0.0     # seconds toward the next charge
var den_cd := 0.0         # seconds until the den may fire again
var time := 0.0
var touched := false      # a hero has laid hands on a gem (grabbed from the hoard or picked up)
var over := false
var won := false
var rng := RandomNumberGenerator.new()


func _init(lv: Level, skill_ranks := {}) -> void:
	level = lv
	skills = skill_ranks
	gold = lv.start_gold + Defs.HOARD_GOLD * skill("hoard_gold")
	mana_max = Defs.MANA_MAX + Defs.HOARD_MANA * skill("hoard_mana")
	mana = lv.start_mana
	home = lv.gems
	timer = lv.first_delay
	trees = lv.trees.duplicate()
	rng.seed = hash(lv.id)
	for sd: Dictionary in lv.sites:
		var s := Site.new()
		s.kind = sd["kind"]
		s.cell = sd["cell"]
		s.pos = Vector2(s.cell) + Vector2(0.5, 0.5)
		if s.kind == "camp":
			s.path = sd["path"]
			s.spawn = sd["spawn"]
			s.every = sd["every"]
			s.t = s.every * 0.5
			s.dist = lv.nearest_dist(s.path, s.pos)
		sites[s.cell] = s
	den_max = int(Defs.DEN["charges"]) + skill("den_charge")
	den_charges = den_max
	_relight()


func skill(id: String) -> int:
	return int(skills.get(id, 0))


# ---------------------------------------------------------------- loop

func update(dt: float) -> void:
	if over:
		return
	time += dt
	mana = minf(mana_max, mana + dt * mana_regen())
	if wave < level.waves.size():
		timer -= dt
		if timer <= 0.0:
			start_wave()
	if not queue.is_empty():
		spawn_t -= dt
		if spawn_t <= 0.0:
			_spawn(queue.pop_front(), -1, 0.0, queue_wave.pop_front())
			spawn_t = Defs.SPAWN_INTERVAL
	_update_sites(dt)
	_update_den(dt)
	_update_enemies(dt)
	_update_drops(dt)
	_update_towers(dt)
	_update_shots(dt)
	_update_pools(dt)
	_update_loot(dt)
	_update_fx(dt)
	if lost >= level.gems:
		_end(false)
	elif wave >= level.waves.size() and queue.is_empty() and enemies.is_empty() and drops.is_empty():
		_end(true)


func mana_regen() -> float:
	var r := Defs.MANA_REGEN
	for s: Site in sites.values():
		if s.kind == "well" and s.owned:
			r += Defs.SITES["well"]["regen"]
	return r


func start_wave() -> void:
	if wave >= level.waves.size():
		return
	var list: Array[String] = level.waves[wave].duplicate()
	var wrng := RandomNumberGenerator.new()
	wrng.seed = wave * 7919 + 13
	for i in range(list.size() - 1, 0, -1):
		var j := wrng.randi_range(0, i)
		var tmp := list[i]
		list[i] = list[j]
		list[j] = tmp
	queue.append_array(list)
	for i in list.size():
		queue_wave.append(wave + 1)
	wave_left[wave + 1] = list.size()
	wave_peak[wave + 1] = 0.0
	wave += 1
	timer = level.wave_gap if wave < level.waves.size() else 0.0
	spawn_t = 0.0
	toast.emit("Wave %d: heroes approach" % wave)
	sound.emit("horn")


## Call the next wave now. Also gathers every coin and potion lying on the map.
## Returns the gold bonus paid for the time skipped.
func call_early() -> int:
	if over or wave >= level.waves.size():
		return 0
	gather_loot()
	var bonus := int(ceil(timer))
	gold += bonus
	if bonus > 0:
		_text(level.lair_center + Vector2(0, -1), "+%d early" % bonus, Color("e8b84a"))
	start_wave()
	return bonus


func _spawn(code: String, path := -1, dist := 0.0, w := 0) -> void:
	var d: Dictionary = Defs.ENEMIES[code]
	var e := Enemy.new()
	e.code = code
	e.wave = w
	e.d = d
	var mul := level.hp_mul * (1.0 + Defs.WAVE_HP_SCALE * maxi(0, wave - 1)) * threat
	e.hp = d["hp"] * mul
	e.max_hp = e.hp
	if path < 0:
		e.path = lane % level.paths.size()
		lane += 1
	else:
		e.path = path
	e.dist = dist
	e.pos = level.path_pos(e.path, dist)
	e.bob = randf() * 6.0
	enemies.append(e)


func _update_sites(dt: float) -> void:
	for s: Site in sites.values():
		if not s.owned and s.kind == "camp":
			# Barracks muster troops only while the hero army is still marching in.
			if wave >= 1 and wave < level.waves.size():
				s.t -= dt
				if s.t <= 0.0:
					s.t = s.every
					for code in s.spawn:
						_spawn(code, s.path, s.dist)
					_text(s.pos + Vector2(0, -0.6), "Reinforcements!", Color("ff9a7a"))
		elif s.owned and s.kind == "mine":
			s.t += dt
			if s.t >= Defs.SITES["mine"]["every"]:
				s.t = 0.0
				var g: int = Defs.SITES["mine"]["gold"]
				gold += g
				_text(s.pos + Vector2(0, -0.5), "+%d" % g, Color("e8b84a"))


## The den refills one charge at a time and spends one per bolt at the nearest threat:
## gem carriers first, then whoever is closest to the hoard.
func _update_den(dt: float) -> void:
	if den_charges < den_max:
		den_refill += dt
		if den_refill >= Defs.DEN["refill"]:
			den_refill = 0.0
			den_charges += 1
	den_cd -= dt
	if den_cd > 0.0 or den_charges <= 0:
		return
	var best: Enemy = null
	var best_score := -INF
	for e: Enemy in enemies:
		var d := e.pos.distance_to(level.lair_center)
		if e.hp <= 0.0 or d > Defs.DEN["range"]:
			continue
		var score := (100.0 if e.carry > 0 else 0.0) - d
		if score > best_score:
			best_score = score
			best = e
	if best == null:
		return
	den_charges -= 1
	den_cd = Defs.DEN["rate"]
	var s := Shot.new()
	s.kind = "den"
	s.pos = level.lair_center + Vector2(0, -0.5)
	s.target = best
	s.tpos = best.pos
	s.dmg = Defs.DEN["dmg"]
	s.pierce = true
	s.spd = 9.0
	shots.append(s)
	sound.emit("zap")


func _update_enemies(dt: float) -> void:
	for e: Enemy in enemies:
		if e.hp <= 0.0:
			continue   # slain this frame; removed below
		if e.slow > 0.0:
			e.slow -= dt
		var sp: float = e.d["spd"] * ((1.0 - e.slow_amt) if e.slow > 0.0 else 1.0)
		if e.fear > 0.0:
			# Terrified: back away from the lair, or freeze if already running with gems.
			e.fear -= dt
			if e.dir == 1:
				e.dist = maxf(0.0, e.dist - sp * 0.6 * dt)
		else:
			e.dist += sp * dt * e.dir
		var total: float = level.paths[e.path]["total"]
		if e.dir == 1 and e.dist >= total:
			var take := mini(int(e.d["cap"]), home)
			e.carry += take
			home -= take
			e.dir = -1
			if take > 0:
				touched = true
				_text(level.lair_center + Vector2(0, -0.6), "-%d gem" % take, Color("ff7a90"))
				sound.emit("grab")
		if e.dir == -1 and e.dist <= 0.0:
			e.gone = true
			if e.carry > 0:
				lost += e.carry
				toast.emit("%s escaped with %s" % [e.d["name"], "a gem" if e.carry == 1 else "%d gems" % e.carry])
				sound.emit("lost")
		if e.wave > 0:
			# How much of the defence it has walked through. Running away means it reached the
			# hoard or grabbed a dropped gem: as far as it gets.
			var reach := _cover_share(e.path, e.dist) if e.dir == 1 else 1.0
			wave_peak[e.wave] = maxf(wave_peak.get(e.wave, 0.0), reach)
		var p := level.path_pos(e.path, e.dist)
		if absf(p.x - e.pos.x) > 0.0001:
			e.face = 1 if p.x > e.pos.x else -1
		e.pos = p
		if e.d.has("ward"):
			for o: Enemy in enemies:
				if o.hp > 0.0 and o.pos.distance_to(e.pos) <= float(e.d["ward"]):
					o.slow = 0.0
					o.fear = 0.0
		if e.d.has("heal"):
			for o: Enemy in enemies:
				if o != e and o.hp > 0.0 and o.hp < o.max_hp and o.pos.distance_to(e.pos) < 1.5:
					o.hp = minf(o.max_hp, o.hp + float(e.d["heal"]) * dt)
		if e.carry < int(e.d["cap"]):
			for g: Drop in drops:
				if g.n > 0 and g.pos.distance_to(e.pos) < 0.4:
					var take := mini(int(e.d["cap"]) - e.carry, g.n)
					touched = true
					g.n -= take
					e.carry += take
					e.dir = -1
					sound.emit("grab")
	for e: Enemy in enemies:
		if e.wave > 0 and (e.gone or e.hp <= 0.0):
			wave_left[e.wave] -= 1
			if wave_left[e.wave] == 0:
				_judge_wave(e.wave)
	enemies = enemies.filter(func(e: Enemy) -> bool: return not e.gone and e.hp > 0.0)


## Share (0..1) of road i's defended stretch, the parts a tower or the den can reach, that lies
## before distance d. Measures how deep into the defence a hero got, wherever towers stand.
func _cover_share(i: int, d: float) -> float:
	if _cover.is_empty():
		for k in level.paths.size():
			var total: float = level.paths[k]["total"]
			var cum := PackedFloat32Array()
			var sum := 0.0
			for n in int(total / COVER_STEP) + 1:
				var p := level.path_pos(k, n * COVER_STEP)
				var hit := p.distance_to(level.lair_center) <= Defs.DEN["range"]
				for tw: Tower in towers.values():
					if hit:
						break
					hit = p.distance_to(tw.pos) <= tw.stat("range")
				if hit:
					sum += COVER_STEP
				cum.append(sum)
			_cover[k] = cum
	var arr: PackedFloat32Array = _cover[i]
	var last := arr[arr.size() - 1]
	return arr[clampi(int(d / COVER_STEP), 0, arr.size() - 1)] / last if last > 0.0 else 1.0


## Dynamic difficulty. Once every hero of a wave is gone, see how close the wave came: the
## most of its road's defended stretch any of them got through. The threat only ever rises: a lot
## after a wave stopped early, only a little after one that got close, so it never feels hopeless.
func _judge_wave(w: int) -> void:
	var t: Dictionary = Defs.THREAT
	var reach: float = wave_peak.get(w, 0.0)
	var before := threat
	if reach < t["easy"]:
		threat += t["up_easy"] + (t["up_max"] - t["up_easy"]) * (t["easy"] - reach) / t["easy"]
	elif reach < t["hard"]:
		threat += t["up_mid"]
	elif reach < 1.0:
		threat += t["up_close"]
	else:
		threat += t["up_touched"]
	threat = minf(threat, t["max"])
	wave_left.erase(w)
	wave_peak.erase(w)
	if threat - before >= 0.1:
		_text(level.lair_center + Vector2(0, -1.5), "Threat ×%.1f" % threat, Color("ff9a7a"))


func _update_drops(dt: float) -> void:
	for g: Drop in drops:
		var total: float = level.paths[g.path]["total"]
		g.dist = minf(total, g.dist + Defs.DROP_SPEED * dt)
		g.pos = level.path_pos(g.path, g.dist)
		if g.dist >= total:
			home += g.n
			g.n = 0
	drops = drops.filter(func(g: Drop) -> bool: return g.n > 0)


## Who a tower shoots: gem carriers first, then special heroes (Cleric, Shieldbearer, Warden),
## then whoever has the least health left. Skips `skip`.
func _pick_target(tw: Tower, skip: Enemy = null) -> Enemy:
	var rg := tw.stat("range")
	var best: Enemy = null
	var best_score := -INF
	for e: Enemy in enemies:
		if e == skip or e.hp <= 0.0 or e.pos.distance_to(tw.pos) > rg:
			continue
		var score := -e.hp
		if e.d.get("special", false):
			score += 100000.0
		if e.carry > 0:
			score += 1000000.0
		if score > best_score:
			best_score = score
			best = e
	return best


func _update_towers(dt: float) -> void:
	for tw: Tower in towers.values():
		if tw.flash > 0.0:
			tw.flash -= dt
		if Defs.TOWERS[tw.type]["kind"] == "beam":
			_update_beam(tw, dt)
			continue
		tw.cd -= dt
		if tw.cd > 0.0:
			continue
		var best := _pick_target(tw)
		if best == null:
			continue
		tw.cd = tw.stat("rate")
		tw.flash = 0.15
		var s := _make_shot(tw, best)
		shots.append(s)
		sound.emit("hut" if s.kind == "arrow" else "crypt")
		if tw.type == "moss" and tw.has_ability():
			var second := _pick_target(tw, best)
			if second != null:
				var v := _make_shot(tw, second)
				v.dmg *= tw.ability_power()
				shots.append(v)


## The Cinder Shrine burns one hero without pause. It holds that hero until it dies or leaves
## range (or a gem carrier shows up), and its damage grows with heat. Armour does not stop it.
func _update_beam(tw: Tower, dt: float) -> void:
	var b := tw.beam
	var lost_hold := b == null or b.hp <= 0.0 or b.gone or b.pos.distance_to(tw.pos) > tw.stat("range")
	if lost_hold or b.carry == 0:
		var best := _pick_target(tw)
		if best != b and (lost_hold or (best != null and best.carry > 0)):
			tw.beam = best
			tw.heat *= Defs.HEAT_KEEP
			tw.cd = 0.0
	var rate := dt * tw.rate_mul / Defs.HEAT_TIME
	if tw.beam == null:
		tw.heat = maxf(0.0, tw.heat - rate)
		return
	tw.heat = minf(1.0, tw.heat + rate)
	tw.flash = 0.15
	var e := tw.beam
	var dps := tw.stat("dmg") * (1.0 + (Defs.HEAT_MAX - 1.0) * tw.heat)
	hurt(e, dps * dt, true, tw)
	if e.hp <= 0.0:
		tw.beam = null


func _make_shot(tw: Tower, target: Enemy) -> Shot:
	var def: Dictionary = Defs.TOWERS[tw.type]
	var s := Shot.new()
	s.kind = def["kind"]
	s.src = tw
	s.pos = tw.pos + Vector2(0, -0.25)
	s.target = target
	s.tpos = target.pos
	s.dmg = tw.stat("dmg")
	s.slow = def["slow"][tw.lvl - 1] if def.has("slow") else 0.0
	if tw.has_ability():
		if tw.type == "frost":
			s.fear = tw.ability_power()
	s.spd = 8.0
	return s


func _update_shots(dt: float) -> void:
	for s: Shot in shots:
		if s.target != null and s.target.hp > 0.0 and not s.target.gone:
			s.tpos = s.target.pos
		var to := s.tpos - s.pos
		var step := s.spd * dt
		if to.length() <= step:
			s.done = true
			if s.target != null and s.target.hp > 0.0:
				hurt(s.target, s.dmg, s.pierce, s.src)
				if s.slow > 0.0:
					s.target.slow_amt = maxf(s.slow, s.target.slow_amt) if s.target.slow > 0.0 else s.slow
					s.target.slow = Defs.SLOW_TIME
				if s.fear > 0.0 and s.target.hp > 0.0 and rng.randf() < s.fear:
					s.target.fear = Defs.ABILITIES["frost"]["dur"]
		else:
			s.pos += to.normalized() * step
	shots = shots.filter(func(s: Shot) -> bool: return not s.done)


func _update_pools(dt: float) -> void:
	for pl: Pool in pools:
		pl.t += dt
		for e: Enemy in enemies:
			if e.pos.distance_to(pl.pos) <= pl.r:
				hurt(e, pl.dps * dt, true, pl.src)
	pools = pools.filter(func(pl: Pool) -> bool: return pl.t < pl.dur)


func _update_loot(dt: float) -> void:
	for l: Loot in loot:
		l.t += dt   # only animates; loot never expires


func _update_fx(dt: float) -> void:
	for f: Fx in fx:
		f.t += dt
		if f.kind == "meteor" and not f.hit and f.t >= Defs.METEOR["delay"]:
			f.hit = true
			_boom(f.pos, Defs.METEOR["radius"], 0.5)
			sound.emit("boom")
			for e: Enemy in enemies:
				if e.pos.distance_to(f.pos) <= Defs.METEOR["radius"]:
					hurt(e, Defs.METEOR["dmg"], true)
	fx = fx.filter(func(f: Fx) -> bool: return f.t < f.dur)


func hurt(e: Enemy, dmg: float, pierce := false, src: Tower = null) -> void:
	if e.hp <= 0.0:
		return
	var dealt := dmg if pierce else maxf(1.0, dmg - float(e.d["armor"]))
	if not pierce:
		dealt *= 1.0 - _guard(e)
	dealt = minf(dealt, e.hp)
	e.hp -= dealt
	if src != null:
		_tower_xp(src, dealt)
	if e.hp <= 0.0:
		gold += int(e.d["gold"])
		mana = minf(mana_max, mana + Defs.MANA_PER_KILL)
		_text(e.pos + Vector2(0, -0.3), "+%d" % int(e.d["gold"]), Color("e8b84a"))
		sound.emit("die")
		if e.carry > 0:
			var g := Drop.new()
			g.pos = e.pos
			g.n = e.carry
			g.path = e.path
			g.dist = e.dist
			drops.append(g)
			e.carry = 0
		_roll_loot(e)
		if src != null and src.type == "ash" and src.has_ability() and rng.randf() < Defs.ABILITIES["ash"]["chance"]:
			_lava(src, e.pos)


## Lava: a pool of burning ground where a Cinder Shrine killed a hero.
func _lava(tw: Tower, at: Vector2) -> void:
	var pl := Pool.new()
	pl.pos = at
	pl.r = Defs.ABILITIES["ash"]["r"]
	pl.dur = Defs.ABILITIES["ash"]["dur"]
	pl.dps = tw.stat("dmg") * Defs.HEAT_MAX * tw.ability_power()
	pl.src = tw
	pools.append(pl)


## Damage reduction from the strongest living Shieldbearer next to e (never from itself).
func _guard(e: Enemy) -> float:
	var g := 0.0
	for o: Enemy in enemies:
		if o != e and o.hp > 0.0 and o.d.has("guard") and o.pos.distance_to(e.pos) <= Defs.GUARD_RANGE:
			g = maxf(g, float(o.d["guard"]))
	return g


func _tower_xp(tw: Tower, amount: float) -> void:
	tw.xp += amount * tw.xp_mul
	var ranks: Array = Defs.TOWER_XP_RANKS
	while tw.rank < ranks.size() and tw.xp >= ranks[tw.rank]:
		tw.rank += 1
		var msg := "Rank %d" % tw.rank
		if tw.has_ability() and tw.rank == Defs.ABILITY_RANK:
			msg = Defs.ABILITIES[tw.type]["name"] + "!"
		_text(tw.pos + Vector2(0, -0.9), msg, Color("c9c0ff"))
		sound.emit("rank")


## One roll per slain hero, so it drops a coin, a potion or nothing, never both.
func _roll_loot(e: Enemy) -> void:
	var r := rng.randf()
	if r >= Defs.LOOT_COIN_CHANCE + Defs.LOOT_POTION_CHANCE:
		return
	var l := Loot.new()
	l.pos = e.pos + Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(0.1, 0.3))
	if r < Defs.LOOT_COIN_CHANCE:
		l.kind = "coin"
		# Worth more for stronger heroes: their bounty, scaled by how much tougher than
		# base they are this wave and level.
		l.amount = Defs.LOOT_COIN_BONUS + roundi(float(e.d["gold"]) * Defs.LOOT_COIN_MUL * e.max_hp / float(e.d["hp"]))
	else:
		l.kind = "potion"
		l.amount = Defs.LOOT_POTION_MANA
	loot.append(l)


## Picks up the loot nearest to pos (in tiles), if any is within reach. Returns true if something was taken.
func collect_loot(pos: Vector2, reach := 0.5) -> bool:
	var best: Loot = null
	var best_d := reach
	for l: Loot in loot:
		var d := l.pos.distance_to(pos)
		if d <= best_d:
			best_d = d
			best = l
	if best == null:
		return false
	_take_loot(best)
	loot.erase(best)
	return true


## Picks up every coin and potion on the map at once. Returns how many were taken.
func gather_loot() -> int:
	var n := loot.size()
	for l: Loot in loot:
		_take_loot(l)
	loot.clear()
	return n


func _take_loot(l: Loot) -> void:
	sound.emit(l.kind)
	if l.kind == "coin":
		gold += l.amount
		_text(l.pos + Vector2(0, -0.3), "+%d" % l.amount, Color("e8b84a"))
	else:
		mana = minf(mana_max, mana + l.amount)
		_text(l.pos + Vector2(0, -0.3), "+%d mana" % l.amount, Color("c9c0ff"))


func _end(win: bool) -> void:
	over = true
	won = win
	ended.emit(win)


# ---------------------------------------------------------------- effects

func _text(pos: Vector2, text: String, color: Color) -> void:
	var f := Fx.new()
	f.kind = "text"
	f.pos = pos
	f.text = text
	f.color = color
	f.dur = 1.0
	fx.append(f)


func _boom(pos: Vector2, r: float, dur: float) -> void:
	var f := Fx.new()
	f.kind = "boom"
	f.pos = pos
	f.r = r
	f.dur = dur
	fx.append(f)


# ---------------------------------------------------------------- spells

func can_meteor() -> bool:
	return mana >= Defs.METEOR["cost"]


func cast_meteor(pos: Vector2) -> bool:
	if not can_meteor():
		return false
	mana -= Defs.METEOR["cost"]
	var f := Fx.new()
	f.kind = "meteor"
	f.pos = pos
	f.dur = Defs.METEOR["delay"] + 0.5
	fx.append(f)
	sound.emit("whoosh")
	return true


# ---------------------------------------------------------------- night

## On night levels, tiles near the lair, your towers and your mines and wells are lit.
func _relight() -> void:
	_cover.clear()   # towers changed, so did the defended stretch of each road
	lit.clear()
	if not level.night:
		return
	var lights: Array = [[level.lair_center, Defs.LIGHT["lair"]]]
	for tw: Tower in towers.values():
		lights.append([tw.pos, Defs.LIGHT["tower"]])
	for s: Site in sites.values():
		if s.owned and s.kind != "camp":
			lights.append([s.pos, Defs.SITES[s.kind]["light"]])
	for c in level.cols:
		for r in level.rows:
			var center := Vector2(c, r) + Vector2(0.5, 0.5)
			for l in lights:
				if center.distance_to(l[0]) <= l[1]:
					lit[Vector2i(c, r)] = true
					break
	light_changed.emit()


func is_lit(c: Vector2i) -> bool:
	return not level.night or lit.has(c)


# ---------------------------------------------------------------- tiles

## Building price: the base cost, plus TOWER_COST_STEP for each tower of this type already standing.
func build_cost(type: String) -> int:
	var n := 0
	for tw: Tower in towers.values():
		if tw.type == type:
			n += 1
	return int(Defs.TOWERS[type]["cost"][0]) + Defs.TOWER_COST_STEP * n


func _build_action(type: String, label: String) -> Dictionary:
	var cost := build_cost(type)
	return {"id": "build:" + type, "label": label, "price": "%dg" % cost, "gold": cost}


## What a tile panel should show: a title, a line of text and the actions available.
func cell_info(c: Vector2i) -> Dictionary:
	var t := level.terrain_at(c)
	if sites.has(c):
		return _site_info(sites[c])
	if level.road.has(c):
		return {"title": "Hero road", "text": "Nothing can be built on the road.", "actions": []}
	if level.is_lair(c):
		var txt := "%d gems inside. Heroes grab them and run for the edge of the map.\n" % home
		txt += "The den strikes heroes within %.1f tiles: %d of %d charges ready, one refills every %d s. Add charges in Dark Arts." % [
			Defs.DEN["range"], den_charges, den_max, int(Defs.DEN["refill"])]
		return {"title": "Your den", "text": txt, "actions": []}
	if trees.has(c):
		return {"title": "Woods", "text": "Cut the trees to free this %s tile for building. You sell the timber for gold." % _ground_name(t),
			"actions": [{"id": "clear", "label": "Cut woods", "price": "%d mana  +%dg" % [Defs.CLEAR_MANA, Defs.CLEAR_GOLD], "mana": Defs.CLEAR_MANA}]}
	if towers.has(c):
		var tw: Tower = towers[c]
		var d: Dictionary = Defs.TOWERS[tw.type]
		var acts := []
		if tw.lvl < 3:
			acts.append({"id": "upgrade", "label": "Upgrade", "price": "%dg" % d["cost"][tw.lvl], "gold": d["cost"][tw.lvl]})
		acts.append({"id": "sell", "label": "Sell", "price": "+%dg" % int(tw.spent * Defs.SELL_REFUND)})
		var ab: Dictionary = Defs.ABILITIES[tw.type]
		var txt := "Damage %d, range %.1f\n" % [int(tw.stat("dmg")), tw.stat("range")]
		if d["kind"] == "beam":
			txt = "Burns %d to %d per second as it heats, range %.1f\n" % [int(tw.stat("dmg")), int(tw.stat("dmg") * Defs.HEAT_MAX), tw.stat("range")]
		var ranks: Array = Defs.TOWER_XP_RANKS
		if tw.rank < ranks.size():
			txt += "Veteran rank %d/3 (next at %d/%d damage)\n" % [tw.rank, int(tw.xp), ranks[tw.rank]]
		else:
			txt += "Veteran rank 3/3 (max)\n"
		if tw.has_ability():
			txt += "%s: %s" % [ab["name"], ab["text"]]
		else:
			txt += "%s at rank %d and level III: %s" % [ab["name"], Defs.ABILITY_RANK, ab["text"]]
		return {"title": "%s, level %d" % [d["name"], tw.lvl], "text": txt, "actions": acts}
	if not is_lit(c):
		return {"title": "Darkness", "text": "You can't build where you can't see. Towers, mines and wells light the ground around them.", "actions": []}
	var td: Dictionary = Defs.TOWERS[t]
	if level.high.has(c):
		var acts := []
		var bonus := []
		for type: String in Defs.TOWERS:
			acts.append(_build_action(type, Defs.TOWERS[type]["name"]))
			bonus.append("%s +%.1f" % [Defs.TOWERS[type]["name"], Defs.TOWERS[type]["high_range"]])
		return {"title": "Raised ground", "text": "Any tower can be built up here, and it reaches further: %s." % ", ".join(bonus),
			"actions": acts}
	return {"title": td["name"], "text": "%s Builds only on %s." % [td["blurb"], t],
		"actions": [_build_action(t, "Build")]}


func _ground_name(t: String) -> String:
	return t


func _site_info(s: Site) -> Dictionary:
	var d: Dictionary = Defs.SITES[s.kind]
	var cut := {"id": "cut", "price": "%d mana" % d["cut"], "mana": d["cut"]}
	match s.kind:
		"mine":
			if s.owned:
				return {"title": d["name"], "text": "Yours. Earns %d gold every %d s." % [d["gold"], int(d["every"])], "actions": []}
			cut["label"] = "Cut free"
			return {"title": d["name"], "text": d["text"] % [d["gold"], int(d["every"])], "actions": [cut]}
		"well":
			if s.owned:
				return {"title": d["name"], "text": "Yours. +%.1f mana per second." % d["regen"], "actions": []}
			cut["label"] = "Cut free"
			return {"title": d["name"], "text": d["text"] % d["regen"], "actions": [cut]}
	if s.owned:
		return {"title": "Ruined barracks", "text": "Nothing left but ash.", "actions": []}
	cut["label"] = "Raze"
	cut["price"] = "%d mana  +%dg" % [d["cut"], d["bounty"]]
	return {"title": d["name"], "text": d["text"] % d["bounty"], "actions": [cut]}


## Range (in tiles) to preview when a tile is selected, or 0.
func preview_range(c: Vector2i) -> float:
	if towers.has(c):
		return (towers[c] as Tower).stat("range")
	if level.road.has(c) or level.is_lair(c) or trees.has(c) or sites.has(c) or not is_lit(c):
		return 0.0
	var t := level.terrain_at(c)
	if level.high.has(c):
		var best := 0.0   # any tower fits: show the longest reach
		for type: String in Defs.TOWERS:
			best = maxf(best, float(Defs.TOWERS[type]["range"][0]) + _range_bonus(type, c))
		return best
	return float(Defs.TOWERS[t]["range"][0]) + _range_bonus(t, c)


## Extra range from the skill tree and, on a raised tile, from the height.
func _range_bonus(type: String, c: Vector2i) -> float:
	var r := 0.2 * skill(type + "_range")
	if level.high.has(c):
		r += float(Defs.TOWERS[type]["high_range"])
	return r


## Runs a tile action. Returns "" on success, or a message explaining why it failed.
func do_action(id: String, c: Vector2i) -> String:
	if id.begins_with("build"):
		var t := level.terrain_at(c)
		var type := id.get_slice(":", 1) if id.contains(":") else t
		if towers.has(c) or trees.has(c) or sites.has(c) or level.road.has(c) or level.is_lair(c):
			return "Can't build here"
		if not is_lit(c):
			return "Too dark to build here"
		if not Defs.TOWERS.has(type) or (type != t and not level.high.has(c)):
			return "That tower needs %s ground" % type
		var cost := build_cost(type)
		if gold < cost:
			return "Not enough gold"
		gold -= cost
		var tw := Tower.new()
		tw.type = type
		tw.cell = c
		tw.pos = Vector2(c) + Vector2(0.5, 0.5)
		tw.spent = cost
		tw.dmg_mul = 1.0 + 0.1 * skill(type + "_dmg")
		tw.rate_mul = 1.0 + 0.08 * skill(type + "_rate")
		tw.range_add = _range_bonus(type, c)
		tw.xp_mul = 1.0 + 0.25 * skill(type + "_vet")
		tw.ability_rank = skill(type + "_ability")
		towers[c] = tw
		_relight()
		sound.emit("build")
		return ""
	match id:
		"clear":
			if not trees.has(c):
				return "No woods here"
			if mana < Defs.CLEAR_MANA:
				return "Not enough mana"
			mana -= Defs.CLEAR_MANA
			gold += Defs.CLEAR_GOLD
			trees.erase(c)
			_text(Vector2(c) + Vector2(0.5, 0.3), "+%d" % Defs.CLEAR_GOLD, Color("e8b84a"))
			ground_changed.emit()
			sound.emit("chop")
		"cut":
			if not sites.has(c) or (sites[c] as Site).owned:
				return "Nothing to cut"
			var s: Site = sites[c]
			var d: Dictionary = Defs.SITES[s.kind]
			if mana < d["cut"]:
				return "Not enough mana"
			mana -= d["cut"]
			s.owned = true
			s.t = 0.0
			sound.emit("raze")
			if s.kind == "camp":
				gold += d["bounty"]
				_boom(s.pos, 0.9, 0.5)
				_text(s.pos + Vector2(0, -0.4), "+%d" % d["bounty"], Color("e8b84a"))
				toast.emit("Barracks razed")
			else:
				toast.emit("%s is yours" % d["name"])
				_relight()
		"upgrade":
			if not towers.has(c):
				return "No tower here"
			var tw: Tower = towers[c]
			if tw.lvl >= 3:
				return "Fully upgraded"
			var cost: int = Defs.TOWERS[tw.type]["cost"][tw.lvl]
			if gold < cost:
				return "Not enough gold"
			gold -= cost
			tw.spent += cost
			tw.lvl += 1
			_cover.clear()   # range grew
			sound.emit("upgrade")
			if tw.has_ability() and tw.lvl == Defs.ABILITY_LEVEL:
				_text(tw.pos + Vector2(0, -0.9), Defs.ABILITIES[tw.type]["name"] + "!", Color("c9c0ff"))
		"sell":
			if not towers.has(c):
				return "No tower here"
			var tw: Tower = towers[c]
			gold += int(tw.spent * Defs.SELL_REFUND)
			towers.erase(c)
			_relight()
			sound.emit("sell")
		_:
			return "Unknown action"
	return ""


# ---------------------------------------------------------------- scoring

func gems_left() -> int:
	var n := home
	for g: Drop in drops:
		n += g.n
	for e: Enemy in enemies:
		n += e.carry
	return n


## Three tiers of clearance: Survived (gems lost), Wicked (none lost, but a hero touched one)
## and Brilliant (no hero ever touched a gem). Brilliant unlocks the level's night mission.
func rank() -> String:
	if not won:
		return "Plundered"
	if lost > 0:
		return "Survived"
	if touched:
		return "Wicked"
	return "Brilliant"
