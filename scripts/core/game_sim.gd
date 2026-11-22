class_name GameSim
extends RefCounted
## The rules of one battle: heroes, towers, spells, waves, gems, map buildings and loot.
## No drawing code lives here, so battles can run headless in tests.

const COVER_STEP := 0.25   # tiles between samples when measuring how much of a road is defended

signal toast(text: String)
signal ended(won: bool)
signal ground_changed
signal trees_changed   # woods were cut: only the woods need drawing again
signal light_changed
## A sound effect to play (see Sfx.SFX): the rules say what happened, the view decides how it sounds.
signal sound(name: String)
## A burst of particles for the view (see Board): "death" (code = the hero), "build", "meteor",
## "pickup_coin", "pickup_potion". Purely cosmetic; nothing in the rules listens.
signal burst(kind: String, pos: Vector2, code: String)


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
	var soak := 0.0       # seconds of Soaked left (in a ford or swimming, and SOAK_TIME after)
	var swim := false     # swimming a flooded ford or a collapsed bridge: slow, and no Herald haste
	var wade := 0.0       # seconds it wades freely, like a Fenwalker (the Tidecaller's surge)
	var mark := 0.0       # seconds it stays marked by a Hunter's Lodge (takes more damage)
	var work := 0.0       # Engineer: seconds spent repairing the bridge ahead
	var surge_t := 0.0    # Tidecaller: seconds until her next surge
	var crew: Array[String] = []   # Longboat: the heroes it carries
	var ashore := -1.0    # Longboat: seconds until the next of its crew steps ashore (-1 = still sailing)
	var beached := false  # Longboat: empty on the shore, waiting to carry its crew away (no longer a hero)
	var hidden := false   # Diver under water: towers and the den can't see him
	var zone := ""        # the road zone it stood in last frame
	var crossing := -1    # which crossing that was (Level.crossings), or -1
	var sap: Tower        # Sapper: the tower he is running at, or null
	var fuse := -1.0      # Sapper: seconds the fuse has burned, or -1 while it is not lit
	var back := false     # Sapper: walking back to the road (his tower was sold)
	var pave: Dictionary  # Pavior: the stretch of road he is paving (an entry of GameSim.paved)
	var deployed := false # Trebuchet: set up and slinging stones
	var sling := 0.0      # Trebuchet: seconds to the next stone (or to set up); Belfry: to the next Sapper
	var stones := 0       # Trebuchet: stones thrown
	var retreat := false  # an engine rolling away: it never comes back, nor counts as escaped
	var unloaded := false # Iron Belfry: has unloaded its Footmen at the den
	var covered := false  # walking in an Iron Belfry's shadow: towers and the den can't see him
	var untouch := 0.0    # seconds untouchable (a Justicar's shield, the Seraph landing)
	var shielded := false # Justicar: has spent his shield
	var chant := 0.0      # Spiriter: seconds of chanting left at the cave mouth (0 = not chanting)
	var phase := 0        # the Seraph: times she has landed and raised the fallen
	var grounded := false # a flyer that has come down onto a road (the Seraph after landing)
	var hit := 0.0        # seconds of hit flash left (view only)
	var knock := Vector2.ZERO   # small knock-back offset in tiles from the last hit (view only)
	var stride := 0.0     # tiles walked at its own pace (GameSim.pace), for the walk cycle (view only)


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
	var altars := 0       # freed Dark Altars in reach (see GameSim._attune)
	var mastery := ""     # level IV: "longhouse", "lodge", "ossuary", "mausoleum", "twin" or "sunlance"
	var plunder := 0      # level IV Hut: kills since it became level IV (see Defs.PLUNDER_MAX)
	var aim := "auto"     # who it shoots after gem carriers: "auto", "strong" (most health) or "first" (closest to the cave)
	var charges := 0      # Ossuary: bolts stored
	var volley_t := 0.0   # Ossuary: seconds to the next stored bolt
	var volley_hits: Array = []   # Ossuary: heroes already hit in this volley
	var volley_kills := 0  # Ossuary: heroes its current volley has slain
	var beam2: Enemy      # Twin Flame: the second beam's hero
	var heat2 := 0.0
	var born := -10.0     # battle time it was built or last upgraded (view only: squash and settle)
	var stun := 0.0       # seconds stunned (Sapper, Iron Belfry): no firing
	var rubble := 0.0     # seconds buried under Rubble (Trebuchet): no firing
	var silence := 0.0    # silenced by an Inquisitor this frame: how much slower it fires (0 = not)
	var sapped: Enemy     # a Sapper is on his way to it
	var holy := false     # on hallowed ground while a Chapel stands: less range, no ability
	# Permanent bonuses from the skill tree, filled in when the tower is built.
	var dmg_mul := 1.0
	var rate_mul := 1.0
	var range_add := 0.0
	var xp_mul := 1.0
	var ability_rank := 0
	var altar_mul := 1.0   # damage from those altars

	func stat(key: String) -> float:
		var v := float(Defs.TOWERS[type][key][lvl - 1])
		match key:
			"dmg":
				return v * dmg_mul * (1.0 + (Defs.RANK_DMG * rank if silence <= 0.0 else 0.0)) * (altar_mul if altars > 0 else 1.0)
			"rate":
				var r := v / rate_mul * (1.0 + silence)
				if mastery == "lodge":
					r *= Defs.LODGE["rate"]
				return r
			"range":
				return (v + range_add) * (Defs.HALLOW_RANGE if holy else 1.0)
		return v

	func has_ability() -> bool:
		return rank >= Defs.ABILITY_RANK and lvl >= Defs.ABILITY_LEVEL and silence <= 0.0 and not holy

	## Stunned or buried: it can't fire.
	func blocked() -> bool:
		return stun > 0.0 or rubble > 0.0

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
	var ap := 0           # armour it ignores (Bodkin Points)
	var mark := 0.0       # Hunter's Lodge: marks its hero this long
	var burst := false    # Mausoleum: hurts and chills the heroes around its target too
	var src: Tower        # gets the XP for damage dealt
	var spd := 8.0
	var done := false


## Gems dropped by a slain carrier. They roll back to the lair along the road they fell on.
class Drop:
	var pos := Vector2.ZERO
	var n := 0
	var path := 0
	var dist := 0.0
	var fall := 0.0       # seconds left falling from the air to the road (Defs.DROP_FALL); it rolls once landed
	var from := Vector2.ZERO   # where it began to fall (the flying carrier), for drawing the fall


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
	var cuts := 1         # cuts it takes in all (its own "cuts" in the level file, else Level.site_cuts)
	var cuts_left := 1    # cuts still needed
	var t := 0.0
	var path := 0
	var spawn: Array[String] = []
	var every := 25.0
	var dist := 0.0       # where camp troops join their road


class Fx:
	var kind := ""        # "boom" | "meteor" | "text" | "shock" | "scorch"
	var pos := Vector2.ZERO
	var r := 0.0
	var t := 0.0
	var dur := 1.0
	var text := ""
	var color := Color.WHITE
	var hit := false
	var to := Vector2.ZERO   # "stone": where the Trebuchet's stone lands
	var cell := Vector2i.ZERO   # "stone": the tower it buries


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
var wave_live := {}       # wave -> threat already added by its heroes falling early (_judge_kill)
var _cover := {}          # road -> defended length up to each COVER_STEP along it; empty = rebuild
var spawn_t := 0.0
var lane := 0
var boat_lane := 0        # boats are dealt over river roads on their own count
var tide := Vector2.ZERO  # the lair's Tide rule: (period, seconds up), or zero for none
var enemies: Array = []
var _rally: Array = []    # [{"codes", "path", "dist", "wave"}]: heroes to raise where a Champion fell
var towers := {}          # Vector2i -> Tower
var shots: Array = []
var drops: Array = []
var loot: Array = []
var pools: Array = []
var sites := {}           # Vector2i -> Site
var fx: Array = []
var trees := {}           # Vector2i -> true (woods still standing)
var lit := {}             # Vector2i -> true, night levels only
var lights: Array = []    # [Vector2 centre, radius] of every light while it is dark (the view draws them)
var den_max := 0          # den charges when full: base plus one per Den skill point
var den_charges := 0
var den_refill := 0.0     # seconds toward the next charge
var den_cd := 0.0         # seconds until the den may fire again
var time := 0.0
var race_on := false       # an online race (set_race): kills send heroes to the rival, the race clock runs
var race_sends := ""      # hero codes sent to the rival so far, oldest first
var stopped := false      # an online race ended because the rival finished first
var touched := false      # a hero has laid hands on a gem (grabbed from the hoard or picked up)
var over := false
var won := false
var rng := RandomNumberGenerator.new()
# Battle stats, for the score and achievements.
var kills := 0
var kills_by := {}        # hero code -> how many were slain
var best_meteor := 0      # most heroes a single meteor slew
var built := {}           # tower type -> true for every kind built this battle
var most_towers := 0      # most towers standing at once
var early_calls := 0
var skipped := 0          # seconds of wave countdown skipped by calling early
var abilities := 0        # times a tower learned its ability
var learned := {}         # tower type -> true once one of that type learned its ability
var kills_tower := {}     # tower type -> heroes it slew
var den_kills := 0        # heroes the den's bolts slew
var race_kills := 0       # online race: kills counted toward the next hero sent (drowned crews included)
var meteors := 0          # meteors cast
var meteor_kills := 0     # heroes meteors slew
var towers_built := 0
var built_count := {}     # tower type -> how many were built
var high_built := 0       # of those, how many on raised ground
var upgrades := 0
var sold := 0
var gold_spent := 0       # on towers and upgrades
var woods_cut := 0
var coins := 0            # coins picked up
var potions := 0          # potions picked up
var gems_saved := 0       # gems knocked out of the hands of heroes that were slain carrying them
var dreads := 0           # heroes terrified by Dread
var lavas := 0            # pools of Lava left behind
# Road zones (Level.zones): what has changed on them during the battle.
var collapsed := {}       # Vector2i -> true for water tiles whose bridge has been collapsed
var collapses := {}       # crossing index -> times that bridge has been collapsed (stats; the cost is flat)
var planks := {}          # crossing index -> battle time a ford's planks rot away (laid by Engineers)
var rains: Array = []     # [Vector2 centre, radius] of every rain cloud this frame
var drowned := 0          # boat crews drowned with their boat
var boats_sunk := 0
var boats_landed := 0
var collapsed_n := 0      # bridges collapsed this battle
var collapse_kills := 0   # heroes slain while swimming a collapsed bridge
var water_kills := 0      # heroes slain in water (fords, swimming, boats)
var floods := 0           # Sluice surges sent
var best_flood := 0       # most heroes one surge slew
var diver_meteor := 0     # hidden Divers slain by a meteor
var plundered := 0        # gold Plunder paid
var masteries_built := {} # mastery id -> how many towers became it this battle
var twin_t := -10.0       # battle time a Twin Flame last slew a hero (twin_kills)
var twin_kills := 0       # a Twin Flame slew two heroes within a second
var best_ossuary := 0     # most heroes slain by one Ossuary volley
var lodge_champion := 0   # a Hunter's Lodge landed the killing blow on a Champion
var sunlance_best := 0    # most heroes burning on one Sunlance at once
var paved: Array = []     # per road: [{"from", "to", "until"}] stretches Paviors have paved (until: battle time it fades)
var tide_up := false      # the tide is in: fords are deep
# Chapter IV: siege.
var dark := false         # darkness is on: the night mission, or after Dusk (see dusk_wave)
var dusk_wave := 0        # the Dusk rule: night falls as this wave starts (0 = never)
var dark_t := -100.0      # battle time darkness last came or went (Dusk, Eclipse): the view fades it
var eclipse := Vector2.ZERO   # the Eclipse rule: (period, seconds dark), or zero for none
# Chapter V: the Radiant Host.
var air_lane := 0         # flyers are dealt over air roads on their own count
var fallen: Array[String] = []   # heroes slain so far, oldest first: the Seraph raises the last ones
var chants_broken := 0    # Spiriters whose chant was broken by Dread or death
var chants_done := 0      # Spiriters who vanished with a gem
var shield_waste := 0     # Justicar shields spent where no tower could reach him
var built_hallowed := 0   # towers built on hallowed ground
var chapels_razed_wave := -1   # the wave during which the last Chapel fell (-1: none fell, or none to raze)
var seraph_phase := -1    # how many times the Seraph had risen when she fell (-1: not slain)
var stuns := 0            # towers stunned by Sappers and the Belfry
var rubbles := 0          # towers buried under Rubble
var rubble_cleared := 0   # Rubble cleared from the tile panel
var keg_best := 0         # most heroes one Sapper's keg slew
var treb_fast := 0        # Trebuchets destroyed before their first stone
var silence_proof := 0    # Inquisitors slain by a tower they were silencing
var pavior_early := 0     # Paviors slain before they paved three tiles
var engines_built := 0    # Trebuchets that rolled out of Siege Workshops


