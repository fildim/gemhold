class_name Guide
extends RefCounted
## The player's guide, opened from the level map: one card per topic, grouped. Numbers come from
## Defs, so the guide stays right when the balance changes.


## [{"group", "name", "text" (BBCode)}], in the order the guide lists them.
static func topics() -> Array:
	var t := []
	var hut: Dictionary = Defs.TOWERS["moss"]
	var crypt: Dictionary = Defs.TOWERS["frost"]
	var shrine: Dictionary = Defs.TOWERS["ash"]
	var e: Dictionary = Defs.ENEMIES

	# ------------------------------------------------------------ basics
	t.append(_t("The basics", "Your goal",
		"You are the dark lord. Your cave holds [b]5 gems[/b], and self-righteous heroes walk the roads to steal them.\n\n"
		+ "A hero who reaches the cave grabs a gem and runs back the way he came. If he gets off the map, that gem is gone for good. Lose all five and the lair is plundered.\n\n"
		+ "Stop them with towers along the roads, your den's bolts and your Meteor."))
	t.append(_t("The basics", "Waves",
		"Heroes come in waves. The button at the top of the panel counts down to the next one.\n\n"
		+ "[b]Call a wave early[/b] to earn the seconds left as gold. Early calls are how good players get rich, but only call when your towers can take it.\n\n"
		+ "After the last wave the lair is won the moment its last hero falls or flees."))
	t.append(_t("The basics", "Ratings and stars",
		"Each win is rated:\n\n"
		+ "[color=#e8b84a]★[/color] [b]Survived[/b]: you lost some gems.\n"
		+ "[color=#e8b84a]★★[/color] [b]Wicked[/b]: none lost, but a hero touched one.\n"
		+ "[color=#e8b84a]★★★[/color] [b]Brilliant[/b]: no hero ever touched a gem.\n\n"
		+ "Stars are your skill points for Dark Arts. Only your best rating on each lair counts, so replay a lair to earn the stars you missed. A Brilliant win also opens that lair's night mission."))
	t.append(_t("The basics", "Speed and pause",
		"[b]1× / 2×[/b] runs the battle at double speed when a wave is easy.\n\n[b]Pause[/b] stops everything; on a phone the back button pauses too. You can still tap tiles and read their panels while paused."))

	# ------------------------------------------------------------ towers
	t.append(_t("Towers", "Building",
		"Tap an empty tile to see what can be built there. [b]Each tower needs its own ground:[/b] Warband Huts on green moss, Bone Crypts on frost, Cinder Shrines on ash.\n\n"
		+ "The first tower of a kind costs [b]%d gold[/b]; each more of that kind standing costs %d more. Upgrades cost %d (level II) and %d (level III) and add damage and range.\n\n"
		% [hut["cost"][0], Defs.TOWER_COST_STEP, hut["cost"][1], hut["cost"][2]]
		+ "[b]Selling[/b] gives back %d%% of what you spent. The button needs a second tap, so a slip never costs you a tower." % roundi(Defs.SELL_REFUND * 100)))
	t.append(_t("Towers", "Warband Hut",
		"[color=#8fb35a][b]Fast, light arrows.[/b][/color] Fires about twice a second at one hero.\n\n"
		+ "Best against crowds of weak heroes (Peasants, Scouts, Cutpurses). Armour takes a bite out of every arrow, so Knights and Shieldbearers shrug it off.\n\n"
		+ "Range %.1f, rising to %.1f at level III." % [hut["range"][0], hut["range"][2]]
		+ "\n\nAbility: [b]Volley[/b], a second arrow at another hero."))
	t.append(_t("Towers", "Bone Crypt",
		"[color=#9fd8f0][b]Slow, heavy bolts that chill.[/b][/color] Each hit slows the hero hard (%d%% at level I, %d%% at level III) for a few seconds.\n\n"
		% [roundi(crypt["slow"][0] * 100), roundi(crypt["slow"][2] * 100)]
		+ "Slowed heroes spend longer in range of all your other towers, so one Crypt makes a whole stretch of road deadlier. Put it where many towers can reach.\n\n"
		+ "Ability: [b]Dread[/b], hits may terrify a hero: he backs away, or freezes on the spot if he carries a gem."))
	t.append(_t("Towers", "Cinder Shrine",
		"[color=#ff8a3a][b]A burning beam.[/b][/color] It holds on one hero and heats up, reaching %d× damage after %d seconds on the same target. It ignores armour.\n\n"
		% [roundi(Defs.HEAT_MAX), roundi(Defs.HEAT_TIME)]
		+ "Best against Knights and other tough heroes. It starts cold on every new target, so it is weak against swarms.\n\n"
		+ "Range %.1f, the shortest of the three. Ability: [b]Lava[/b], heroes it kills may leave burning ground." % shrine["range"][0]))
	t.append(_t("Towers", "High ground",
		"Some tiles are [b]pale, shimmering stone[/b], raised above the rest. [b]Any tower[/b] can be built on them, whatever the ground around.\n\n"
		+ "Up high a tower sees further: Huts +%.1f range, Shrines +%.1f, Crypts +%.1f.\n\n"
		% [hut["high_range"], shrine["high_range"], crypt["high_range"]]
		+ "There are only a few on each map. Decide what that spot needs most: a Crypt to slow a long bend, a Hut to cover two roads, or a Shrine where Knights come through."))
	t.append(_t("Towers", "Ranks and abilities",
		"Towers earn experience from the damage they deal and rank up three times; each rank adds %d%% damage.\n\n" % roundi(Defs.RANK_DMG * 100)
		+ "A tower at [b]rank %d[/b] that is also [b]upgraded to level III[/b] unlocks its ability: Volley (Hut), Dread (Crypt) or Lava (Shrine). Dark Arts can make each ability stronger.\n\n" % Defs.ABILITY_RANK
		+ "Towers that see a lot of action rank up fastest, so upgrade the ones at the busy spots."))
	t.append(_t("Towers", "Who towers shoot",
		"Towers always pick, in this order:\n\n1. a hero [b]carrying a gem[/b]\n2. a [b]support hero[/b] (Cleric, Shieldbearer, Warden)\n3. whoever has the [b]least health[/b] left\n\nSo a thief running home is never ignored, and healers and protectors die first."))

	# ------------------------------------------------------------ heroes
	t.append(_t("Heroes", "Gem carriers",
		"A hero with a gem glows red and runs for the edge of the map. Every tower turns on him.\n\n"
		+ "[b]Kill him[/b] and his gems fall to the road and roll home on their own. But any hero on that road with room to carry will turn and go for them, even walking back the way he came.\n\n"
		+ "So kill carriers where your towers also cover the road behind them."))
	t.append(_t("Heroes", "Peasant, Footman, Scout",
		"[b]Peasant[/b]: weak and slow, comes in crowds. %d health.\n\n" % e["p"]["hp"]
		+ "[b]Footman[/b]: sturdier, with a little armour (%d). %d health.\n\n" % [e["f"]["armor"], e["f"]["hp"]]
		+ "[b]Scout[/b]: fast and fragile. He reaches the cave before your towers notice. Slow him with a Crypt."))
	t.append(_t("Heroes", "Cleric",
		"Heals the heroes around him while he walks. A group with a Cleric in it lasts much longer.\n\nYour towers shoot Clerics before ordinary heroes, but make sure something reaches him early."))
	t.append(_t("Heroes", "Knight",
		"Slow, very tough ([b]%d health[/b]) and armoured (%d). He carries [b]2 gems[/b].\n\n" % [e["k"]["hp"], e["k"]["armor"]]
		+ "Arrows barely scratch him. Cinder Shrines ignore armour, and the Meteor does too. A Crypt keeps him in range long enough to burn."))
	t.append(_t("Heroes", "Shieldbearer",
		"Arrives from the fourth lair. Heroes within %.1f tiles of him take %d%% less damage (not him, and not from beams, the den or the Meteor).\n\n"
		% [Defs.GUARD_RANGE, roundi(e["b"]["guard"] * 100)]
		+ "Kill him first and the whole group goes soft. Towers already aim for him before ordinary heroes."))
	t.append(_t("Heroes", "Cutpurse",
		"Arrives from the fourth lair. Fast, fragile, and carries [b]2 gems[/b]. Losing one Cutpurse can cost you a whole Brilliant rating.\n\nCrypts and the den's bolts are your best answer."))
	t.append(_t("Heroes", "Warden",
		"Arrives from the fourth lair. His lantern [b]clears slow and Dread[/b] from every hero near him, himself included.\n\nCrypts do little around a Warden. Kill him first, then the chill works again."))
	t.append(_t("Heroes", "Heroes get stronger",
		"Each wave's heroes are tougher than the last. The game also watches how you play: when you crush a wave far from the cave, the next heroes come back much tougher; when a wave gets close, only a little.\n\n"
		+ "[b]Riches draw heroes too.[/b] Gold you leave unspent above %d makes every following wave stronger. Spend it on towers and upgrades instead of saving it.\n\n" % roundi(Defs.THREAT["rich"])
		+ "It never gets easier during a battle, but it never runs away either."))

	# ------------------------------------------------------------ your powers
	t.append(_t("Your powers", "Mana",
		"The purple bar. Mana refills by itself (%.1f a second) and with every kill (+%d). It pays for the Meteor and for cutting woods, mines and wells.\n\nIt stops filling when the bar is full, so spend it." % [Defs.MANA_REGEN, roundi(Defs.MANA_PER_KILL)]))
	t.append(_t("Your powers", "Meteor",
		"Costs [b]%d mana[/b]. Tap Meteor, then tap the map. A moment later it lands for [b]%d damage[/b] to every hero within %.1f tiles, through armour and shields.\n\n"
		% [Defs.METEOR["cost"], Defs.METEOR["dmg"], Defs.METEOR["radius"]]
		+ "Aim slightly ahead of a group, since it takes a moment to fall. Save it for a carrier about to escape or a Knight-heavy wave. The Starfall skill makes it stronger."))
	t.append(_t("Your powers", "Your den",
		"The cave fights back. It holds charges (the sparks above it) and fires a bolt at heroes within %.1f tiles, gem carriers first, for %d damage through armour. A spent charge comes back every %d seconds.\n\n"
		% [Defs.DEN["range"], Defs.DEN["dmg"], roundi(Defs.DEN["refill"])]
		+ "It starts with %d charge; the Hoard's Wrath skill adds more. It is your last line, not your first." % Defs.DEN["charges"]))
	t.append(_t("Your powers", "Woods",
		"Woods block good building spots. Tap a patch and choose [b]Cut woods[/b] (%d mana): you get %d gold for the timber and the ground is free to build on.\n\n"
		% [Defs.CLEAR_MANA, Defs.CLEAR_GOLD]
		+ "The [b]Cut woods[/b] button in the panel clears a random patch without searching the map. Woods next to the road are worth more: tap those yourself."))
	t.append(_t("Your powers", "Mines and wells",
		"On later lairs the woods hide buildings. Cut them free with mana and they work for you:\n\n"
		+ "[b]Gold Mine[/b] (%d mana): %d gold every %d seconds.\n" % [Defs.SITES["mine"]["cut"], Defs.SITES["mine"]["gold"], roundi(Defs.SITES["mine"]["every"])]
		+ "[b]Mana Well[/b] (%d mana): +%.1f mana a second.\n\n" % [Defs.SITES["well"]["cut"], Defs.SITES["well"]["regen"]]
		+ "Free them early: they pay back over the whole battle."))
	t.append(_t("Your powers", "Hero barracks",
		"A barracks keeps sending extra heroes onto its road while the waves are still coming.\n\n[b]Raze it[/b] (%d mana) to stop it for good, and take %d gold from the ruins." % [Defs.SITES["camp"]["cut"], Defs.SITES["camp"]["bounty"]]))
	t.append(_t("Your powers", "Loot",
		"Slain heroes sometimes drop a [b]coin[/b] (gold, more from tougher kinds of hero) or a [b]mana potion[/b] (+%d mana).\n\nTap loot to take it at once. Anything still lying around is gathered by itself when the next wave starts." % Defs.LOOT_POTION_MANA))

	# ------------------------------------------------------------ progress
	t.append(_t("Progress", "Dark Arts",
		"Your skills, opened from the map. [b]Every star is a skill point.[/b]\n\n"
		+ "Each tower kind has its own column: damage, attack speed, range, faster ranks and a stronger ability. [b]The Hoard[/b] column gives your den more charges, every battle more starting gold or mana, and the Meteor more damage.\n\n"
		+ "Tower skills apply to towers you build after buying them. [b]Refund all points[/b] any time to try a different plan."))
	t.append(_t("Progress", "Night missions",
		"Win a lair [b]Brilliant[/b] and its night mission opens (the moon on the map).\n\n"
		+ "Same lair, in darkness: you can only build where you can see. Your cave, towers, mines and wells light the ground around them, so each tower you build opens room for the next.\n\nNight missions earn their own stars."))
	t.append(_t("Progress", "Tips",
		"• Build your first towers near where the roads come close to the cave, so the den helps.\n"
		+ "• Mix towers: Crypts to slow, Huts for crowds, Shrines for Knights.\n"
		+ "• Upgrading a tower at a busy spot is often better than building a new one at a quiet spot.\n"
		+ "• Cut the woods next to the road early: more room for towers, and timber gold.\n"
		+ "• Spend your gold. Hoarding it makes the heroes stronger.\n"
		+ "• Keep enough mana for one Meteor when a dangerous wave is due.\n"
		+ "• Missed a Brilliant? Replay the lair: only your best rating counts."))
	return t


static func _t(group: String, name: String, text: String) -> Dictionary:
	return {"group": group, "name": name, "text": text}
