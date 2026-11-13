class_name Defs
extends RefCounted
## Game data shared by every level. Tune balance here.
## Towers: one per terrain. Each array holds values for levels I, II and III.
## Costs are the first build, then the upgrades to level II and III. Each more tower of
## the same type standing on the map costs TOWER_COST_STEP more to build.
## Three ways to attack, none stronger overall: the Hut is quick but armour blunts its small
## arrows, the Crypt hits rarely but slows hard, and the Shrine's beam ignores armour and
## heats up the longer it holds one hero. For the beam, dmg is per second.
## high_range: extra range when built on a raised tile (a capital letter in the level grid).
## Raised tiles take any of the three towers, whatever ground they are.

const TOWERS := {
	"moss": {
		"name": "Warband Hut", "blurb": "Rapid arrows at one foe. Armour blunts them.",
		"cost": [50, 75, 100, 150], "dmg": [7, 11, 17, 22], "range": [2.3, 2.6, 2.9, 3.0],
		"rate": [0.45, 0.4, 0.35, 0.33], "kind": "arrow", "high_range": 0.8,
	},
	"frost": {
		"name": "Bone Crypt", "blurb": "Slow, heavy bolts that chill heroes to a crawl.",
		"cost": [50, 75, 100, 150], "dmg": [16, 27, 50, 66], "range": [2.2, 2.5, 2.8, 2.9],
		"rate": [1.5, 1.4, 1.3, 1.25], "slow": [0.45, 0.55, 0.65, 0.7], "kind": "frost", "high_range": 0.5,
	},
	"ash": {
		"name": "Cinder Shrine", "blurb": "A searing beam that melts armour and grows hotter on one hero.",
		"cost": [50, 75, 100, 150], "dmg": [6, 9, 14, 18], "range": [2.0, 2.3, 2.6, 2.7], "kind": "beam", "high_range": 0.6,
	},
}

## Cinder Shrine beam: heat rises from 0 to 1 over HEAT_TIME seconds on the same hero, scaling
## damage up to HEAT_MAX times. Switching to a new hero keeps HEAT_KEEP of the heat; with no
## target it cools at the same rate it heats.
const HEAT_TIME := 2.0
const HEAT_MAX := 5.0
const HEAT_KEEP := 0.0
const SLOW_TIME := 2.5

## Heroes. Letter codes are used in each level's wave list ("6p,2f" = 6 peasants, 2 footmen).
## spd is in tiles per second, r is body radius in tiles, cap is how many gems they can carry.
## guard: other heroes within GUARD_RANGE take this much less damage (Shieldbearer).
## ward: clears slow and Dread from heroes within this many tiles, itself included (Warden).
## haste: heroes within HASTE_RANGE (itself included) walk this much faster (Herald).
## rage: below half health it walks this many times faster (Berserker).
## rally: heroes that rise where it falls and march on with its wave (Champion).
## special: towers shoot these support heroes before ordinary ones (gem carriers still come first).
## no_send: online races never offer it in the Send shop; send_as: the hero its kills send to the rival instead.
## fly: walks an air road (Level adds one if the lair has none).
const ENEMIES := {
	"p": {"name": "Peasant", "hp": 32, "spd": 1.05, "gold": 4, "r": 0.2, "armor": 0, "cap": 1},
	"f": {"name": "Footman", "hp": 75, "spd": 0.85, "gold": 7, "r": 0.24, "armor": 2, "cap": 1},
	"s": {"name": "Scout", "hp": 40, "spd": 1.7, "gold": 6, "r": 0.19, "armor": 0, "cap": 1},
	"c": {"name": "Cleric", "hp": 60, "spd": 0.85, "gold": 9, "r": 0.22, "armor": 0, "cap": 1, "heal": 7.0, "special": true},
	"k": {"name": "Knight", "hp": 340, "spd": 0.65, "gold": 30, "r": 0.31, "armor": 4, "cap": 2},
	"b": {"name": "Shieldbearer", "hp": 130, "spd": 0.72, "gold": 12, "r": 0.27, "armor": 3, "cap": 1, "guard": 0.35, "special": true},
	"t": {"name": "Cutpurse", "hp": 48, "spd": 1.5, "gold": 10, "r": 0.19, "armor": 0, "cap": 2},
	"w": {"name": "Warden", "hp": 95, "spd": 0.9, "gold": 12, "r": 0.23, "armor": 1, "cap": 1, "ward": 1.4, "special": true},
	"h": {"name": "Herald", "hp": 110, "spd": 0.85, "gold": 12, "r": 0.23, "armor": 1, "cap": 1, "haste": 0.35, "special": true},
	"r": {"name": "Berserker", "hp": 180, "spd": 0.72, "gold": 14, "r": 0.26, "armor": 0, "cap": 1, "rage": 2.1},
	"x": {"name": "Champion", "hp": 1500, "spd": 0.5, "gold": 80, "r": 0.38, "armor": 6, "cap": 3, "rally": "3f", "no_send": true, "send_as": "k"},
	# Chapter III: the Drowned Marches
	"m": {"name": "Fenwalker", "hp": 70, "spd": 1.15, "gold": 8, "r": 0.21, "armor": 0, "cap": 1, "wader": true},
	"e": {"name": "Engineer", "hp": 110, "spd": 0.85, "gold": 14, "r": 0.23, "armor": 1, "cap": 1, "engineer": true, "special": true},
	"q": {"name": "Rainbringer", "hp": 100, "spd": 0.8, "gold": 14, "r": 0.22, "armor": 0, "cap": 1, "rain": 0.75, "special": true},
	"l": {"name": "Longboat", "hp": 520, "spd": 1.25, "gold": 20, "r": 0.36, "armor": 2, "cap": 0, "boat": true, "crew": "4f", "steady": true, "no_send": true},
	"d": {"name": "Diver", "hp": 60, "spd": 1.0, "gold": 10, "r": 0.2, "armor": 0, "cap": 1, "diver": true},
	"T": {"name": "the Tidecaller", "hp": 2400, "spd": 0.5, "gold": 150, "r": 0.4, "armor": 2, "cap": 3, "rain": 1.0, "surge": true, "rally": "3m,2d", "boss": true, "no_send": true, "send_as": "k"},
}