func _init(lv: Level, skill_ranks := {}) -> void:
	level = lv
	skills = skill_ranks
	gold = lv.start_gold + Defs.HOARD_GOLD * skill("hoard_gold") + Defs.TITHE_GOLD * skill("hoard_tithe")
	mana_max = Defs.MANA_MAX + Defs.HOARD_MANA * skill("hoard_mana")
	mana = lv.start_mana + Defs.PATIENCE_MANA * skill("dragon_patience")
	home = lv.gems
	timer = lv.first_delay
	trees = lv.trees.duplicate()
	for i in lv.paths.size():
		paved.append([])
	rng.seed = hash(lv.id)
	for sd: Dictionary in lv.sites:
		var s := Site.new()
		s.kind = sd["kind"]
		s.cell = sd["cell"]
		s.pos = Vector2(s.cell) + Vector2(0.5, 0.5)
		s.cuts = sd.get("cuts", level.site_cuts)
		s.cuts_left = s.cuts
		if s.kind == "sluice":   # yours from the start; s.t counts down its recharge
			s.owned = true
			s.path = sd["path"]
			s.t = 0.0
		if Defs.MUSTER_SITES.has(s.kind):
			s.path = sd["path"]
			s.spawn = sd["spawn"]
			s.every = sd["every"]
			s.t = s.every * 0.5
			s.dist = lv.nearest_dist(s.path, s.pos)
		sites[s.cell] = s
	dark = lv.night
	for rule: Dictionary in lv.rules:
		if rule.get("kind", "") == "tide":
			tide = Vector2(float(rule.get("period", 40)), float(rule.get("up", 14)))
		if rule.get("kind", "") == "dusk" and not lv.night:   # the night mission is dark from the start
			dusk_wave = int(rule.get("wave", 1))
		if rule.get("kind", "") == "eclipse" and not lv.night:
			eclipse = Vector2(float(rule.get("period", 70)), float(rule.get("dark", 25)))
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
	if tide.x > 0.0:
		tide_up = fmod(time, tide.x) >= tide.x - tide.y
	if eclipse.x > 0.0:
		var d := fmod(time, eclipse.x) >= eclipse.x - eclipse.y
		if d != dark:
			dark = d
			dark_t = time
			_relight()
			toast.emit("The sun goes dark" if dark else "The light returns")
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
	elif wave >= level.waves.size() and queue.is_empty() and _rally.is_empty() and enemies.all(func(e: Enemy) -> bool: return e.retreat or e.beached):
		# No hero is left to take them (an engine rolling away never comes back, so the battle does
		# not wait for it), so gems still rolling home count as home now.
		for g: Drop in drops:
			home += g.n
		drops.clear()
		_end(true)


func mana_regen() -> float:
	var r := Defs.MANA_REGEN + Defs.HOARD_REGEN * skill("hoard_regen")
	for s: Site in sites.values():
		if s.kind == "well" and s.owned:
			r += Defs.SITES["well"]["regen"] + Defs.SPRINGS_REGEN * skill("land_springs")
	return r


func start_wave() -> void:
	if wave >= level.waves.size():
		return
	gather_loot()   # whatever the last wave dropped is picked up as the next one marches in
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
	timer = wave_gap() if wave < level.waves.size() else 0.0
	spawn_t = 0.0
	toast.emit("Wave %d: heroes approach" % wave)
	sound.emit("horn")
	if wave == dusk_wave and not dark:
		dark = true
		dark_t = time
		_relight()
		toast.emit("Night falls")


## Seconds from one wave to the next: the lair's gap, or the race clock's in an online race;
## a lit Signal Fire takes its seconds off (in a race never below Defs.RACE["gap_min"]).
func wave_gap() -> float:
	var sooner: float = Defs.SITES["beacon"]["sooner"] if beacon_lit() else 0.0
	if race_on:
		return maxf(float(Defs.RACE["gap_min"]), float(Defs.RACE["gap"]) - sooner)
	return level.wave_gap - sooner


## Makes this battle an online race: kills send heroes to the rival, the waves come on the race
## clock (Defs.RACE) and heroes have the lair's race health (Level.race_hp). Call before it begins.
func set_race() -> void:
	race_on = true
	timer = float(Defs.RACE["first"])


## A Signal Fire still burns: waves come sooner and barracks muster faster.
func beacon_lit() -> bool:
	for s: Site in sites.values():
		if s.kind == "beacon" and not s.owned:
			return true
	return false


## Call the next wave now (which, like every wave start, gathers the loot lying on the map).
## Returns the gold bonus paid for the time skipped.
func call_early() -> int:
	if over or wave >= level.waves.size():
		return 0
	var bonus := int(ceil(timer))
	early_calls += 1
	skipped += bonus
	gold += bonus
	# The skipped seconds also pay the mana they would have regenerated.
	var gain := minf(mana_max - mana, timer * mana_regen())
	mana += maxf(0.0, gain)
	# And owned gold mines pay what they would have dug in that time.
	var dug := 0
	for s: Site in sites.values():
		if s.owned and s.kind == "mine":
			var every: float = Defs.SITES["mine"]["every"]
			dug += int((s.t + timer) / every) * mine_gold()
			s.t = fmod(s.t + timer, every)
	gold += dug
	if dug > 0:
		_text(level.lair_center + Vector2(0, 0.2), "+%d mines" % dug, Color("e8b84a"))
	if bonus > 0:
		_text(level.lair_center + Vector2(0, -1), "+%d early" % bonus, Color("e8b84a"))
	if gain >= 1.0:
		_text(level.lair_center + Vector2(0, -0.4), "+%d mana" % int(gain), Color("c9c0ff"))
	start_wave()
	return bonus


func _spawn(code: String, path := -1, dist := 0.0, w := 0) -> void:
	var d: Dictionary = Defs.ENEMIES[code]
	var e := Enemy.new()
	e.code = code
	e.wave = w
	e.d = d
	var mul := level.hp_mul * (1.0 + Defs.WAVE_HP_SCALE * maxi(0, wave - 1)) * threat
	if level.night:
		mul *= level.night_hp
	if race_on:
		mul *= level.race_hp
	e.hp = d["hp"] * mul
	e.max_hp = e.hp
	var rivers: Array = level.wave_rivers[w - 1] if w > 0 and w <= level.wave_rivers.size() else []
	if path < 0 and d.has("boat") and not rivers.is_empty():
		# Boats sail the river roads their wave may use, dealt round-robin on their own count.
		e.path = rivers[boat_lane % rivers.size()]
		boat_lane += 1
		var cargo: Dictionary = level.wave_cargo[w - 1]
		e.crew = cargo[str(e.path)].duplicate() if cargo.has(str(e.path)) else Level._parse_wave(String(d["crew"]))
	elif path < 0 and d.has("fly") and level.path_kind.has("air"):
		# Flyers take the air roads their wave may use, dealt round-robin on their own count.
		var airs: Array = level.wave_air[w - 1] if w > 0 and w <= level.wave_air.size() else []
		if airs.is_empty():
			for i in level.path_kind.size():
				if level.path_kind[i] == "air":
					airs.append(i)
		e.path = airs[air_lane % airs.size()]
		air_lane += 1
	elif path < 0:
		# Dealt round-robin over the land roads its wave may use (every land road unless it names some),
		# short roads at half a share (Level.deal).
		var roads: Array[int] = level.wave_deal[w - 1] if w > 0 and w <= level.wave_deal.size() else level.deal(level.land_roads)
		e.path = roads[lane % roads.size()]
		lane += 1
	else:
		e.path = path
	if d.has("surge"):
		e.surge_t = Defs.SURGE["every"]
	if d.has("belfry"):
		e.sling = Defs.BELFRY["sapper"]
	if d.has("pave") and level.path_kind[e.path] == "land":
		e.pave = {"from": dist, "to": dist, "until": INF}
		paved[e.path].append(e.pave)
	e.dist = dist
	e.pos = level.path_pos(e.path, dist)
	e.bob = randf() * 6.0
	enemies.append(e)


func _update_sites(dt: float) -> void:
	var muster := float(Defs.SITES["beacon"]["muster"]) if beacon_lit() else 1.0
	for s: Site in sites.values():
		if s.kind == "chapel" and not s.owned:   # heals the heroes around it
			var cd: Dictionary = Defs.SITES["chapel"]
			for e: Enemy in enemies:
				if e.hp > 0.0 and e.hp < e.max_hp and e.pos.distance_to(s.pos) <= float(cd["r"]):
					e.hp = minf(e.max_hp, e.hp + float(cd["heal"]) * level.hp_mul * dt)
		if not s.owned and Defs.MUSTER_SITES.has(s.kind):
			# Barracks and workshops muster only while the hero army is still marching in.
			if wave >= 1 and wave < level.waves.size():
				s.t -= dt * muster
				if s.t <= 0.0:
					s.t = s.every
					for code in s.spawn:
						_spawn(code, s.path, s.dist)
					if s.kind == "workshop":
						engines_built += s.spawn.size()
					_text(s.pos + Vector2(0, -0.6), "A siege engine!" if s.kind == "workshop" else "Reinforcements!", Color("ff9a7a"))
		elif s.kind == "sluice" and s.t > 0.0:
			s.t = maxf(0.0, s.t - dt)
		elif s.owned and s.kind == "mine":
			s.t += dt
			if s.t >= Defs.SITES["mine"]["every"]:
				s.t = 0.0
				var g: int = Defs.SITES["mine"]["gold"] + Defs.VEINS_GOLD * skill("land_veins")
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
		if e.hp <= 0.0 or e.hidden or e.covered or d > Defs.DEN["range"]:
			continue
		var score := (100.0 if e.carry > 0 else 0.0) - d
		if e.beached:
			score -= 1000.0
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
	s.dmg = Defs.DEN["dmg"] * (1.0 + Defs.FURY_DMG * skill("den_fury"))
	s.pierce = true
	s.spd = 9.0
	shots.append(s)
	sound.emit("zap")


