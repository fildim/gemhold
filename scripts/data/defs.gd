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
		"cost": [50, 75, 100], "dmg": [7, 11, 17], "range": [2.3, 2.6, 2.9],
		"rate": [0.45, 0.4, 0.35], "kind": "arrow", "high_range": 0.8,
	},
	"frost": {
		"name": "Bone Crypt", "blurb": "Slow, heavy bolts that chill heroes to a crawl.",
		"cost": [50, 75, 100], "dmg": [16, 27, 50], "range": [2.2, 2.5, 2.8],
		"rate": [1.5, 1.4, 1.3], "slow": [0.45, 0.55, 0.65], "kind": "frost", "high_range": 0.5,
	},
	"ash": {
		"name": "Cinder Shrine", "blurb": "A searing beam that melts armour and grows hotter on one hero.",
		"cost": [50, 75, 100], "dmg": [6, 9, 14], "range": [2.0, 2.3, 2.6], "kind": "beam", "high_range": 0.6,
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
## special: towers shoot these support heroes before ordinary ones (gem carriers still come first).
const ENEMIES := {
	"p": {"name": "Peasant", "hp": 32, "spd": 1.05, "gold": 4, "r": 0.2, "armor": 0, "cap": 1},
	"f": {"name": "Footman", "hp": 75, "spd": 0.85, "gold": 7, "r": 0.24, "armor": 2, "cap": 1},
	"s": {"name": "Scout", "hp": 40, "spd": 1.7, "gold": 6, "r": 0.19, "armor": 0, "cap": 1},
	"c": {"name": "Cleric", "hp": 60, "spd": 0.85, "gold": 9, "r": 0.22, "armor": 0, "cap": 1, "heal": 7.0, "special": true},
	"k": {"name": "Knight", "hp": 340, "spd": 0.65, "gold": 30, "r": 0.31, "armor": 4, "cap": 2},
	"b": {"name": "Shieldbearer", "hp": 130, "spd": 0.72, "gold": 12, "r": 0.27, "armor": 3, "cap": 1, "guard": 0.35, "special": true},
	"t": {"name": "Cutpurse", "hp": 48, "spd": 1.5, "gold": 10, "r": 0.19, "armor": 0, "cap": 2},
	"w": {"name": "Warden", "hp": 95, "spd": 0.9, "gold": 12, "r": 0.23, "armor": 1, "cap": 1, "ward": 1.4, "special": true},
}

const GUARD_RANGE := 1.2
const TOWER_COST_STEP := 15
const SELL_REFUND := 0.6
const CLEAR_MANA := 15
const CLEAR_GOLD := 15
const MANA_MAX := 100.0
const MANA_REGEN := 1.2      # per second
const MANA_PER_KILL := 3.0
const SPAWN_INTERVAL := 0.85
const WAVE_HP_SCALE := 0.12  # +12% hero health per wave
const DROP_SPEED := 0.7      # dropped gems roll home along the road at this many tiles/s

## The den (your lair) strikes heroes near it. It holds charges: each is one bolt, and spent
## charges refill one at a time. Every point in the Den skill adds one more charge.
## The Hoard skills: each point adds this much starting gold or maximum mana.
const HOARD_GOLD := 50
const HOARD_MANA := 15

const DEN := {"charges": 1, "range": 2.6, "dmg": 70, "refill": 8.0, "rate": 0.5}

const METEOR := {"cost": 60, "radius": 1.3, "dmg": 140, "delay": 0.55}

## Tower veterancy: towers earn 1 XP per point of damage dealt and rank up at these totals.
## Each rank adds damage; rank ABILITY_RANK unlocks the tower's ability.
const TOWER_XP_RANKS := [150, 500, 1200]
const RANK_DMG := 0.08
const ABILITY_RANK := 2
const ABILITIES := {
	"moss": {"name": "Volley", "text": "A second arrow hits another hero in range.", "base": 0.5, "per_rank": 0.2},
	"frost": {"name": "Dread", "text": "Hits may terrify a hero: it backs away, or freezes if carrying a gem.", "base": 0.12, "per_rank": 0.06, "dur": 1.6},
	"ash": {"name": "Lava", "text": "The beam leaves burning ground under its target.", "base": 0.3, "per_rank": 0.15, "dur": 3.0, "r": 0.7, "every": 1.0},
}

## Map buildings. Cutting (a mana action) frees mines and wells for you, or razes a hero barracks.
const SITES := {
	"mine": {"name": "Gold Mine", "cut": 30, "gold": 5, "every": 6.0, "light": 1.6,
		"text": "Overgrown. Cut it free to earn %d gold every %d s."},
	"well": {"name": "Mana Well", "cut": 25, "regen": 0.6, "light": 1.6,
		"text": "Choked with roots. Cut it free for +%.1f mana per second."},
	"camp": {"name": "Hero Barracks", "cut": 50, "bounty": 40,
		"text": "Sends extra heroes onto the road while waves are coming. Raze it for %d gold."},
}

## Loot dropped by slain heroes. It stays where it fell until you tap it.
const LOOT_COIN_CHANCE := 0.35
const LOOT_POTION_CHANCE := 0.15
const LOOT_POTION_MANA := 15
const LOOT_COIN_MUL := 1.5    # a coin is worth this times the hero's bounty, scaled by its toughness,
const LOOT_COIN_BONUS := 5    # plus this flat amount, so even small heroes drop a worthwhile coin

## Night levels: you can only build on lit tiles. Radii in tiles.
## Night missions unlock when a level is cleared Brilliant.
const LIGHT := {"lair": 2.3, "tower": 1.7}


## Skill trees, one per tower type. Effects are applied in GameSim.
## Skill points are stars: each mission's best rating gives 1 (Survived), 2 (Wicked) or 3 (Brilliant).
const SKILLS := {
	"moss": [
		{"id": "moss_dmg", "name": "Barbed Arrows", "text": "+10% damage", "max": 3},
		{"id": "moss_rate", "name": "Quick Draw", "text": "+8% attack speed", "max": 3},
		{"id": "moss_range", "name": "Lookout Posts", "text": "+0.2 range", "max": 2},
		{"id": "moss_vet", "name": "Blooded", "text": "Towers rank up 25% faster", "max": 2},
		{"id": "moss_ability", "name": "Volley", "text": "Second arrow +20% damage", "max": 3},
	],
	"frost": [
		{"id": "frost_dmg", "name": "Grave Chill", "text": "+10% damage", "max": 3},
		{"id": "frost_rate", "name": "Restless Dead", "text": "+8% attack speed", "max": 3},
		{"id": "frost_range", "name": "Long Shadows", "text": "+0.2 range", "max": 2},
		{"id": "frost_vet", "name": "Old Bones", "text": "Towers rank up 25% faster", "max": 2},
		{"id": "frost_ability", "name": "Dread", "text": "+6% chance to terrify", "max": 3},
	],
	"ash": [
		{"id": "ash_dmg", "name": "Hotter Coals", "text": "+10% damage", "max": 3},
		{"id": "ash_rate", "name": "Bellows", "text": "Beam heats 8% faster", "max": 3},
		{"id": "ash_range", "name": "High Flames", "text": "+0.2 range", "max": 2},
		{"id": "ash_vet", "name": "Tempered", "text": "Towers rank up 25% faster", "max": 2},
		{"id": "ash_ability", "name": "Lava", "text": "Burning ground +15% damage", "max": 3},
	],
	"den": [
		{"id": "den_charge", "name": "Hoard's Wrath", "text": "+1 den charge", "max": 5},
		{"id": "hoard_gold", "name": "Buried Gold", "text": "+50 starting gold", "max": 5},
		{"id": "hoard_mana", "name": "Deep Well", "text": "+15 max mana", "max": 4},
	],
}