## Shown the first time each hero walks onto the map (see main.gd).
const HERO_TIPS := {
	"p": "Weak and slow, but comes in crowds. Huts mow them down.",
	"f": "Sturdier, with a little armour that blunts Hut arrows.",
	"s": "Fast and fragile. He can reach the cave before your towers notice. Slow him with a Crypt.",
	"c": "Heals the heroes around him as he walks. Towers aim for him first; make sure something reaches him early.",
	"k": "Huge health and heavy armour, and carries [b]2 gems[/b]. Shrine beams melt through armour; Hut arrows barely scratch him.",
	"b": "His shield makes heroes near him take much less damage. Kill him first and the rest fall faster.",
	"t": "Fast, fragile, and carries [b]2 gems[/b]. Crypts and the den's bolts are your best answer.",
	"w": "His lantern clears slow and Dread from every hero near him. Crypts do little until he falls.",
	"h": "His horn makes nearby heroes walk faster. Towers aim for him first.",
	"r": "Below half health he runs twice as fast. Hit him early, or hard enough to finish him in one stretch.",
	"x": "A towering hero with thick armour who carries [b]3 gems[/b]. Where he falls, Footmen rise and march on.",
	"m": "Wades through water as if it were dry land: fords and broken bridges don't slow him. Kill him on dry ground.",
	"e": "Repairs broken bridges (he stands at the bank for a moment) and lays planks over fords so heroes cross dry. Towers aim for him first.",
	"q": "Carries a rain cloud: Shrine beams on heroes under it never get hot, and it puts out Lava. Arrows and bolts work fine.",
	"l": "A boat full of heroes on the river. Chill and Dread don't touch it. Sink it before it lands and its crew drowns; let it land and they march on.",
	"d": "Swims under the water: towers and the den can't see him while he is in a ford or a flooded crossing. Meteors still hit him.",
	"T": "The Tidecaller, a boss. Her surge washes chill and Dread off the heroes around her and lets them wade freely. Where she falls, Fenwalkers and Divers rise.",
}

const GUARD_RANGE := 1.2
const HASTE_RANGE := 1.5
const TOWER_COST_STEP := 15
const SELL_REFUND := 0.6
const CLEAR_MANA := 15
const CLEAR_GOLD := 15
const MANA_MAX := 100.0
const MANA_REGEN := 1.0      # per second, plus HOARD_REGEN per Mana Spring point
const SPAWN_INTERVAL := 0.85
const WAVE_HP_SCALE := 0.13  # +13% hero health per wave