func _update_enemies(dt: float) -> void:
	for r: Dictionary in _rally:
		for code in r["codes"]:
			_spawn(code, r["path"], r["dist"], r["wave"])
			if r.get("half", false):   # raised by the Seraph: at half health
				enemies[-1].hp *= Defs.SERAPH["hp"]
		if r["wave"] > 0 and not r.get("counted", false):
			wave_left[r["wave"]] += r["codes"].size()
	_rally.clear()
	var heralds := enemies.filter(func(o: Enemy) -> bool: return o.hp > 0.0 and o.d.has("haste"))
	rains.clear()
	var belfries: Array = []
	for o: Enemy in enemies:
		if o.hp > 0.0 and o.d.has("rain"):
			rains.append([o.pos, float(o.d["rain"])])
		if o.hp > 0.0 and o.d.has("belfry") and o.dir == 1:
			belfries.append(o)
	for e: Enemy in enemies:
		e.covered = false   # in an Iron Belfry's shadow: walking just behind it on its road
		for b: Enemy in belfries:
			var gap := b.dist - e.dist
			if b != e and b.path == e.path and e.dir == 1 and gap > 0.0 and gap <= Defs.BELFRY["cover"]:
				e.covered = true
	for e: Enemy in enemies:
		if e.hp <= 0.0:
			continue   # slain this frame; removed below
		if e.hit > 0.0:
			e.hit -= dt
			e.knock *= 0.8
		if e.slow > 0.0:
			e.slow -= dt
		if e.wade > 0.0:
			e.wade -= dt
		if e.mark > 0.0:
			e.mark -= dt
		if e.untouch > 0.0:
			e.untouch -= dt
		if e.d.has("surge"):
			e.surge_t -= dt
			if e.surge_t <= 0.0:
				_surge(e)
		e.stride += pace(e) * dt
		if e.d.has("sapper") and _sapper(e, dt):
			continue   # off the road, running at a tower or lighting his keg
		if e.d.has("belfry") and not e.retreat:
			e.sling -= dt
			if e.sling <= 0.0:   # a Sapper jumps out
				e.sling = Defs.BELFRY["sapper"]
				_rally.append({"codes": ["a"], "path": e.path, "dist": maxf(0.0, e.dist - 0.4), "wave": e.wave})
		var sp := pace(e)
		if e.d.has("siege") and _siege(e, dt):
			sp = 0.0
		if e.chant > 0.0:
			if e.fear > 0.0:   # Dread breaks the chant: now he runs like anyone else
				e.chant = 0.0
				chants_broken += 1
				_text(e.pos + Vector2(0, -0.8), "Chant broken!", Color("c9c0ff"))
			else:
				e.chant -= dt
				if e.chant <= 0.0:
					_vanish(e)
					continue
				sp = 0.0
		if e.d.has("engineer") and _repairing(e, dt):
			sp = 0.0
		if e.d.has("rage") and e.hp < e.max_hp * 0.5:
			sp *= float(e.d["rage"])
		var zm := _zone_mul(e, dt)
		if zm != 1.0:
			sp *= zm
		for o: Enemy in heralds:
			if not e.swim and not aloof(e) and o.pos.distance_to(e.pos) <= Defs.HASTE_RANGE:
				sp *= 1.0 + float(o.d["haste"])
				break
		if e.fear > 0.0:
			# Terrified: back away from the lair, or freeze if already running with gems.
			e.fear -= dt
			if e.dir == 1:
				e.dist = maxf(0.0, e.dist - sp * 0.6 * dt)
		else:
			if e.dir == -1 and e.carry == 0 and home > 0 and int(e.d["cap"]) > 0 and not e.retreat and not e.d.has("belfry"):
				# Turned back empty-handed, but a dropped gem has since rolled home: back to the lair.
				e.dir = 1
			var goal := -1.0 if _stranded(e) else _gem_goal(e)
			if _stranded(e):
				# Their boat is sunk: the only way off the map is back past the cave and out by land.
				e.dist = minf(float(level.paths[e.path]["total"]), e.dist + sp * dt)
				if e.dist >= float(level.paths[e.path]["total"]):
					_to_land_road(e)
			elif goal >= 0.0:
				# A gem lies out on this road: go for it, back the way it came if need be.
				var step := minf(sp * dt, absf(goal - e.dist))
				e.dist += step * signf(goal - e.dist)
			else:
				e.dist += sp * dt * e.dir
		var total: float = level.paths[e.path]["total"]
		if e.d.has("boat") and e.dist >= float(level.landings[e.path]) and float(level.landings[e.path]) >= 0.0:
			e.dist = float(level.landings[e.path])   # beached: it waits while its crew steps off
			_land(e, dt)
			if e.gone:
				continue
		if e.dir == -1 and level.path_kind[e.path] == "river" and not e.d.has("boat") and e.dist <= float(level.landings[e.path]) and _boat_waiting(e.path):
			_board(e)
			continue
		if e.dir == 1 and e.dist >= total and e.d.has("belfry"):
			_unload(e)
		if e.dir == 1 and e.dist >= total:
			var take := mini(int(e.d["cap"]), home)
			e.carry += take
			home -= take
			e.dir = -1
			if take > 0:
				touched = true
				_text(level.lair_center + Vector2(0, -0.6), "-%d gem" % take, Color("ff7a90"))
				sound.emit("grab")
				if e.d.has("chant"):   # a Spiriter chants at the cave mouth instead of running
					e.chant = Defs.CHANT_TIME
					_text(e.pos + Vector2(0, -0.8), "He chants!", Color("ff7a90"))
		if e.dir == -1 and e.dist <= 0.0:
			e.gone = true
			if e.carry > 0:
				lost += e.carry
				toast.emit("%s escaped with %s" % [e.d["name"], "a gem" if e.carry == 1 else "%d gems" % e.carry])
				sound.emit("lost")
		if not e.pave.is_empty():
			if e.dir == 1:
				e.pave["to"] = maxf(float(e.pave["to"]), e.dist)
			else:   # turned back for a gem: the paving stops here
				e.pave["until"] = time + Defs.PAVE_FADE
				e.pave = {}
		if e.wave > 0 and not e.retreat:
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
				if o.hp > 0.0 and not aloof(o) and o.pos.distance_to(e.pos) <= float(e.d["ward"]):
					o.slow = 0.0
					o.fear = 0.0
		if e.d.has("heal"):
			for o: Enemy in enemies:
				if o != e and o.hp > 0.0 and o.hp < o.max_hp and not aloof(o) and o.pos.distance_to(e.pos) < 1.5:
					o.hp = minf(o.max_hp, o.hp + float(e.d["heal"]) * dt)
		if e.carry < int(e.d["cap"]):
			for g: Drop in drops:
				if g.n > 0 and g.fall <= 0.0 and g.pos.distance_to(e.pos) < 0.4:
					var take := mini(int(e.d["cap"]) - e.carry, g.n)
					touched = true
					g.n -= take
					e.carry += take
					e.dir = -1
					sound.emit("grab")
	for e: Enemy in enemies:
		if e.gone or e.hp <= 0.0:
			_leave(e)
		if e.wave > 0 and (e.gone or e.hp <= 0.0):
			if not e.gone:
				_judge_kill(e.wave)
			wave_left[e.wave] -= 1
			if wave_left[e.wave] == 0:
				_judge_wave(e.wave)
	enemies = enemies.filter(func(e: Enemy) -> bool: return not e.gone and e.hp > 0.0)
	for i in paved.size():
		if not paved[i].is_empty():
			paved[i] = paved[i].filter(func(p: Dictionary) -> bool: return time < float(p["until"]))


## A hero leaves the map (slain, escaped, landed or blown up): let go of his tower, and his paving
## starts to fade.
func _leave(e: Enemy) -> void:
	if e.sap != null:
		e.sap.sapped = null
		e.sap = null
	if not e.pave.is_empty():
		e.pave["until"] = time + Defs.PAVE_FADE
		e.pave = {}


## Stun, Rubble and Silence weigh this much (Sturdy Foundations lightens them).
func sturdy_mul() -> float:
	return 1.0 - Defs.STURDY * skill("sturdy")


## A hero's own walking speed in tiles a second: his base speed, held back by chill and by the
## gems he carries (Defs.CARRY_SLOW each, at most CARRY_SLOW_MAX). The ground (_zone_mul), Herald
## haste, Berserker rage and the like multiply on top of it.
func pace(e: Enemy) -> float:
	var chill := (1.0 - e.slow_amt) if e.slow > 0.0 else 1.0
	if e.d.has("boat") and e.dir == -1:   # rowing back upstream, heavy with loot
		chill *= Defs.ROW_BACK
	return float(e.d["spd"]) * chill * (1.0 - minf(Defs.CARRY_SLOW_MAX, Defs.CARRY_SLOW * e.carry))


## Moves e off the road toward `to` at its own speed; true once it is within `stop` tiles of it.
func _walk_to(e: Enemy, to: Vector2, stop: float, dt: float) -> bool:
	var gap := to - e.pos
	var sp := pace(e) * dt
	if gap.length() <= stop + sp:
		if stop <= 0.0:
			e.pos = to
		return true
	if absf(gap.x) > 0.01:
		e.face = 1 if gap.x > 0.0 else -1
	e.pos += gap.normalized() * sp
	return false


## A Sapper runs off the road at the nearest tower within reach that is not on a raised tile (and
## no other Sapper is after), lights a fuse beside it and stuns it, dying in the blast (no bounty).
## True while he is off the road: he moves himself.
func _sapper(e: Enemy, dt: float) -> bool:
	if e.sap != null and towers.get(e.sap.cell) != e.sap:
		e.sap = null   # his tower was sold: back to the road
		e.fuse = -1.0
		e.back = true
	if e.back:
		if _walk_to(e, level.path_pos(e.path, e.dist), 0.0, dt):
			e.back = false
		return e.back
	if e.sap == null:
		if e.dir != 1 or e.fear > 0.0:
			return false
		var best: Tower = null
		var bd := INF
		for tw: Tower in towers.values():
			if level.high.has(tw.cell) or tw.sapped != null or tw.stun > 0.0:
				continue
			var dd := tw.pos.distance_to(e.pos)
			if dd <= Defs.SAPPER["reach"] and dd < bd:
				bd = dd
				best = tw
		if best == null:
			return false
		e.sap = best
		best.sapped = e
	if e.fuse < 0.0:
		if _walk_to(e, e.sap.pos, 0.42, dt):
			e.fuse = 0.0
			sound.emit("chop")
		return true
	e.fuse += dt
	if e.fuse >= Defs.SAPPER["fuse"]:
		var tw := e.sap
		tw.stun = maxf(tw.stun, Defs.STUN_TIME * sturdy_mul())
		stuns += 1
		_boom(e.pos, 0.6, 0.4)
		_fx("smoke", tw.pos, 0.6, 1.2)
		_text(tw.pos + Vector2(0, -0.9), "Stunned!", Color("ff9a7a"))
		sound.emit("boom")
		tw.sapped = null
		e.sap = null
		e.fuse = -1.0
		e.gone = true   # he dies in his own blast: neither slain nor escaped
	return true


## A Sapper slain with his fuse lit: the keg goes off among the heroes around him.
func _keg(e: Enemy) -> void:
	e.fuse = -1.0
	var before := kills
	for o: Enemy in enemies.duplicate():
		if o != e and o.hp > 0.0 and o.pos.distance_to(e.pos) <= Defs.SAPPER["r"]:
			hurt(o, Defs.SAPPER["dmg"], true)
	keg_best = maxi(keg_best, kills - before)
	_boom(e.pos, Defs.SAPPER["r"], 0.5)
	sound.emit("boom")


## A Trebuchet rolls until a tower is in reach (or it is far enough down the road), sets up, then
## buries the strongest tower in reach under Rubble every few seconds. When the last wave is out and
## only engines are left, it packs up and rolls away. True while it stands still.
func _siege(e: Enemy, dt: float) -> bool:
	if e.retreat:
		return false
	if wave >= level.waves.size() and queue.is_empty() and enemies.all(func(o: Enemy) -> bool: return o.hp <= 0.0 or o.d.has("siege")):
		_retreat(e)
		return false
	var tb: Dictionary = Defs.TREBUCHET
	if not e.deployed:
		if e.dir != 1:
			return false
		var near := towers.values().any(func(tw: Tower) -> bool: return tw.pos.distance_to(e.pos) <= tb["reach"])
		if not near and e.dist < float(level.paths[e.path]["total"]) * tb["stop"]:
			return false
		e.deployed = true
		e.sling = tb["setup"]
		_text(e.pos + Vector2(0, -0.9), "Siege!", Color("ff9a7a"))
	e.sling -= dt
	if e.sling <= 0.0:
		var best: Tower = null
		for tw: Tower in towers.values():
			if tw.rubble > 0.0 or tw.pos.distance_to(e.pos) > tb["reach"]:
				continue
			if best == null or tw.spent > best.spent or (tw.spent == best.spent and tw.lvl > best.lvl):
				best = tw
		if best == null:
			e.sling = 0.5   # nothing to hit: look again soon
		else:
			e.sling = tb["every"]
			e.stones += 1
			var f := Fx.new()
			f.kind = "stone"
			f.pos = e.pos + Vector2(0, -0.6)
			f.to = best.pos
			f.cell = best.cell
			f.dur = tb["flight"]
			fx.append(f)
			sound.emit("whoosh")
	return true


## An engine turns for home: it never comes back, and leaving does not count as escaping.
func _retreat(e: Enemy) -> void:
	e.retreat = true
	e.deployed = false
	e.dir = -1
	_text(e.pos + Vector2(0, -0.9), "Retreat!", Color("c9c0ff"))


## The Iron Belfry reached the den: its Footmen pour out and it rolls away.
func _unload(e: Enemy) -> void:
	e.unloaded = true
	_rally.append({"codes": Level._parse_wave(String(Defs.BELFRY["unload"])), "path": e.path, "dist": maxf(0.0, e.dist - 0.3), "wave": e.wave})
	_text(e.pos + Vector2(0, -1.0), "The doors open!", Color("ff9a7a"))
	sound.emit("horn")
	_retreat(e)