## Dynamic difficulty (GameSim._judge_wave). After each wave the threat, which multiplies hero
## health, rises by how deep into the defence that wave got: the most of its road's defended
## stretch (where towers or the den can reach) any of its heroes walked through, from 0 to 1.
## It never falls. Under `easy`: up by up_easy..up_max (the earlier they fell, the more).
## Up to `hard`: up_mid. Past `hard`: up_close. A hero reaching the hoard or a dropped gem: up_touched.
## Riches draw heroes too: gold left unspent above `rich` adds per_gold threat per coin, up to
## rich_max a wave, so hoarding gold is never the safe choice.
## Within a wave too: while none of its heroes has got past `easy`, each one slain adds up_kill
## at once (up to kill_max a wave), so the rest of that wave and the next already come tougher.
const THREAT := {"easy": 0.45, "hard": 0.7, "up_max": 0.4, "up_easy": 0.1, "up_mid": 0.06,
	"up_kill": 0.006, "kill_max": 0.1,
	"up_close": 0.03, "up_touched": 0.01, "max": 4.0,
	"rich": 250, "per_gold": 0.0005, "rich_max": 0.25}
const DROP_SPEED := 0.7      # dropped gems roll home along the road at this many tiles/s

## Road zones (Level.zones, GameSim._zone_mul): hero speed factors. A ford is road over shallows;
## swimming is a flooded ford or a collapsed bridge; paving is laid by a Pavior.
const ZONE_SPEED := {"ford": 0.7, "swim": 0.4, "paved": 1.25}
## Soaked: in a ford or swimming, and SOAK_TIME seconds after. Crypt chill lasts SOAK_CHILL times
## longer on a soaked hero; a Shrine heats up at SOAK_HEAT of its speed.
const SOAK_TIME := 4.0
const SOAK_CHILL := 1.5
const SOAK_HEAT := 0.6

## The den (your lair) strikes heroes near it. It holds charges: each is one bolt, and spent
## charges refill one at a time. Every point in the Den skill adds one more charge.
## The Hoard skills: each point adds this much starting gold or maximum mana (Starfall: see METEOR).
const HOARD_GOLD := 50
const HOARD_MANA := 15
const HOARD_REGEN := 0.15   # Mana Spring: +0.15 mana per second per point

const DEN := {"charges": 1, "range": 2.6, "dmg": 70, "refill": 8.0, "rate": 0.5}

const METEOR := {"cost": 50, "radius": 1.3, "dmg": 650, "delay": 0.55}   # dmg: half of lair 3's last-wave Knight
const HOARD_METEOR := 0.25   # Starfall (The Hoard): +25% meteor damage per point

## Tower veterancy: towers earn 1 XP per point of damage dealt and rank up at these totals.
## Each rank adds damage. A tower at rank ABILITY_RANK and upgrade level ABILITY_LEVEL unlocks its ability.
const TOWER_XP_RANKS := [240, 800, 1900]
const RANK_DMG := 0.08
const ABILITY_RANK := 3
const ABILITY_LEVEL := 3
const ABILITIES := {
	"moss": {"name": "Volley", "text": "A second arrow hits another hero in range.", "base": 0.5, "per_rank": 0.2},
	"frost": {"name": "Dread", "text": "Hits may terrify a hero: it backs away, or freezes if carrying a gem.", "base": 0.12, "per_rank": 0.06, "dur": 1.6},
	"ash": {"name": "Lava", "text": "Heroes it kills may leave a pool of burning ground.", "base": 0.3, "per_rank": 0.15, "dur": 3.0, "r": 0.7, "chance": 0.35},
}

## Map buildings. Cutting (a mana action) frees mines and wells for you, or razes a hero barracks.
const SITES := {
	"mine": {"name": "Gold Mine", "cut": 30, "gold": 5, "every": 6.0, "light": 1.6,
		"text": "Overgrown. Cut it free to earn %d gold every %d s."},
	"well": {"name": "Mana Well", "cut": 25, "regen": 0.6, "light": 1.6,
		"text": "Choked with roots. Cut it free for +%.1f mana per second."},
	"camp": {"name": "Hero Barracks", "cut": 50, "bounty": 40,
		"text": "Sends extra heroes onto the road while waves are coming. Raze it for %d gold."},
	"altar": {"name": "Dark Altar", "cut": 30, "range": 2.2, "dmg": 0.1, "xp": 0.2, "light": 1.6,
		"text": "Overgrown. Cut it free: towers within %.1f tiles deal %d%% more damage and rank up faster."},
	"sluice": {"name": "Sluice Gate", "cut": 0, "mana": 35, "recharge": 45.0, "push": 2.0, "dmg": 120, "boat_mul": 3.0, "light": 1.6,
		"text": "Open it to send a flood surge down its road: heroes in the water are swept back and take %d damage, boats triple."},
}

## Loot dropped by slain heroes. It stays where it fell until you tap it.
const LOOT_COIN_CHANCE := 0.32
const LOOT_POTION_CHANCE := 0.15
const LOOT_POTION_MANA := 15

## Online races (see main.gd): every RACE_KILL_SEND heroes you slay sends one like the last onto your
## rival's road (a Champion sends a Knight); Send buys more for RACE_SEND_COST × the hero's bounty.
## Between two survivors, finishing sooner is worth RACE_TIME_BONUS points per second.
const RACE_KILL_SEND := 10
const RACE_SEND_COST := 5
const RACE_TIME_BONUS := 20
const LOOT_COIN_MUL := 1.4    # a coin is worth this times the hero's bounty, grown by wave (not threat),
const LOOT_COIN_BONUS := 4    # plus this flat amount, so even small heroes drop a worthwhile coin

## Night levels: you can only build on lit tiles. Radii in tiles.
## Night missions unlock when a level is cleared Brilliant.
const LIGHT := {"lair": 2.3, "tower": 1.7}
## Darkness is the night mission's challenge, so its heroes are this much less tough than by day.
const NIGHT_HP := 0.85


## Skill trees, one per tower type, plus The Hoard (and The Land). Effects are applied in GameSim.
## Skill points are stars: each mission's best rating gives 1 (Survived), 2 (Wicked) or 3 (Brilliant).
## A skill may set "tier" (default 1). Tiers open with the campaign: once the player has beaten
## this many lairs (TIER_BEATEN), so tier II comes with Chapter III and tier III with Chapter V; a
## whole tree may wait for a chapter too (TREE_BEATEN: The Land with Chapter II). Beaten lairs stay
## beaten, so a refund never locks anything.
const TIER_BEATEN := {1: 0, 2: 20, 3: 40}
const TREE_BEATEN := {"land": 10}
const LAIRS_PER_CHAPTER := 10
## Skills that only add score and are not counted as "learning every Dark Art".
const SCORE_ONLY_SKILLS := ["renown"]
## Tree ids in the order the Dark Arts tabs show them.
const SKILL_TREES := ["moss", "frost", "ash", "den", "land"]
const SKILLS := {
	"moss": [
		{"id": "moss_dmg", "name": "Barbed Arrows", "text": "+10% damage", "max": 3},
		{"id": "moss_rate", "name": "Quick Draw", "text": "+8% attack speed", "max": 3},
		{"id": "moss_range", "name": "Lookout Posts", "text": "+0.2 range", "max": 2},
		{"id": "moss_vet", "name": "Blooded", "text": "Towers rank up 25% faster", "max": 2},
		{"id": "moss_ability", "name": "Volley", "text": "Second arrow +20% damage", "max": 3},
		{"id": "moss_bodkin", "name": "Bodkin Points", "text": "Arrows ignore 1 armour", "max": 2, "tier": 2},
		{"id": "moss_keen", "name": "Keen Eyes", "text": "+10% damage to gem carriers", "max": 3, "tier": 2},
		{"id": "mastery_longhouse", "name": "Mastery: Longhouse", "text": "Huts can become Longhouses (level IV)", "max": 1, "tier": 2},
		{"id": "mastery_lodge", "name": "Mastery: Hunter's Lodge", "text": "Huts can become Hunter's Lodges (level IV)", "max": 1, "tier": 2},
	],
	"frost": [
		{"id": "frost_dmg", "name": "Grave Chill", "text": "+10% damage", "max": 3},
		{"id": "frost_rate", "name": "Restless Dead", "text": "+8% attack speed", "max": 3},
		{"id": "frost_range", "name": "Long Shadows", "text": "+0.2 range", "max": 2},
		{"id": "frost_vet", "name": "Old Bones", "text": "Towers rank up 25% faster", "max": 2},
		{"id": "frost_ability", "name": "Dread", "text": "+6% chance to terrify", "max": 3},
		{"id": "frost_freeze", "name": "Deep Freeze", "text": "Chill lasts 0.4 s longer", "max": 3, "tier": 2},
		{"id": "frost_cold", "name": "Grave Cold", "text": "+5% damage to chilled or soaked heroes", "max": 2, "tier": 2},
		{"id": "frost_dread", "name": "Lingering Dread", "text": "Dread lasts 0.3 s longer", "max": 2, "tier": 2},
		{"id": "mastery_ossuary", "name": "Mastery: Ossuary", "text": "Crypts can become Ossuaries (level IV)", "max": 1, "tier": 2},
		{"id": "mastery_mausoleum", "name": "Mastery: Mausoleum", "text": "Crypts can become Mausoleums (level IV)", "max": 1, "tier": 2},
	],
	"ash": [
		{"id": "ash_dmg", "name": "Hotter Coals", "text": "+10% damage", "max": 3},
		{"id": "ash_rate", "name": "Bellows", "text": "Beam heats 8% faster", "max": 3},
		{"id": "ash_range", "name": "High Flames", "text": "+0.2 range", "max": 2},
		{"id": "ash_vet", "name": "Tempered", "text": "Towers rank up 25% faster", "max": 2},
		{"id": "ash_ability", "name": "Lava", "text": "Burning ground +15% damage", "max": 3},
		{"id": "ash_memory", "name": "Ember Memory", "text": "Keep 10% heat when changing hero", "max": 3, "tier": 2},
		{"id": "ash_core", "name": "Molten Core", "text": "Top heat +0.4x", "max": 2, "tier": 2},
		{"id": "ash_cooling", "name": "Slow Cooling", "text": "Lava lasts 0.5 s longer", "max": 2, "tier": 2},
		{"id": "mastery_twin", "name": "Mastery: Twin Flame", "text": "Shrines can become Twin Flames (level IV)", "max": 1, "tier": 2},
		{"id": "mastery_sunlance", "name": "Mastery: Sunlance", "text": "Shrines can become Sunlances (level IV)", "max": 1, "tier": 2},
	],
	"den": [
		{"id": "den_charge", "name": "Hoard's Wrath", "text": "+1 den charge", "max": 5},
		{"id": "hoard_gold", "name": "Buried Gold", "text": "+50 starting gold", "max": 5},
		{"id": "hoard_mana", "name": "Deep Well", "text": "+15 max mana", "max": 4},
		{"id": "hoard_regen", "name": "Mana Spring", "text": "+0.15 mana per second", "max": 3},
		{"id": "meteor_dmg", "name": "Starfall", "text": "+25% meteor damage", "max": 3},
		{"id": "spell_nightmare", "name": "Nightmare", "text": "A spell: heroes flee back along the road", "max": 1, "tier": 2},
		{"id": "nightmare_dur", "name": "Night Terrors", "text": "Nightmare lasts 0.5 s longer", "max": 2, "tier": 2},
		{"id": "spell_frenzy", "name": "Frenzy", "text": "A spell: towers fire and heat faster", "max": 1, "tier": 2},
		{"id": "frenzy_dur", "name": "Bloodlust", "text": "Frenzy lasts 1 s longer", "max": 2, "tier": 2},
		{"id": "gem_magnet", "name": "Gem Magnet", "text": "Loose gems roll home 20% faster", "max": 3, "tier": 2},
		{"id": "sturdy", "name": "Sturdy Foundations", "text": "Stun, Rubble and Silence weigh 15% less", "max": 3, "tier": 2},
	],
	"land": [
		{"id": "land_veins", "name": "Rich Veins", "text": "Gold mines pay +1 gold", "max": 3},
		{"id": "land_springs", "name": "Deep Springs", "text": "Mana wells give +0.1 mana per second", "max": 3},
		{"id": "land_axes", "name": "Sharp Axes", "text": "Cuts cost 10% less mana", "max": 3},
		{"id": "land_heights", "name": "Commanding Heights", "text": "Raised tiles give +0.1 more range", "max": 2},
		{"id": "land_spoils", "name": "Spoils of War", "text": "Razing a barracks pays +15 gold", "max": 2},
		{"id": "land_lantern", "name": "Lantern Oil", "text": "Lights reach 0.3 tiles further at night", "max": 3},
		{"id": "land_flood", "name": "Floodmaster", "text": "Sluices recharge 20% faster; collapsing a bridge costs 5 mana less", "max": 2},
		{"id": "land_rites", "name": "Black Rites", "text": "Dark Altars give +5% more damage", "max": 2},
	],
}