## Road zones are the one place hero speed changes with the ground: a ford (shallows) slows and
## soaks, a flooded ford or a collapsed bridge makes heroes swim, paving speeds them up. Returns
## the speed factor for e this frame and updates its Soaked and swimming state.
func _zone_mul(e: Enemy, dt: float) -> float:
	if e.soak > 0.0:
		e.soak -= dt
	e.swim = false
	e.hidden = false
	var m := 1.0
	var z := level.zone_at(e.path, e.dist) if not level.zones[e.path].is_empty() else ""
	var cell := Vector2i(floori(e.pos.x), floori(e.pos.y))
	var cross: int = level.crossings.get(cell, -1) if z != "" else -1
	var free := e.d.has("wader") or e.wade > 0.0   # Fenwalkers, and heroes lifted by the Tidecaller's surge
	match z:
		"ford":
			if cross >= 0 and float(planks.get(cross, -1.0)) > time:
				pass   # planked over: a dry crossing
			elif free:
				pass
			else:
				e.soak = Defs.SOAK_TIME
				if tide_up:
					e.swim = true
				else:
					m = Defs.ZONE_SPEED["ford"]
			if not (cross >= 0 and float(planks.get(cross, -1.0)) > time):
				e.hidden = e.d.has("diver")
		"bridge":
			if collapsed.has(cell):
				e.hidden = e.d.has("diver")
				if not free:
					e.soak = Defs.SOAK_TIME
					e.swim = true
	if level.path_kind[e.path] == "river" and not e.d.has("boat") and e.dist < float(level.landings[e.path]):
		# Off the boat and back into the river (a crew running away with gems): they must swim.
		e.hidden = e.d.has("diver")
		if not free:
			e.soak = Defs.SOAK_TIME
			e.swim = true
	if e.d.has("engineer") and e.zone == "ford" and z != "ford" and e.crossing >= 0:
		planks[e.crossing] = time + Defs.PLANK_TIME   # he lays planks over the ford he just crossed
	e.zone = z
	if cross >= 0:
		e.crossing = cross
	if e.swim:
		m = Defs.ZONE_SPEED["swim"]
	for p: Dictionary in paved[e.path]:
		if e.dist >= p["from"] and e.dist < p["to"] and time < float(p["until"]):
			m *= Defs.ZONE_SPEED["paved"]
			break
	return m


func is_soaked(e: Enemy) -> bool:
	return e.soak > 0.0


## The Tidecaller's surge: heroes around her shed chill and Dread and wade freely for a while.
func _surge(t: Enemy) -> void:
	t.surge_t = Defs.SURGE["every"]
	for o: Enemy in enemies:
		if o.hp > 0.0 and o.pos.distance_to(t.pos) <= Defs.SURGE["r"]:
			o.slow = 0.0
			o.fear = 0.0
			o.wade = Defs.SURGE["dur"]
	_fx("surge", t.pos, Defs.SURGE["r"], 0.8)
	_text(t.pos + Vector2(0, -0.9), "Surge!", Color("9fd8f0"))
	sound.emit("whoosh")


## An Engineer walking up to a collapsed bridge stops at the bank and rebuilds it. True while he
## is at work (he stands still).
func _repairing(e: Enemy, dt: float) -> bool:
	if e.dir != 1 or collapsed.is_empty():
		e.work = 0.0
		return false
	for z: Dictionary in level.zones[e.path]:
		if z["kind"] != "bridge" or z["from"] < e.dist - 0.05 or z["from"] - e.dist > 0.3:
			continue
		var p := level.path_pos(e.path, z["from"] + 0.05)
		var cell := Vector2i(floori(p.x), floori(p.y))
		if not collapsed.has(cell):
			continue
		e.work += dt
		if e.work >= Defs.ENGINEER_FIX:
			e.work = 0.0
			repair_bridge(int(level.crossings.get(cell, -1)))
			_text(p + Vector2(0, -0.6), "Bridge rebuilt", Color("ff9a7a"))
		return true
	e.work = 0.0
	return false


## A boat at its landing: its crew steps ashore one by one (Defs.LAND_GAP apart) and marches on.
## Sink it before the last one is off and the rest drown. Once empty the boat is gone (neither
## slain nor escaped, so it does not count toward the threat).
func _land(e: Enemy, dt: float) -> void:
	if e.beached:
		return
	if e.ashore < 0.0:
		e.ashore = 0.0
		_text(e.pos + Vector2(0, -0.7), "They land!", Color("ff9a7a"))
		sound.emit("horn")
	e.ashore -= dt
	if e.ashore > 0.0:
		return
	if not e.crew.is_empty():
		var code: String = e.crew.pop_front()
		if e.wave > 0:
			wave_left[e.wave] += 1   # counted now, before the boat's own removal
		_rally.append({"codes": [code], "path": e.path, "dist": e.dist + 0.3, "wave": e.wave, "counted": true})
		e.ashore = Defs.LAND_GAP
	if e.crew.is_empty():
		# Empty, it waits on the shore to carry them away. It is no longer a hero of its wave.
		e.beached = true
		boats_landed += 1
		if e.wave > 0:
			wave_left[e.wave] -= 1
			if wave_left[e.wave] == 0:
				_judge_wave(e.wave)
			e.wave = 0


## A beached boat waits on this river road.
func _boat_waiting(path: int) -> bool:
	for o: Enemy in enemies:
		if o.beached and o.path == path and o.hp > 0.0:
			return true
	return false


## A hero walking back along a river road whose boat has been sunk: no way out by water.
func _stranded(e: Enemy) -> bool:
	return e.dir == -1 and not e.d.has("boat") and level.path_kind[e.path] == "river" and not _boat_waiting(e.path)


## Back at the cave with no boat to flee in: out along the shortest land road instead.
func _to_land_road(e: Enemy) -> void:
	var best := -1
	for r: int in level.land_roads:
		if best < 0 or float(level.paths[r]["total"]) < float(level.paths[best]["total"]):
			best = r
	if best < 0:
		return
	e.path = best
	e.dist = float(level.paths[best]["total"])
	e.swim = false


## A hero walking back reached the beached boat: he climbs aboard with whatever gems he holds and
## it rows back down the river. Sink it on the way and he drowns, and the gems roll home.
func _board(e: Enemy) -> void:
	for o: Enemy in enemies:
		if o.beached and o.path == e.path and o.hp > 0.0:
			e.gone = true
			o.crew.append(e.code)
			o.carry += e.carry
			e.carry = 0
			o.beached = false
			o.dir = -1
			o.dist = float(level.landings[o.path]) - 0.01
			_text(o.pos + Vector2(0, -0.7), "They row away!", Color("ff9a7a"))
			return


## Is the hero in water: a boat afloat, in a ford, or swimming a collapsed bridge.
func in_water(e: Enemy) -> bool:
	if e.d.has("boat"):
		return float(level.landings[e.path]) < 0.0 or e.dist <= float(level.landings[e.path])
	return e.zone == "ford" or e.swim


## Is pos under a Rainbringer's cloud.
func in_rain(pos: Vector2) -> bool:
	for r: Array in rains:
		if pos.distance_to(r[0]) <= r[1]:
			return true
	return false


## Mana to collapse bridge (crossing) i (flat COLLAPSE mana, less with Floodmaster).
func collapse_cost(i: int) -> int:
	return Defs.COLLAPSE["mana"] + Defs.COLLAPSE["step"] * int(collapses.get(i, 0)) - 5 * skill("land_flood")


## Heroes and boats in the water on a Sluice Gate's road right now: what opening it would hit.
func sluice_targets(s: Site) -> int:
	var n := 0
	for e: Enemy in enemies:
		if e.hp > 0.0 and e.path == s.path and in_water(e):
			n += 1
	return n


## A Sluice Gate's surge sweeps down its road: heroes in the water are pushed back and hurt
## through armour; a boat loses a third of its full health.
func _flood(s: Site) -> void:
	var d: Dictionary = Defs.SITES["sluice"]
	s.t = float(d["recharge"]) * (1.0 - 0.2 * skill("land_flood"))
	floods += 1
	var before := kills
	var hit := 0
	for e: Enemy in enemies.duplicate():
		if e.hp <= 0.0 or e.path != s.path or not in_water(e):
			continue
		hit += 1
		hurt(e, e.max_hp * float(d["boat_share"]) if e.d.has("boat") else float(d["dmg"]), true)   # a boat: a third of its full health
		if e.hp > 0.0:
			e.dist = maxf(0.0, e.dist - float(d["push"]))
			e.pos = level.path_pos(e.path, e.dist)
	best_flood = maxi(best_flood, kills - before)
	_fx("flood", s.pos, 1.5, 0.9)
	# The surge runs down the whole waterway, so the player sees where it went.
	var wet := float(level.landings[s.path])
	if wet < 0.0:
		wet = float(level.paths[s.path]["total"])
	var t := 0.0
	while t <= wet:
		_fx("flood", level.path_pos(s.path, t), 0.9, 0.8)
		t += 1.2
	_text(s.pos + Vector2(0, -0.7), "Flood! %d swept back" % hit, Color("9fd8f0"))
	sound.emit("whoosh")


func collapse_bridge(i: int) -> void:
	for c: Vector2i in level.crossing_cells[i]:
		collapsed[c] = true
	collapses[i] = int(collapses.get(i, 0)) + 1
	collapsed_n += 1
	_fx("splash", Vector2(level.crossing_cells[i][0]) + Vector2(0.5, 0.5), 0.8, 0.6)
	sound.emit("boom")
	ground_changed.emit()


func repair_bridge(i: int) -> void:
	if i < 0:
		return
	for c: Vector2i in level.crossing_cells[i]:
		collapsed.erase(c)
	ground_changed.emit()


## Where along its road a hero with room to carry more should walk to reach the nearest gem lying
## outside the lair, or -1 if none is on its road. Gems on a joined road count when they lie on
## this one too.
func _gem_goal(e: Enemy) -> float:
	if e.carry >= int(e.d["cap"]):
		return -1.0
	var best := -1.0
	var best_gap := INF
	for g: Drop in drops:
		if g.n <= 0:
			continue
		var d := g.dist if g.path == e.path else level.nearest_dist(e.path, g.pos)
		if g.path != e.path and level.path_pos(e.path, d).distance_to(g.pos) > 0.3:
			continue
		var gap := absf(d - e.dist)
		if gap < best_gap:
			best_gap = gap
			best = d
	return best


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
	if reach < t["easy"]:
		threat += t["up_easy"] + (t["up_max"] - t["up_easy"]) * (t["easy"] - reach) / t["easy"]
	elif reach < t["hard"]:
		threat += t["up_mid"]
	elif reach < 1.0:
		threat += t["up_close"]
	else:
		threat += t["up_touched"]
	# Riches draw heroes: unspent gold over the line adds threat too.
	threat += minf(t["rich_max"], maxf(0.0, gold - t["rich"]) * t["per_gold"])
	threat = minf(threat, t["max"])
	wave_left.erase(w)
	wave_peak.erase(w)
	wave_live.erase(w)


## A hero of wave w fell. While the wave is going easily, the threat rises a little at once, so
## the heroes still to come in it (and the next wave, which may start before this one ends) are
## already tougher instead of waiting for the wave to be judged.
func _judge_kill(w: int) -> void:
	var t: Dictionary = Defs.THREAT
	var live: float = wave_live.get(w, 0.0)
	if wave_peak.get(w, 0.0) >= t["easy"] or live >= t["kill_max"]:
		return
	var step := minf(t["up_kill"], t["kill_max"] - live)
	wave_live[w] = live + step
	threat = minf(threat + step, t["max"])


func _update_drops(dt: float) -> void:
	for g: Drop in drops:
		if g.fall > 0.0:   # still falling from the air: it rolls once it lands
			g.fall = maxf(0.0, g.fall - dt)
			continue
		var total: float = level.paths[g.path]["total"]
		g.dist = minf(total, g.dist + Defs.DROP_SPEED * (1.0 + 0.2 * skill("gem_magnet")) * dt)
		g.pos = level.path_pos(g.path, g.dist)
		if g.dist >= total:
			home += g.n
			g.n = 0
	drops = drops.filter(func(g: Drop) -> bool: return g.n > 0)


## Who a tower shoots: gem carriers first, then special heroes (Cleric, Shieldbearer, Warden, Herald),
## then whoever has the least health left (Auto aim). Skips `skip` and `skips`; a Hunter's Lodge (healthiest)
## wants the toughest hero after gem carriers. The player may set a tower's aim (Tower.aim) to Strongest or
## Closest to the cave instead; gem carriers come first whatever it is. Hidden Divers are never picked.
## Tower aim choices in the order the tile panel button steps through them, and their names.
const AIMS := ["auto", "strong", "first"]
const AIM_NAMES := {"auto": "Auto", "strong": "Strongest", "first": "Closest to the cave"}


func _pick_target(tw: Tower, skip: Enemy = null, skips: Array = [], healthiest := false) -> Enemy:
	var rg := tw.stat("range")
	var best: Enemy = null
	var best_score := -INF
	for e: Enemy in enemies:
		if e == skip or e.hp <= 0.0 or e.hidden or e.covered or e.pos.distance_to(tw.pos) > rg or (not skips.is_empty() and skips.has(e)):
			continue
		var score := 0.0
		match tw.aim:
			"strong":
				score = e.hp
			"first":
				score = -e.pos.distance_to(level.lair_center)
			_:
				score = e.hp if healthiest else -e.hp
				if e.d.get("special", false) and not healthiest:
					score += 100000.0
		if e.carry > 0:
			score += 1000000.0
		if e.beached:   # an empty boat on the shore: only when no hero is in reach
			score -= 10000000.0
		if score > best_score:
			best_score = score
			best = e
	return best


func _update_towers(dt: float) -> void:
	var censers: Array = enemies.filter(func(o: Enemy) -> bool: return o.hp > 0.0 and o.d.has("censer"))
	var holy := hallow_on()
	for tw: Tower in towers.values():
		if tw.flash > 0.0:
			tw.flash -= dt
		var was := tw.holy
		tw.holy = holy and level.hallowed.has(tw.cell)
		if was != tw.holy:
			_cover.clear()   # its reach changed
		tw.silence = 0.0   # an Inquisitor's censer smoke reaches it
		for o: Enemy in censers:
			if o.pos.distance_to(tw.pos) <= float(o.d["censer"]):
				tw.silence = Defs.SILENCE_SLOW * sturdy_mul()
				break
		if tw.stun > 0.0:
			tw.stun -= dt
		if tw.rubble > 0.0:
			tw.rubble -= dt
		if tw.blocked():   # stunned or buried: no firing, and a beam goes out and cools
			tw.beam = null
			tw.beam2 = null
			tw.heat = maxf(0.0, tw.heat - dt / Defs.HEAT_TIME)
			tw.heat2 = maxf(0.0, tw.heat2 - dt / Defs.HEAT_TIME)
			continue
		if Defs.TOWERS[tw.type]["kind"] == "beam":
			_update_beam(tw, dt)
			continue
		if tw.mastery == "ossuary":
			_update_ossuary(tw, dt)
			continue
		tw.cd -= dt
		if tw.cd > 0.0:
			continue
		var best := _pick_target(tw, null, [], tw.mastery == "lodge")
		if best == null:
			continue
		tw.cd = tw.stat("rate")
		tw.flash = 0.15
		var s := _make_shot(tw, best)
		shots.append(s)
		sound.emit("hut" if s.kind == "arrow" else "crypt")
		if tw.type == "moss" and tw.has_ability() and tw.mastery != "lodge":
			# Volley: a second arrow at another hero; a Longhouse looses two more.
			var skips: Array = [best]
			for k in (2 if tw.mastery == "longhouse" else 1):
				var other := _pick_target(tw, best, skips)
				if other == null:
					break
				skips.append(other)
				var v := _make_shot(tw, other)
				v.dmg *= maxf(tw.ability_power(), Defs.LONGHOUSE_SHARE) if tw.mastery == "longhouse" else tw.ability_power()
				shots.append(v)


## Ossuary: a bolt is stored every reload, hero or not, up to four; then they fly 0.3 s apart at the
## tower's target, as any Crypt picks it (_pick_target: its aim, gem carriers first): a burst on one
## hero. A hero the bolts already flying will finish is passed over, so no bolt is wasted on the dead.
func _update_ossuary(tw: Tower, dt: float) -> void:
	tw.cd -= dt
	if tw.charges >= Defs.OSSUARY["charges"]:
		tw.cd = maxf(tw.cd, 0.0)
	elif tw.cd <= 0.0:
		tw.charges += 1
		tw.cd = tw.stat("rate")
	tw.volley_t -= dt
	if tw.charges <= 0 or tw.volley_t > 0.0:
		return
	var coming := {}   # hero -> damage this tower's bolts in flight will deal (armour counted)
	for s: Shot in shots:
		if s.src == tw and not s.done and s.target != null and s.target.hp > 0.0:
			coming[s.target] = float(coming.get(s.target, 0.0)) + maxf(1.0, s.dmg - float(s.target.d["armor"]))
	var doomed := []
	for e: Enemy in coming:
		if coming[e] >= e.hp:
			doomed.append(e)
	var best := _pick_target(tw, null, doomed)
	if best == null:
		tw.volley_hits.clear()
		return
	tw.charges -= 1
	tw.volley_t = Defs.OSSUARY["gap"]
	if tw.volley_hits.is_empty():
		tw.volley_kills = 0   # a new volley begins
	tw.volley_hits.append(best)
	if tw.charges == 0:
		tw.volley_hits.clear()
	tw.flash = 0.15
	shots.append(_make_shot(tw, best))
	sound.emit("crypt")


## The Cinder Shrine burns one hero without pause. It holds that hero until it dies or leaves
## range (or a gem carrier shows up), and its damage grows with heat. Armour does not stop it.
## A Twin Flame runs two beams, each with its own heat; a Sunlance burns through to the heroes behind.
func _update_beam(tw: Tower, dt: float) -> void:
	if tw.mastery == "twin":
		_beam(tw, dt, 0, Defs.TWIN_DMG)
		_beam(tw, dt, 1, Defs.TWIN_SAME if tw.beam2 != null and tw.beam2 == tw.beam else Defs.TWIN_DMG)
	else:
		_beam(tw, dt, 0, 1.0)


func _beam(tw: Tower, dt: float, slot: int, share: float) -> void:
	var b := tw.beam if slot == 0 else tw.beam2
	var heat := tw.heat if slot == 0 else tw.heat2
	var lost_hold := b == null or b.hp <= 0.0 or b.gone or b.hidden or b.covered or b.pos.distance_to(tw.pos) > tw.stat("range")
	if lost_hold or b.carry == 0:
		var best := _pick_target(tw, tw.beam if slot == 1 else null)
		if best == null and slot == 1:
			best = _pick_target(tw)   # only one hero in reach: both beams burn him
		if best != b and (lost_hold or (best != null and best.carry > 0)):
			b = best
			var keep := Defs.HEAT_KEEP + 0.1 * skill("ash_memory")
			if tw.mastery == "sunlance":
				keep = maxf(keep, Defs.SUNLANCE["keep"])
			heat *= keep
			tw.cd = 0.0
	var rate := dt * tw.rate_mul / Defs.HEAT_TIME / (1.0 + tw.silence)   # an Inquisitor slows the heating
	if b == null:
		heat = maxf(0.0, heat - rate)
	else:
		heat = minf(1.0, heat + (rate * Defs.SOAK_HEAT if b.soak > 0.0 else rate))   # wet heroes heat slower
		if not rains.is_empty() and in_rain(b.pos):
			heat = minf(heat, Defs.RAIN_HEAT)   # under a Rainbringer's cloud the beam stays cool
		tw.flash = 0.15
		var dps := tw.stat("dmg") * (1.0 + (Defs.HEAT_MAX + 0.4 * skill("ash_core") - 1.0) * heat) * share
		hurt(b, dps * dt, true, tw)
		if tw.mastery == "sunlance":
			_lance(tw, b, dps * dt * Defs.SUNLANCE["share"])
		if b.hp <= 0.0:
			b = null
	if slot == 0:
		tw.beam = b
		tw.heat = heat
	else:
		tw.beam2 = b
		tw.heat2 = heat


## Sunlance: every other hero on the line from the shrine through its target, out to its range.
func _lance(tw: Tower, target: Enemy, dmg: float) -> void:
	var dir := (target.pos - tw.pos).normalized()
	var rg := tw.stat("range")
	var burning := 1
	for o: Enemy in enemies:
		if o == target or o.hp <= 0.0 or o.hidden:
			continue
		var rel := o.pos - tw.pos
		var along := rel.dot(dir)
		if along > 0.0 and along <= rg and absf(rel.cross(dir)) <= float(o.d["r"]) + 0.15:
			hurt(o, dmg, true, tw)
			burning += 1
	sunlance_best = maxi(sunlance_best, burning)


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
	if tw.type == "moss":
		s.ap = skill("moss_bodkin")
	match tw.mastery:
		"lodge":   # a heavy javelin: armour does not stop it, and it marks its hero
			s.dmg *= Defs.LODGE["dmg"]
			s.pierce = true
			s.mark = Defs.LODGE["mark"]
		"mausoleum":
			s.burst = true
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
				s.target.hit = 0.12
				s.target.knock = to.normalized() * 0.07
				var at := s.target.pos
				_strike(s, s.target, s.dmg)
				if s.burst:   # Mausoleum: the bolt bursts over the heroes close by
					for o: Enemy in enemies.duplicate():
						if o != s.target and o.hp > 0.0 and not o.hidden and o.pos.distance_to(at) <= Defs.MAUSOLEUM["r"]:
							_strike(s, o, s.dmg * Defs.MAUSOLEUM["share"])
		else:
			s.pos += to.normalized() * step
	shots = shots.filter(func(s: Shot) -> bool: return not s.done)


## One hit of a shot on one hero: damage, then chill, Dread and a Hunter's mark.
func _strike(s: Shot, e: Enemy, dmg: float) -> void:
	var before := kills
	hurt(e, dmg, s.pierce, s.src, s.ap)
	if s.kind == "den":
		den_kills += kills - before
	if s.mark > 0.0:
		e.mark = s.mark
	if s.slow > 0.0 and not e.d.has("steady"):
		var amt := s.slow * (Defs.FLY_CHILL if flying(e) else 1.0)   # a flyer is only half held
		e.slow_amt = maxf(amt, e.slow_amt) if e.slow > 0.0 else amt
		var chill := Defs.SLOW_TIME + 0.4 * skill("frost_freeze")
		e.slow = chill * Defs.SOAK_CHILL if e.soak > 0.0 else chill
	if s.fear > 0.0 and e.hp > 0.0 and rng.randf() < s.fear and not e.d.has("steady") and not e.d.has("fearless"):
		e.fear = Defs.ABILITIES["frost"]["dur"] + 0.3 * skill("frost_dread")
		dreads += 1


func _update_pools(dt: float) -> void:
	for pl: Pool in pools:
		pl.t += dt
		if not rains.is_empty() and in_rain(pl.pos):
			pl.t = pl.dur   # the rain puts it out
			continue
		for e: Enemy in enemies:
			if e.pos.distance_to(pl.pos) <= pl.r and not flying(e):   # flyers pass over Lava
				hurt(e, pl.dps * dt, true, pl.src)
	pools = pools.filter(func(pl: Pool) -> bool: return pl.t < pl.dur)


func _update_loot(dt: float) -> void:
	for l: Loot in loot:
		l.t += dt   # only animates; loot never expires


func _update_fx(dt: float) -> void:
	for f: Fx in fx:
		f.t += dt
		if f.kind == "stone" and not f.hit and f.t >= f.dur:
			f.hit = true
			var tw: Tower = towers.get(f.cell)
			if tw != null:
				tw.rubble = maxf(tw.rubble, Defs.RUBBLE_TIME * sturdy_mul())
				rubbles += 1
				_fx("smoke", tw.pos, 0.7, 1.0)
				_text(tw.pos + Vector2(0, -0.9), "Buried!", Color("ff9a7a"))
				sound.emit("boom")
		if f.kind == "meteor" and not f.hit and f.t >= Defs.METEOR["delay"]:
			f.hit = true
			_boom(f.pos, Defs.METEOR["radius"], 0.5)
			_fx("shock", f.pos, Defs.METEOR["radius"] * 1.6, 0.5)
			_fx("scorch", f.pos, Defs.METEOR["radius"] * 0.8, 8.0)
			burst.emit("meteor", f.pos, "")
			sound.emit("boom")
			var before := kills
			for e: Enemy in enemies:
				if e.pos.distance_to(f.pos) <= Defs.METEOR["radius"]:
					var under := e.hidden
					hurt(e, meteor_damage(), true)
					if under and e.hp <= 0.0:
						diver_meteor += 1
			best_meteor = maxi(best_meteor, kills - before)
			meteor_kills += kills - before
	fx = fx.filter(func(f: Fx) -> bool: return f.t < f.dur)