## The skill entry with this id, its tree id under "tree", or {} if there is none.
static func skill_def(id: String) -> Dictionary:
	for tree: String in SKILLS:
		for sk: Dictionary in SKILLS[tree]:
			if sk["id"] == id:
				var out := sk.duplicate()
				out["tree"] = tree
				return out
	return {}


static func skill_tier(sk: Dictionary) -> int:
	return int(sk.get("tier", 1))


## Lairs a player must have beaten before this skill can be bought.
static func skill_gate(id: String) -> int:
	var sk := skill_def(id)
	if sk.is_empty():
		return 0
	return maxi(int(TIER_BEATEN.get(skill_tier(sk), 0)), int(TREE_BEATEN.get(sk["tree"], 0)))


## Every rank of every skill that does something in battle: what "learn every Dark Art" means.
static func skill_points_all() -> int:
	var n := 0
	for tree: String in SKILLS:
		for sk: Dictionary in SKILLS[tree]:
			if not SCORE_ONLY_SKILLS.has(sk["id"]):
				n += int(sk["max"])
	return n


## The chapter a gate of `beaten` lairs opens with: 20 lairs beaten = Chapter III reached.
static func gate_chapter(beaten: int) -> int:
	return beaten / LAIRS_PER_CHAPTER + 1


# ---------------------------------------------------------------- Chapter III: water