func hurt(e: Enemy, dmg: float, pierce := false, src: Tower = null, ap := 0) -> void:
	if e.hp <= 0.0 or e.untouch > 0.0:
		return
	var dealt := dmg if pierce else maxf(1.0, dmg - (float(e.d["armor"]) if ap == 0 else maxf(0.0, float(e.d["armor"]) - ap)))
	if not pierce:
		dealt *= 1.0 - _guard(e)
	if e.mark > 0.0:
		dealt *= 1.0 + Defs.LODGE["mark_dmg"]   # marked by a Hunter's Lodge
	if src != null and src.type == "moss" and e.carry > 0 and skill("moss_keen") > 0:
		dealt *= 1.0 + 0.1 * skill("moss_keen")   # Keen Eyes
	if src != null and src.type == "frost" and (e.slow > 0.0 or e.soak > 0.0) and skill("frost_cold") > 0:
		dealt *= 1.0 + 0.05 * skill("frost_cold")   # Grave Cold
	dealt = minf(dealt, e.hp)
	e.hp -= dealt
	if src != null:
		_tower_xp(src, dealt)
	if e.hp > 0.0 and e.d.has("shield") and not e.shielded and e.hp < e.max_hp * Defs.JUSTICAR["below"]:
		# The Justicar's holy shield: untouchable for a moment, and healed.
		e.shielded = true
		e.untouch = Defs.JUSTICAR["dur"]
		e.hp = e.max_hp * Defs.JUSTICAR["heal"]
		if not _covered_by_towers(e.pos):
			shield_waste += 1
		_fx("surge", e.pos, 0.7, 0.6)
		_text(e.pos + Vector2(0, -0.9), "Holy shield!", Color("fff2c0"))
	if e.hp > 0.0 and e.d.has("seraph") and e.phase < Defs.SERAPH["at"].size() and e.hp < e.max_hp * float(Defs.SERAPH["at"][e.phase]):
		_seraph_land(e)
	if e.hp <= 0.0:
		gold += int(e.d["gold"])
		kills += 1
		kills_by[e.code] = int(kills_by.get(e.code, 0)) + 1
		if src != null:
			kills_tower[src.type] = int(kills_tower.get(src.type, 0)) + 1
		_race_kill(e.code)
		var paid := int(e.d["gold"])
		if src != null and src.mastery == "twin":
			if time - twin_t <= 1.0:
				twin_kills += 1
			twin_t = time
		if src != null and src.mastery == "ossuary":
			src.volley_kills += 1
			best_ossuary = maxi(best_ossuary, src.volley_kills)
		if src != null and src.mastery == "lodge" and e.code == "x":
			lodge_champion += 1
		if src != null and src.type == "moss" and src.lvl >= 4:   # Plunder
			src.plunder += 1
			var extra := mini(Defs.PLUNDER_START + src.plunder - 1, Defs.PLUNDER_MAX)
			gold += extra
			plundered += extra
			paid += extra
		_text(e.pos + Vector2(0, -0.3), "+%d" % paid, Color("e8b84a"))
		sound.emit("die")
		burst.emit("death", e.pos, e.code)
		if in_water(e):
			water_kills += 1
			if e.swim and e.zone == "bridge":
				collapse_kills += 1
		if e.d.has("boat") and not e.crew.is_empty():
			# Sunk before it landed: the crew drowns, and their bounties are yours.
			boats_sunk += 1
			for code: String in e.crew:
				var cd: Dictionary = Defs.ENEMIES[code]
				gold += int(cd["gold"])
				kills += 1
				drowned += 1
				kills_by[code] = int(kills_by.get(code, 0)) + 1
				_race_kill(code)
			_text(e.pos + Vector2(0, -0.8), "%d drowned" % e.crew.size(), Color("9fd8f0"))
			e.crew.clear()
		if e.carry > 0:
			var g := Drop.new()
			g.pos = e.pos
			g.n = e.carry
			gems_saved += e.carry
			g.path = e.path
			g.dist = e.dist
			if level.path_kind[e.path] == "air":   # fell from the air: to the nearest road, to roll home
				var near := _nearest_land(e.pos)
				g.path = near[0]
				g.dist = near[1]
				g.pos = level.path_pos(g.path, g.dist)
				g.from = e.pos
				g.fall = Defs.DROP_FALL
			drops.append(g)
			e.carry = 0
		if not (e.d.has("boss") or e.d.has("boat") or e.d.has("siege") or e.d.has("fly")):
			fallen.append(e.code)   # the Seraph may raise him again
			if fallen.size() > 40:
				fallen.pop_front()
		if e.chant > 0.0:
			chants_broken += 1
		if e.d.has("seraph"):
			seraph_phase = e.phase
		_roll_loot(e)
		if e.d.has("sapper") and e.fuse >= 0.0:
			_keg(e)
		if e.d.has("pave") and not e.pave.is_empty() and float(e.pave["to"]) - float(e.pave["from"]) < 3.0:
			pavior_early += 1
		if e.d.has("censer") and src != null and src.silence > 0.0 and src.pos.distance_to(e.pos) <= float(e.d["censer"]):
			silence_proof += 1
		if e.d.has("siege") and e.stones == 0:
			treb_fast += 1
		# A hero already off the map (escaped this frame, then hit by a shot in flight) raises nobody:
		# his wave has been judged, and the heroes would march in from where he left.
		if e.d.has("spill") and not e.unloaded and not e.gone:
			# Broken open before it reached the den: its garrison spills out where it fell.
			_rally.append({"codes": Level._parse_wave(String(e.d["spill"])), "path": e.path, "dist": e.dist, "wave": e.wave})
			_text(e.pos + Vector2(0, -0.8), "It breaks open!", Color("ff9a7a"))
		if e.d.has("rally") and not e.gone:
			# His escort rises where he fell (spawned next frame, outside any loop over heroes).
			_rally.append({"codes": Level._parse_wave(String(e.d["rally"])), "path": e.path, "dist": e.dist, "wave": e.wave})
			_text(e.pos + Vector2(0, -0.8), "Rally!", Color("ff9a7a"))
		if src != null and src.type == "ash" and src.has_ability() and rng.randf() < Defs.ABILITIES["ash"]["chance"]:
			_lava(src, e.pos)


## Online race: every RACE_KILL_SEND heroes slain (a drowned crew counts hero by hero) sends one
## like the last onto the rival's road.
func _race_kill(code: String) -> void:
	if not race_on:
		return
	race_kills += 1
	if race_kills % Defs.RACE_KILL_SEND == 0:
		race_sends += String(Defs.ENEMIES[code].get("send_as", code))


## Lava: a pool of burning ground where a Cinder Shrine killed a hero.
func _lava(tw: Tower, at: Vector2) -> void:
	if level.is_water(Vector2i(floori(at.x), floori(at.y))):
		return   # lava cannot form on water
	var pl := Pool.new()
	pl.pos = at
	pl.r = Defs.ABILITIES["ash"]["r"]
	pl.dur = Defs.ABILITIES["ash"]["dur"] + 0.5 * skill("ash_cooling")
	pl.dps = tw.stat("dmg") * Defs.HEAT_MAX * tw.ability_power()
	pl.src = tw
	lavas += 1
	pools.append(pl)


## Damage reduction from the strongest living Shieldbearer next to e (never from itself).
func _guard(e: Enemy) -> float:
	if aloof(e):
		return 0.0   # boats, engines and flyers are out of a Shieldbearer's reach
	var g := 0.0
	for o: Enemy in enemies:
		if o != e and o.hp > 0.0 and o.d.has("guard") and o.pos.distance_to(e.pos) <= Defs.GUARD_RANGE:
			g = maxf(g, float(o.d["guard"]))
	return g


func _tower_xp(tw: Tower, amount: float) -> void:
	tw.xp += amount * tw.xp_mul * (1.0 + Defs.SITES["altar"]["xp"] * tw.altars if tw.altars > 0 else 1.0)
	var ranks: Array = Defs.TOWER_XP_RANKS
	while tw.rank < ranks.size() and tw.xp >= ranks[tw.rank]:
		tw.rank += 1
		# Ranks stay hidden; only learning the ability is announced.
		if tw.has_ability() and tw.rank == Defs.ABILITY_RANK:
			_text(tw.pos + Vector2(0, -0.9), Defs.ABILITIES[tw.type]["name"] + "!", Color("c9c0ff"))
			abilities += 1
			learned[tw.type] = true
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
		# Worth more for stronger kinds of hero and later waves, but not for the threat: it rises
		# when you do well, and paying more for that would snowball into riches. Tougher lairs pay
		# only the square root of their extra hero health, or late lairs would drown you in gold.
		var later := sqrt(level.hp_mul) * (1.0 + Defs.WAVE_HP_SCALE * maxi(0, wave - 1))
		l.amount = Defs.LOOT_COIN_BONUS + roundi(float(e.d["gold"]) * Defs.LOOT_COIN_MUL * later)
	else:
		l.kind = "potion"
		l.amount = Defs.LOOT_POTION_MANA
	if wave >= level.waves.size():
		_take_loot(l)   # no wave comes after the last to gather it, so it is taken at once
	else:
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
	burst.emit("pickup_" + l.kind, l.pos, "")
	if l.kind == "coin":
		coins += 1
		gold += l.amount
		_text(l.pos + Vector2(0, -0.3), "+%d" % l.amount, Color("e8b84a"))
	else:
		potions += 1
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


## A drawn effect: "shock" (a ring sweeping out), "scorch" (burnt ground that fades).
func _fx(kind: String, pos: Vector2, r: float, dur: float) -> void:
	var f := Fx.new()
	f.kind = kind
	f.pos = pos
	f.r = r
	f.dur = dur
	fx.append(f)


func _boom(pos: Vector2, r: float, dur: float) -> void:
	var f := Fx.new()
	f.kind = "boom"
	f.pos = pos
	f.r = r
	f.dur = dur
	fx.append(f)


# ---------------------------------------------------------------- spells

## Meteor damage, with the Starfall skill.
func meteor_damage() -> float:
	return Defs.METEOR["dmg"] * (1.0 + Defs.HOARD_METEOR * skill("meteor_dmg"))


## Cuts a random patch of woods (the HUD's Cut woods button). Returns "" or why it could not.
func cut_random_woods() -> String:
	if trees.is_empty():
		return "No woods left"
	var cells: Array = trees.keys()
	return do_action("clear", cells[rng.randi_range(0, cells.size() - 1)])


func can_meteor() -> bool:
	return mana >= Defs.METEOR["cost"]


func cast_meteor(pos: Vector2) -> bool:
	if not can_meteor():
		return false
	mana -= Defs.METEOR["cost"]
	meteors += 1
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
	_attune()
	lit.clear()
	lights = []
	if not can_dark():
		return
	lights = [[level.lair_center, Defs.LIGHT["lair"] + 0.3 * skill("land_lantern")]]
	for tw: Tower in towers.values():
		lights.append([tw.pos, Defs.LIGHT["tower"] + 0.3 * skill("land_lantern")])
	for s: Site in sites.values():
		if s.owned and not Defs.HERO_SITES.has(s.kind):
			lights.append([s.pos, float(Defs.SITES[s.kind]["light"]) + 0.3 * skill("land_lantern")])
	for c in level.cols:
		for r in level.rows:
			var center := Vector2(c, r) + Vector2(0.5, 0.5)
			for l in lights:
				if center.distance_to(l[0]) <= l[1]:
					lit[Vector2i(c, r)] = true
					break
	light_changed.emit()


## Dark Altars you have freed strengthen the towers around them.
func _attune() -> void:
	var alts: Array = sites.values().filter(func(s: Site) -> bool: return s.kind == "altar" and s.owned)
	for tw: Tower in towers.values():
		tw.altars = 0
		for s: Site in alts:
			if s.pos.distance_to(tw.pos) <= Defs.SITES["altar"]["range"]:
				tw.altars += 1
		tw.altar_mul = 1.0 + tw.altars * (Defs.SITES["altar"]["dmg"] + 0.05 * skill("land_rites"))