## Bridges (road over deep water) can be collapsed from their tile panel: heroes then swim the gap
## (ZONE_SPEED swim, Soaked). Each later collapse of the same bridge costs COLLAPSE_STEP more.
const COLLAPSE := {"mana": 40, "step": 20}
## Engineer: stands this long at the bank of a collapsed bridge, then it stands again; a ford he
## crosses alive gets planks (no slow, no soak) for PLANK_TIME seconds.
const ENGINEER_FIX := 4.0
const PLANK_TIME := 40.0
## Rainbringer's cloud: Shrine beams on heroes under it never heat past this, and Lava goes out.
const RAIN_HEAT := 0.35
## The Tidecaller's surge: every `every` seconds heroes within `r` lose chill and Dread and wade
## freely (like a Fenwalker) for `dur` seconds.
const SURGE := {"every": 12.0, "r": 2.5, "dur": 6.0}

## Level IV: a level III tower that has learned its ability can become one of two masteries,
## each first unlocked in Dark Arts ("mastery_<id>"). Costs TOWERS[type]["cost"][3].
const MASTERIES := {
	"moss": [
		{"id": "longhouse", "name": "Longhouse", "text": "Three arrows at a time, at up to three heroes."},
		{"id": "lodge", "name": "Hunter's Lodge", "text": "A heavy javelin that ignores armour and marks its hero: everything hits him harder."},
	],
	"frost": [
		{"id": "ossuary", "name": "Ossuary", "text": "Stores bolts while it waits, up to four, then looses them at different heroes."},
		{"id": "mausoleum", "name": "Mausoleum", "text": "Bolts burst, chilling and hurting every hero close by."},
	],
	"ash": [
		{"id": "twin", "name": "Twin Flame", "text": "Two beams on two heroes, each heating up on its own."},
		{"id": "sunlance", "name": "Sunlance", "text": "The beam burns through its hero and every hero behind him."},
	],
}
const LODGE := {"rate": 1.6, "dmg": 2.6, "mark": 4.0, "mark_dmg": 0.15}
const OSSUARY := {"charges": 4, "gap": 0.3}
const MAUSOLEUM := {"r": 0.9, "share": 0.5}
const TWIN_DMG := 0.65
const SUNLANCE := {"share": 0.5, "keep": 0.5}
## Plunder: a level IV Hut pays +1 gold on its first kill as level IV, +2 on the next, ... up to this.
const PLUNDER_MAX := 5

## Spells unlocked in Dark Arts. Nightmare: heroes in the circle flee back along the road (gem
## carriers freeze); bosses and boats ignore it. Frenzy: towers in the circle fire and heat faster.
const NIGHTMARE := {"cost": 40, "radius": 1.6, "dur": 3.0}
const FRENZY := {"cost": 35, "radius": 2.0, "dur": 6.0, "speed": 1.6}