func is_lit(c: Vector2i) -> bool:
	return not dark or lit.has(c)


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
	if level.crossings.has(c) and level.crossing_kind[level.crossings[c]] == "bridge":
		return _bridge_info(level.crossings[c])
	if level.road.has(c):
		return {"title": "Hero road", "text": "Nothing can be built on the road.", "actions": []}
	if level.is_lair(c):
		var txt := "%d gems inside. Heroes grab them and run for the edge of the map.\n" % home
		txt += "The den strikes heroes within %.1f tiles: %d of %d charges ready, one refills every %d s. Add charges in Dark Arts." % [
			Defs.DEN["range"], den_charges, den_max, int(Defs.DEN["refill"])]
		return {"title": "Your den", "text": txt, "actions": []}
	if trees.has(c):
		return {"title": "Woods", "text": "Cut the trees to free this %s tile for building. You sell the timber for gold." % _ground_name(t),
			"actions": [{"id": "clear", "label": "Cut woods", "price": "%d mana  +%dg" % [woods_cost(), Defs.CLEAR_GOLD], "mana": woods_cost()}]}
	if towers.has(c):
		var tw: Tower = towers[c]
		var d: Dictionary = Defs.TOWERS[tw.type]
		var acts := []
		if tw.rubble > 0.0:
			acts.append({"id": "rubble", "label": "Clear rubble", "price": "%dg" % Defs.RUBBLE_CLEAR, "gold": Defs.RUBBLE_CLEAR})
		if tw.lvl < 3:
			acts.append({"id": "upgrade", "label": "Upgrade", "price": "%dg" % d["cost"][tw.lvl], "gold": d["cost"][tw.lvl]})
		var offers := masteries_for(tw)
		for m: Dictionary in offers:
			acts.append({"id": "master:" + m["id"], "label": m["name"], "price": "%dg" % d["cost"][3], "gold": d["cost"][3]})
		acts.append({"id": "aim", "label": "Aim: %s" % AIM_NAMES[tw.aim], "price": "tap to change"})
		acts.append({"id": "sell", "label": "Sell", "price": "+%dg" % int(tw.spent * Defs.SELL_REFUND)})
		var ab: Dictionary = Defs.ABILITIES[tw.type]
		var txt := "Damage %d, range %.1f\n" % [int(tw.stat("dmg")), tw.stat("range")]
		if d["kind"] == "beam":
			txt = "Burns %d to %d per second as it heats, range %.1f\n" % [int(tw.stat("dmg")), int(tw.stat("dmg") * (Defs.HEAT_MAX + 0.4 * skill("ash_core"))), tw.stat("range")]
		# Battle-hardened ranks: what the tower's experience has given it so far.
		var ranks: int = Defs.TOWER_XP_RANKS.size()
		var prev_xp: float = Defs.TOWER_XP_RANKS[tw.rank - 1] if tw.rank > 0 else 0.0
		if tw.rank >= ranks:
			txt += "Battle-hardened %d/%d: +%d%% damage\n" % [tw.rank, ranks, roundi(100.0 * Defs.RANK_DMG * tw.rank)]
		else:
			txt += "Battle-hardened %d/%d: +%d%% damage (%d%% to the next rank)\n" % [tw.rank, ranks, roundi(100.0 * Defs.RANK_DMG * tw.rank),
				clampi(roundi(100.0 * (tw.xp - prev_xp) / (float(Defs.TOWER_XP_RANKS[tw.rank]) - prev_xp)), 0, 99)]
		if tw.has_ability():
			txt += "%s: %s" % [ab["name"], ab["text"]]
		else:
			txt += "%s, once the tower is battle-hardened and level III: %s" % [ab["name"], ab["text"]]
		for m: Dictionary in offers:
			txt += "
[Level IV] %s: %s" % [m["name"], m["text"]]
		var title := "%s, level %d" % [d["name"], tw.lvl]
		if tw.mastery != "":
			var m := mastery_def(tw.type, tw.mastery)
			title = "%s, level IV" % m["name"]
			txt += "
%s" % m["text"]
		if tw.type == "moss" and tw.lvl >= 4:
			txt += "
Plunder: +%d gold on its next kill (up to +%d)" % [mini(Defs.PLUNDER_START + tw.plunder, Defs.PLUNDER_MAX), Defs.PLUNDER_MAX]
		var status := tower_status(tw)
		if status != "":
			txt = status + "\n" + txt
		return {"title": title, "text": txt, "actions": acts}
	if level.is_water(c):
		return {"title": "Deep water" if t == "water" else "Shallows", "text": "Nothing can be built on water.", "actions": []}
	if not is_lit(c):
		return {"title": "Darkness", "text": "You can't build where you can't see. Towers, mines and wells light the ground around them.", "actions": []}
	var td: Dictionary = Defs.TOWERS[t]
	if level.high.has(c):
		var acts := []
		var bonus := []
		for type: String in Defs.TOWERS:
			acts.append(_build_action(type, Defs.TOWERS[type]["name"]))
			bonus.append("%s +%.1f" % [Defs.TOWERS[type]["name"], float(Defs.TOWERS[type]["high_range"]) + Defs.HEIGHTS_RANGE * skill("land_heights")])
		var hl := " Hallowed: towers here have less range and no ability while a Chapel stands." if hallow_on() and level.hallowed.has(c) else ""
		var hd := " Commanding Heights: +%d%% damage." % roundi(100.0 * Defs.HEIGHTS_DMG * skill("land_heights")) if skill("land_heights") > 0 else ""
		return {"title": "Raised ground", "text": "Any tower can be built up here, and it reaches further: %s.%s" % [", ".join(bonus), hd] + hl,
			"actions": acts}
	var holy_note := " Hallowed: towers here have less range and no ability while a Chapel stands." if hallow_on() and level.hallowed.has(c) else ""
	return {"title": td["name"], "text": "%s Builds only on %s.%s" % [td["blurb"], t, holy_note],
		"actions": [_build_action(t, "Build")]}


func _ground_name(t: String) -> String:
	return t


## What is hindering a tower, and what caused it, for its tile panel ("" if nothing).
func tower_status(tw: Tower) -> String:
	var out: Array[String] = []
	if tw.rubble > 0.0:
		out.append("BURIED under rubble by a Trebuchet: it can't fire for %d s, or clear it now." % ceili(tw.rubble))
	if tw.stun > 0.0:
		out.append("STUNNED by a Sapper's keg: it can't fire for %d s." % ceili(tw.stun))
	if tw.holy:
		out.append("HALLOWED ground: %d%% less range and no ability until every Chapel is razed." % roundi((1.0 - Defs.HALLOW_RANGE) * 100.0))
	if tw.silence > 0.0:
		out.append("SILENCED by an Inquisitor's censer: no ability, no battle-hardened bonus, %d%% slower." % roundi(tw.silence * 100.0))
	return "\n".join(out)


## A bridge's tile panel: collapse it (heroes must swim the gap) or see it is broken.
func _bridge_info(i: int) -> Dictionary:
	if collapsed.has(level.crossing_cells[i][0]):
		return {"title": "Broken bridge", "text": "Heroes swim the gap, slow and soaked. An Engineer can rebuild it.", "actions": []}
	var cost := collapse_cost(i)
	return {"title": "Bridge", "text": "Collapse it and heroes must swim the gap: slow, soaked, and no Herald can hurry them." + ("" if int(collapses.get(i, 0)) == 0 else "
Rebuilt bridges cost more to bring down again."),
		"actions": [{"id": "collapse", "label": "Collapse", "price": "%d mana" % cost, "mana": cost}]}


## What a building pays or gives with this battle's skills (Spoils of War, Rich Veins, Deep Springs, Black Rites).
func site_bounty(kind: String) -> int:
	return int(Defs.SITES[kind]["bounty"]) + 15 * skill("land_spoils")


func mine_gold() -> int:
	return int(Defs.SITES["mine"]["gold"]) + Defs.VEINS_GOLD * skill("land_veins")


func well_regen() -> float:
	return float(Defs.SITES["well"]["regen"]) + Defs.SPRINGS_REGEN * skill("land_springs")


func altar_boost() -> float:
	return float(Defs.SITES["altar"]["dmg"]) + 0.05 * skill("land_rites")


## Mana to cut one patch of woods (Sharp Axes takes 10% off per rank).
func woods_cost() -> int:
	return ceili(Defs.CLEAR_MANA * (1.0 - 0.1 * skill("land_axes")))


## Mana for one cut. Buildings that take several cuts cost more in all, but less per cut:
## the whole job costs 1.5x the base for 2 cuts, 2x for 3, 2.5x for 4.
func cut_cost(s: Site) -> int:
	var n := s.cuts
	return ceili(float(Defs.SITES[s.kind]["cut"]) * (1.0 + 0.5 * (n - 1)) / n * (1.0 - 0.1 * skill("land_axes")))


## A building's tile panel. One that takes several cuts also gets "cuts": [cuts left, cuts in all],
## which the panel shows as a bar.
func _site_info(s: Site) -> Dictionary:
	var info := _site_panel(s)
	if not s.owned and s.cuts > 1:
		info["cuts"] = [s.cuts_left, s.cuts]
	return info


func _site_panel(s: Site) -> Dictionary:
	var d: Dictionary = Defs.SITES[s.kind]
	var cut := {"id": "cut", "price": "%d mana" % cut_cost(s), "mana": cut_cost(s)}
	var more := ""   # cuts left are shown by the panel's bar (see _site_info)
	match s.kind:
		"altar":
			var boost := int(round((Defs.SITES["altar"]["dmg"] + 0.05 * skill("land_rites")) * 100.0))
			if s.owned:
				return {"title": d["name"], "text": "Yours. Towers within %.1f tiles deal %d%% more damage and rank up faster." % [d["range"], boost], "actions": []}
			cut["label"] = "Cut free"
			return {"title": d["name"], "text": d["text"] % [d["range"], boost], "actions": [cut]}
		"sluice":
			var txt: String = d["text"]
			if s.t > 0.0:
				return {"title": d["name"], "text": txt + "
Refilling: ready in %d s." % ceili(s.t), "actions": []}
			var wet := sluice_targets(s)
			if wet == 0:
				return {"title": d["name"], "text": txt + "
No boat on its river yet.", "actions": [{"id": "flood", "label": "No boat on the river", "price": "", "mana": 0, "disabled": true}]}
			return {"title": d["name"], "text": txt, "actions": [{"id": "flood", "label": "Open the sluice (%d boat%s)" % [wet, "" if wet == 1 else "s"], "price": "%d mana" % d["mana"], "mana": d["mana"]}]}
	match s.kind:
		"mine":
			if s.owned:
				return {"title": d["name"], "text": "Yours. Earns %d gold every %d s." % [d["gold"] + Defs.VEINS_GOLD * skill("land_veins"), int(d["every"])], "actions": []}
			cut["label"] = "Cut free"
			return {"title": d["name"], "text": d["text"] % [d["gold"] + Defs.VEINS_GOLD * skill("land_veins"), int(d["every"])] + more, "actions": [cut]}
		"well":
			if s.owned:
				return {"title": d["name"], "text": "Yours. +%.1f mana per second." % (d["regen"] + Defs.SPRINGS_REGEN * skill("land_springs")), "actions": []}
			cut["label"] = "Cut free"
			return {"title": d["name"], "text": d["text"] % (d["regen"] + Defs.SPRINGS_REGEN * skill("land_springs")) + more, "actions": [cut]}
	if s.owned:
		var ruin: String = {"camp": "Ruined barracks", "workshop": "Ruined workshop", "beacon": "Cold ashes"}.get(s.kind, "Ruins")
		return {"title": ruin, "text": "Nothing left but ash.", "actions": []}
	cut["label"] = "Raze"
	var bounty: int = d["bounty"] + 15 * skill("land_spoils")
	cut["price"] = "%d mana  +%dg" % [cut_cost(s), bounty]
	var txt: String = d["text"] % ([int(d["sooner"]), bounty] if s.kind == "beacon" else [float(d["r"]), bounty] if s.kind == "chapel" else bounty)
	return {"title": d["name"], "text": txt + more, "actions": [cut]}


## Range (in tiles) to preview when a tile is selected, or 0.
func preview_range(c: Vector2i) -> float:
	if towers.has(c):
		return (towers[c] as Tower).stat("range")
	if sites.has(c):   # what a building reaches: an Altar's blessing, a Chapel's healing
		var s: Site = sites[c]
		if s.kind == "altar":
			return float(Defs.SITES["altar"]["range"])
		if s.kind == "chapel" and not s.owned:
			return float(Defs.SITES["chapel"]["r"])
		return 0.0
	if level.is_lair(c):   # the den's bolts
		return float(Defs.DEN["range"])
	if level.road.has(c) or level.is_lair(c) or trees.has(c) or sites.has(c) or not is_lit(c) or level.is_water(c):
		return 0.0
	var t := level.terrain_at(c)
	var holy := Defs.HALLOW_RANGE if hallow_on() and level.hallowed.has(c) else 1.0
	if level.high.has(c):
		var best := 0.0   # any tower fits: show the longest reach
		for type: String in Defs.TOWERS:
			best = maxf(best, float(Defs.TOWERS[type]["range"][0]) + _range_bonus(type, c))
		return best * holy
	return (float(Defs.TOWERS[t]["range"][0]) + _range_bonus(t, c)) * holy


## Where the previewed range is measured from (in tiles): the tile's middle, or the den's for the lair.
func preview_center(c: Vector2i) -> Vector2:
	return level.lair_center if level.is_lair(c) else Vector2(c) + Vector2(0.5, 0.5)


## Extra range from the skill tree and, on a raised tile, from the height.
func _range_bonus(type: String, c: Vector2i) -> float:
	var r := 0.2 * skill(type + "_range")
	if level.high.has(c):
		r += float(Defs.TOWERS[type]["high_range"]) + Defs.HEIGHTS_RANGE * skill("land_heights")
	return r


## The level IV masteries this tower may take now: it is level III with its ability learned, and
## each mastery must be unlocked in Dark Arts.
func masteries_for(tw: Tower) -> Array:
	if tw.lvl != 3 or not tw.has_ability():
		return []
	return Defs.MASTERIES[tw.type].filter(func(m: Dictionary) -> bool: return skill("mastery_" + m["id"]) > 0)


static func mastery_def(type: String, id: String) -> Dictionary:
	for m: Dictionary in Defs.MASTERIES[type]:
		if m["id"] == id:
			return m
	return {"id": id, "name": id, "text": ""}


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
		tw.dmg_mul = 1.0 + 0.1 * skill(type + "_dmg") + Defs.LEGEND_DMG * skill(type + "_legend") + Defs.DRILL_DMG * skill(type + "_drill")
		if level.high.has(c):   # Commanding Heights
			tw.dmg_mul += Defs.HEIGHTS_DMG * skill("land_heights")
		tw.rate_mul = 1.0 + 0.08 * skill(type + "_rate")
		tw.range_add = _range_bonus(type, c)
		tw.xp_mul = 1.0 + 0.25 * skill(type + "_vet")
		tw.ability_rank = skill(type + "_ability")
		towers[c] = tw
		tw.born = time
		burst.emit("build", tw.pos, tw.type)
		built[type] = true
		towers_built += 1
		built_count[type] = int(built_count.get(type, 0)) + 1
		gold_spent += cost
		if level.high.has(c):
			high_built += 1
		if level.hallowed.has(c):
			built_hallowed += 1
		most_towers = maxi(most_towers, towers.size())
		_relight()
		sound.emit("build")
		return ""
	match id:
		"clear":
			if not trees.has(c):
				return "No woods here"
			if mana < woods_cost():
				return "Not enough mana"
			mana -= woods_cost()
			woods_cut += 1
			gold += Defs.CLEAR_GOLD
			trees.erase(c)
			_text(Vector2(c) + Vector2(0.5, 0.3), "+%d" % Defs.CLEAR_GOLD, Color("e8b84a"))
			trees_changed.emit()
			sound.emit("chop")
		"cut":
			if not sites.has(c) or (sites[c] as Site).owned:
				return "Nothing to cut"
			var s: Site = sites[c]
			var d: Dictionary = Defs.SITES[s.kind]
			if mana < cut_cost(s):
				return "Not enough mana"
			mana -= cut_cost(s)
			s.cuts_left -= 1
			if s.cuts_left > 0:
				sound.emit("chop")
				_text(s.pos + Vector2(0, -0.4), "%d more" % s.cuts_left, Color("c9c0ff"))
				if Defs.MUSTER_SITES.has(s.kind):   # a damaged barracks musters more slowly
					s.every *= 1.3
					s.t = maxf(s.t, s.every * 0.5)
				return ""
			s.owned = true
			s.t = 0.0
			sound.emit("raze")
			if Defs.HERO_SITES.has(s.kind):
				var bounty: int = d["bounty"] + 15 * skill("land_spoils")
				gold += bounty
				_boom(s.pos, 0.9, 0.5)
				_text(s.pos + Vector2(0, -0.4), "+%d" % bounty, Color("e8b84a"))
				toast.emit("%s razed" % d["name"])
				if s.kind == "chapel" and not hallow_on() and not level.hallowed.is_empty():
					chapels_razed_wave = wave
					toast.emit("The ground is no longer holy")
				_cover.clear()
			else:
				toast.emit("%s is yours" % d["name"])
				_relight()
		"collapse":
			var i: int = level.crossings.get(c, -1)
			if i < 0 or level.crossing_kind[i] != "bridge" or collapsed.has(c):
				return "Nothing to collapse"
			if mana < collapse_cost(i):
				return "Not enough mana"
			mana -= collapse_cost(i)
			collapse_bridge(i)
			toast.emit("The bridge falls")
		"flood":
			if not sites.has(c) or (sites[c] as Site).kind != "sluice":
				return "No sluice here"
			var s: Site = sites[c]
			if s.t > 0.0:
				return "Still refilling"
			if sluice_targets(s) == 0:
				return "No boat on the river"
			if mana < Defs.SITES["sluice"]["mana"]:
				return "Not enough mana"
			mana -= Defs.SITES["sluice"]["mana"]
			_flood(s)
		"rubble":
			if not towers.has(c) or (towers[c] as Tower).rubble <= 0.0:
				return "No rubble here"
			if gold < Defs.RUBBLE_CLEAR:
				return "Not enough gold"
			gold -= Defs.RUBBLE_CLEAR
			(towers[c] as Tower).rubble = 0.0
			rubble_cleared += 1
			sound.emit("chop")
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
			upgrades += 1
			gold_spent += cost
			tw.lvl += 1
			tw.born = time
			burst.emit("build", tw.pos, tw.type)
			_cover.clear()   # range grew
			sound.emit("upgrade")
			if tw.has_ability() and tw.lvl == Defs.ABILITY_LEVEL:
				_text(tw.pos + Vector2(0, -0.9), Defs.ABILITIES[tw.type]["name"] + "!", Color("c9c0ff"))
				abilities += 1
				learned[tw.type] = true
		_ when id.begins_with("master:"):
			if not towers.has(c):
				return "No tower here"
			var tw: Tower = towers[c]
			var m := id.get_slice(":", 1)
			if not masteries_for(tw).any(func(x: Dictionary) -> bool: return x["id"] == m):
				return "Not possible yet"
			var cost: int = Defs.TOWERS[tw.type]["cost"][3]
			if gold < cost:
				return "Not enough gold"
			gold -= cost
			tw.spent += cost
			upgrades += 1
			gold_spent += cost
			tw.lvl = 4
			tw.mastery = m
			masteries_built[m] = int(masteries_built.get(m, 0)) + 1
			tw.born = time
			burst.emit("build", tw.pos, tw.type)
			_cover.clear()
			_relight()
			sound.emit("upgrade")
			_text(tw.pos + Vector2(0, -0.9), mastery_def(tw.type, m)["name"] + "!", Color("ffd86a"))
		"aim":
			if not towers.has(c):
				return "No tower here"
			var tw: Tower = towers[c]
			tw.aim = AIMS[(AIMS.find(tw.aim) + 1) % AIMS.size()]
		"sell":
			if not towers.has(c):
				return "No tower here"
			var tw: Tower = towers[c]
			gold += int(tw.spent * Defs.SELL_REFUND)
			sold += 1
			towers.erase(c)
			_relight()
			sound.emit("sell")
		_:
			return "Unknown action"
	return ""


# ---------------------------------------------------------------- scoring

## Online race: the hero kinds that can be bought for the rival (those in this lair's waves, except those marked no_send:
## bosses, boats), cheapest first.
func race_shop() -> Array[String]:
	var kinds: Array[String] = []
	for w: Array in level.waves:
		for code: String in w:
			if not Defs.ENEMIES[code].get("no_send", false) and not kinds.has(code):
				kinds.append(code)
	kinds.sort_custom(func(a: String, b: String) -> bool: return race_cost(a) < race_cost(b))
	return kinds


static func race_cost(code: String) -> int:
	return int(Defs.ENEMIES[code]["gold"]) * Defs.RACE_SEND_COST


## Online race: pays gold to send one hero to the rival. Returns an error, or "".
func race_buy(code: String) -> String:
	if over:
		return "The battle is over"
	if gold < race_cost(code):
		return "Not enough gold"
	gold -= race_cost(code)
	race_sends += code
	sound.emit("horn")
	return ""


## Online race: the rival finished or fell first, so this battle ends where it stands.
func race_stop() -> void:
	if over:
		return
	stopped = true
	_end(false)


## Online race: a hero the rival sent marches in from the start of a road.
func race_receive(code: String) -> void:
	if not over and Defs.ENEMIES.has(code):
		_spawn(code)


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


## Leaderboard points for a won battle (0 for a loss): up to 1000 for gems kept, 500 for Wicked or
## 1000 for Brilliant, 5 per second of countdown skipped by calling waves early and 1 per gold
## left; then +10% for each lair further along the campaign (number counts from 1) and ×1.5 at night.
func score(number: int) -> int:
	if not won:
		return 0
	var pts := 1000.0 * (level.gems - lost) / level.gems
	pts += [0, 0, 500, 1000][SaveData.RANKS.find(rank())]
	pts += 5.0 * skipped + gold
	pts *= 1.0 + 0.1 * (number - 1)
	if level.night:
		pts *= 1.5
	return roundi(pts)


## The best rating still within reach if the battle is won from here (shown during the battle).
func rating_now() -> String:
	if lost > 0:
		return "Survived"
	if touched:
		return "Wicked"
	return "Brilliant"


## Can this battle go dark: a night mission, or a lair with Dusk or an Eclipse.
func can_dark() -> bool:
	return level.night or dusk_wave > 0 or eclipse.x > 0.0


## How dark the view should be (0 day .. 1 night), fading over DUSK_FADE when darkness comes or goes.
func dark_k() -> float:
	var k := clampf((time - dark_t) / Defs.DUSK_FADE, 0.0, 1.0)
	return k if dark else 1.0 - k


## Is e in the air: a flyer that has not come down onto a road.
func flying(e: Enemy) -> bool:
	return e.d.has("fly") and not e.grounded


## Does e stand apart from the support heroes: boats and siege engines (steady) and flyers still in
## the air get no haste from a Herald, no heal from a Cleric, no guard from a Shieldbearer and no
## ward from a Warden.
func aloof(e: Enemy) -> bool:
	return e.d.has("steady") or flying(e)


## A Spiriter finished his chant: he vanishes with the gems he holds (they are lost).
func _vanish(e: Enemy) -> void:
	e.gone = true
	chants_done += 1
	if e.carry > 0:
		lost += e.carry
		toast.emit("%s vanished with %s" % [e.d["name"], "a gem" if e.carry == 1 else "%d gems" % e.carry])
		sound.emit("lost")
	_fx("surge", e.pos, 0.8, 0.8)


## Hallowed ground is holy while a Chapel stands (on a lair with hallowed tiles but no Chapel, always).
func hallow_on() -> bool:
	if level.hallowed.is_empty():
		return false
	var any := false
	for s: Site in sites.values():
		if s.kind == "chapel":
			any = true
			if not s.owned:
				return true
	return not any


## The nearest land road to pos: [road index, distance along it].
func _nearest_land(pos: Vector2) -> Array:
	var best := [level.land_roads[0], 0.0]
	var bd := INF
	for r: int in level.land_roads:
		var t := level.nearest_dist(r, pos)
		var dd := level.path_pos(r, t).distance_to(pos)
		if dd < bd:
			bd = dd
			best = [r, t]
	return best


## The Seraph comes down: onto the nearest road (she walks from now on), untouchable for a while,
## and the last heroes slain rise around her at half health (no bosses, boats or engines).
func _seraph_land(e: Enemy) -> void:
	var sd: Dictionary = Defs.SERAPH
	var n: int = sd["raise"][mini(e.phase, sd["raise"].size() - 1)]
	e.phase += 1
	e.untouch = sd["dur"]
	if level.path_kind[e.path] == "air":
		var near := _nearest_land(e.pos)
		e.path = near[0]
		e.dist = near[1]
		e.pos = level.path_pos(e.path, e.dist)
	e.grounded = true
	var codes: Array[String] = []
	while codes.size() < n and not fallen.is_empty():
		codes.append(fallen.pop_back())
	if not codes.is_empty():
		_rally.append({"codes": codes, "path": e.path, "dist": e.dist, "wave": e.wave, "half": true})
	_fx("surge", e.pos, 2.0, 1.0)
	_text(e.pos + Vector2(0, -1.2), "Rise!", Color("fff2c0"))
	sound.emit("horn")


## Can any tower reach pos.
func _covered_by_towers(pos: Vector2) -> bool:
	for tw: Tower in towers.values():
		if tw.pos.distance_to(pos) <= tw.stat("range"):
			return true
	return false
