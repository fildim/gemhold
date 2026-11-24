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
		+ "A hero who reaches the cave grabs a gem and runs back the way he came. If he gets off the map, that gem is gone for good. Lose them all and the lair is plundered.\n\n"
		+ "Stop them with towers along the roads, your den's bolts and your Meteor."))
	t.append(_t("The basics", "Waves",
		"Heroes come in waves. The button at the top of the panel counts down to the next one.\n\n"
		+ "[b]Call a wave early[/b] to earn the seconds left as gold, plus the mana you would have regenerated and the gold your mines would have dug in that time. Time passes for every building: barracks muster what they would have in those seconds, Sluices refill and your den gains its charges. Early calls are how good players get rich, but only call when your towers can take it.\n\n"
		+ "After the last wave the lair is won the moment its last hero falls or flees."))
	t.append(_t("The basics", "Ratings and stars",
		"Each win is rated:\n\n"
		+ "[color=#e8b84a]★[/color] [b]Survived[/b]: you lost some gems.\n"
		+ "[color=#e8b84a]★★[/color] [b]Wicked[/b]: none lost, but a hero touched one.\n"
		+ "[color=#e8b84a]★★★[/color] [b]Brilliant[/b]: no hero ever touched a gem.\n\n"
		+ "The stars next to the gem count at the top show the best rating still within reach in this battle; a message tells you the moment it slips.\n\n"
		+ "Stars are your skill points for Dark Arts. Only your best rating on each lair counts, so replay a lair to earn the stars you missed. A Brilliant win also opens that lair's night mission."))
	t.append(_t("The basics", "Speed and pause",
		"[b]1× / 2×[/b] runs the battle at double speed when a wave is easy.\n\n[b]Pause[/b] stops everything; on a phone the back button pauses too. You can still tap tiles and read their panels while paused.

[b]Settings[/b] (on the map and in battle) sets the volume of effects and music, and turns the screen shake of a Meteor on or off.

[b]Graphics[/b] in Settings: [b]Detailed[/b] draws everything, [b]Light[/b] draws a simpler picture so slower phones stay smooth, and [b]Auto[/b] picks for you (Light on phones, and Light if battles run slow). [b]Show frame rate[/b] puts a small frames-per-second number in the corner of the map.

With a keyboard there are [b]shortcuts[/b]: %s pauses, %s changes speed, %s calls the next wave, %s readies the Meteor and %s cuts woods. Change any of them under [b]Keyboard[/b] in Settings." % [Keys.name_of("pause"), Keys.name_of("speed"), Keys.name_of("next"), Keys.name_of("meteor"), Keys.name_of("cut")]))

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
		"Towers grow battle-hardened (their experience) from the damage they deal. It happens three times, each adding %d%% damage. Tap a tower to see its rank and how close the next one is (the gold numeral at a tower's foot is its upgrade level, not its rank).\n\n" % roundi(Defs.RANK_DMG * 100)
		+ "A fully battle-hardened tower that is also [b]upgraded to level III[/b] unlocks its ability: Volley (Hut), Dread (Crypt) or Lava (Shrine). Its name flashes over the tower and a violet ring appears. Dark Arts can make each ability stronger.\n\n"
		+ "Towers that see a lot of action harden fastest, so upgrade the ones at the busy spots."))
	t.append(_t("Towers", "Level IV: masteries",
		"A tower that is [b]level III and has learned its ability[/b] can be raised once more, for %d gold, into one of two [b]masteries[/b]. Each mastery must first be learned in Dark Arts (tier II, from Chapter III). Tap the tower to choose; [b]the choice is final[/b] for that tower.\n\n" % hut["cost"][3]
		+ "[color=#8fb35a][b]Longhouse[/b][/color] (Hut): every shot is three arrows at up to three heroes. For crowds.\n"
		+ "[color=#8fb35a][b]Hunter's Lodge[/b][/color] (Hut): one heavy javelin that ignores armour, aimed at the healthiest hero, and [b]marks[/b] him for %d seconds: everything hits him %d%% harder. For Knights and bosses.\n\n" % [roundi(Defs.LODGE["mark"]), roundi(Defs.LODGE["mark_dmg"] * 100)]
		+ "[color=#9fd8f0][b]Ossuary[/b][/color] (Crypt): stores a bolt every reload even with no hero in sight, up to %d (the skulls on its roof light up), then looses them in a quick burst at its target (its Aim). For Knights and bosses; when its target falls, the next bolt goes to the next hero.\n" % Defs.OSSUARY["charges"]
		+ "[color=#9fd8f0][b]Mausoleum[/b][/color] (Crypt): each bolt bursts, chilling and hurting every hero within %.1f tiles, and Dread rolls for each of them.\n\n" % Defs.MAUSOLEUM["r"]
		+ "[color=#ff8a3a][b]Twin Flame[/b][/color] (Shrine): two beams on two heroes, each heating up on its own.\n"
		+ "[color=#ff8a3a][b]Sunlance[/b][/color] (Shrine): the beam burns on through its hero and every hero on the line behind him, and keeps part of its heat when it changes target.\n\n"
		+ "[b]Plunder:[/b] a level IV Hut, whichever mastery, loots what it kills: [b]+%d gold[/b] on its first kill, one more on each kill after, up to [b]+%d a kill[/b]. The count is lost if you sell it." % [Defs.PLUNDER_START, Defs.PLUNDER_MAX]))
	t.append(_t("Towers", "Who towers shoot",
		"On [b]Auto[/b] aim, towers pick in this order:\n\n1. a hero [b]carrying a gem[/b]\n2. a [b]support hero[/b] (Cleric, Shieldbearer, Warden, Herald, Engineer, Rainbringer, Sapper, Pavior)\n3. whoever has the [b]least health[/b] left\n\nSo a thief running home is never ignored, and healers and protectors die first.

Tap a tower and its [b]Aim[/b] button to change what it goes for after gem carriers: [b]Strongest[/b] (the hero with the most health, for Knights and bosses) or [b]Closest to the cave[/b] (whoever is about to reach your gems). Gem carriers always come first. Heroes they can't see are skipped: a Diver under water, and anyone in the Iron Belfry's shadow."))

	# ------------------------------------------------------------ heroes
	t.append(_t("Heroes", "Gem carriers",
		"A hero with a gem glows red and runs for the edge of the map. Every tower turns on him.\n\n"
		+ ("Gems are heavy: a hero is [b]%d%% slower[/b] for each gem he carries.\n\n" % roundi(Defs.CARRY_SLOW * 100.0))
		+ "[b]Kill him[/b] and his gems fall to the road and roll home on their own. But any hero on that road with room to carry will turn and go for them, even walking back the way he came.\n\n"
		+ "So kill carriers where your towers also cover the road behind them."))
	t.append(_t("Heroes", "Peasant, Footman, Scout",
		"[b]Peasant[/b]: weak and slow, comes in crowds. %d health.\n\n" % e["p"]["hp"]
		+ "[b]Footman[/b]: sturdier, with a little armour (%d). %d health.\n\n" % [e["f"]["armor"], e["f"]["hp"]]
		+ "[b]Scout[/b]: fast and fragile. He reaches the cave before your towers notice. Slow him with a Crypt."))
	t.append(_t("Heroes", "Cleric",
		"Heals the heroes around him while he walks. A group with a Cleric in it lasts much longer.\n\nYour towers shoot Clerics before ordinary heroes, but make sure something reaches him early. He does not heal boats, siege engines or flyers."))
	t.append(_t("Heroes", "Knight",
		"Slow, very tough ([b]%d health[/b]) and armoured (%d). He carries [b]2 gems[/b].\n\n" % [e["k"]["hp"], e["k"]["armor"]]
		+ "Arrows barely scratch him. Cinder Shrines ignore armour, and the Meteor does too. A Crypt keeps him in range long enough to burn."))
	t.append(_t("Heroes", "Shieldbearer",
		"Arrives from the fifth lair. Heroes within %.1f tiles of him take %d%% less damage (not him, and not from beams, the den or the Meteor).\n\n"
		% [Defs.GUARD_RANGE, roundi(e["b"]["guard"] * 100)]
		+ "Kill him first and the whole group goes soft. Towers already aim for him before ordinary heroes. His shield does not reach boats, siege engines or flyers."))
	t.append(_t("Heroes", "Cutpurse",
		"Arrives from the fourth lair. Fast, fragile, and carries [b]2 gems[/b]. Losing one Cutpurse can cost you a whole Brilliant rating.\n\nCrypts and the den's bolts are your best answer."))
	t.append(_t("Heroes", "Warden",
		"Arrives from the fifth lair. His lantern [b]clears slow and Dread[/b] from every hero near him, himself included.\n\nCrypts do little around a Warden. Kill him first, then the chill works again. His lantern does not reach boats, siege engines or flyers."))
	t.append(_t("Heroes", "Herald",
		"Arrives from the eleventh lair. Heroes within %.1f tiles of his banner, himself included, march [b]%d%% faster[/b]. The gold ring around his feet shows how far it reaches.\n\n"
		% [Defs.HASTE_RANGE, roundi(e["h"]["haste"] * 100)]
		+ "A group with a Herald runs past towers that would have held it. Towers aim for him before ordinary heroes; a Crypt's chill still works on his followers. His banner does not reach boats, siege engines or flyers."))
	t.append(_t("Heroes", "Berserker",
		"Arrives from the thirteenth lair. Tough and unarmoured, but once he drops [b]below half health he runs %.0f× as fast[/b] and glows red.\n\n" % e["r"]["rage"]
		+ "Don't start on a Berserker just before the cave. Hit him early, or hard enough to finish him in one stretch: Crypts and heated Shrine beams."))
	t.append(_t("Heroes", "Champion",
		"Arrives from the fifteenth lair, at the head of the final waves, never more than one in a wave. A crowned giant with [b]%d health[/b], heavy armour (%d), and he carries [b]3 gems[/b].\n\n" % [e["x"]["hp"], e["x"]["armor"]]
		+ "When he falls, [b]three Footmen rise[/b] where he lay and march on. Bring him down far from the cave, with Shrines, the Meteor and the den's bolts."))
	t.append(_t("Heroes", "Fenwalker",
		"From the Drowned Marches (lair 21). Quick and light, and [b]water does not slow or soak him[/b]: he wades fords and swims broken bridges at full speed.

Kill him on dry land; fords and collapsed bridges won't hold him."))
	t.append(_t("Heroes", "Engineer",
		"From lair 22. He [b]rebuilds a collapsed bridge[/b] (he stands at the bank for %d seconds first) and [b]lays planks over a ford[/b] he crosses alive, so heroes cross it dry for a while.

Towers aim for him first. Cover the bank where he will stop." % roundi(Defs.ENGINEER_FIX)))
	t.append(_t("Heroes", "Rainbringer",
		"From lair 23. She carries a [b]rain cloud[/b]: Shrine beams on heroes under it never heat past a third, and it puts out Lava.

Arrows and bolts don't care about rain. Or catch her with a Shrine before the crowd closes in."))
	t.append(_t("Heroes", "Longboat",
		"From lair 25. A boat of heroes on the [b]river[/b], sturdy (%d health) and armoured; chill and Dread don't touch it. Where the water ends it beaches and [b]its crew steps ashore one by one[/b], then marches on.

[b]Sink it before the last of them is off and the rest drown[/b]: each one still aboard counts as slain and pays its bounty. Towers along the river, a Sluice Gate or the Meteor.

The empty boat [b]waits on the shore[/b] to carry them home with your gems. Sink it there too and anyone fleeing must walk back past the cave and out by a land road." % e["l"]["hp"]))
	t.append(_t("Heroes", "Diver",
		"From lair 26. He swims [b]under the water[/b]: while he is in a ford, a broken bridge or the high tide, towers and the den can't see him (a ripple and a reed give him away). The Meteor and Sluice Gates still hit him.

Guard the far bank, and don't collapse a bridge while Divers are coming."))
	t.append(_t("Heroes", "The Tidecaller",
		"The boss of the Drowned Marches (lair 30): [b]%d health[/b], a wide rain cloud and 3 gems. Every %d seconds her [b]surge[/b] washes chill and Dread off the heroes around her and lets them wade freely.

Where she falls, Fenwalkers and Divers rise. While a boss is on the map, her name and health show in a bar over the top of it." % [e["T"]["hp"], roundi(Defs.SURGE["every"])]))
	t.append(_t("Heroes", "Sapper",
		"From the Siegeworks (lair 31). Fast, with a powder keg on his back. He runs off the road at the nearest tower within %.1f tiles, lights a fuse and [b]stuns it for %d seconds[/b], dying in the blast (no bounty).
\nTowers on [b]raised tiles[/b] are out of his reach. Slay him while the fuse burns and the keg goes off among the heroes around him (%d damage). Towers aim for him first." % [Defs.SAPPER["reach"], roundi(Defs.STUN_TIME), Defs.SAPPER["dmg"]]))
	t.append(_t("Heroes", "Pavior",
		"From lair 32. The road behind him is [b]paved[/b]: other heroes walk %d%% faster on it. The paving fades %d seconds after he falls, so the earlier he dies, the shorter the fast stretch.
\nTowers aim for him first." % [roundi((Defs.ZONE_SPEED["paved"] - 1.0) * 100), roundi(Defs.PAVE_FADE)]))
	t.append(_t("Heroes", "Inquisitor",
		"From lair 33. Tough and armoured. His censer smoke (the pale ring around him, %.1f tiles wide) [b]silences[/b] every tower inside it: no ability, no battle-hardened bonus, and %d%% slower fire or heating.
\nOut-range him from raised tiles, or hit him with the Meteor. Your den is never silenced." % [e["i"]["censer"], roundi(Defs.SILENCE_SLOW * 100)]))
	t.append(_t("Heroes", "Trebuchet",
		"From lair 35. A siege engine: %d health and armour %d. It rolls until a tower is within %.1f tiles, sets up, then every %d seconds [b]buries the strongest tower in reach under rubble[/b]: that tower can't fire until you pay to clear it. [b]It hits each tower only once[/b] (another Trebuchet may hit it again); when it has hit every tower in reach, it packs up and rolls on to the next ones. It never takes gems, and leaves at the end of the road.
\n[b]Only fire breaks it:[/b] Cinder Shrines burn it down, and [b]a Meteor smashes it at once[/b], whatever its health. Huts, Crypts and your den don't even aim at it. When the last wave is out and only engines are left, it rolls away." % [e["u"]["hp"], e["u"]["armor"], Defs.TREBUCHET["reach"], roundi(Defs.TREBUCHET["every"])]))
	t.append(_t("Heroes", "The Iron Belfry",
		"The boss of the Siegeworks (lair 40): a siege tower with [b]%d health[/b] and armour %d. Heroes walking in the %.1f tiles behind it [b]can't be targeted[/b] by towers or the den (the Meteor still hits them). Every %d seconds a Sapper jumps out.
\nAt your den it unloads six Footmen and rolls away. Break it open earlier and its garrison spills out: Footmen, Knights and an Inquisitor." % [e["I"]["hp"], e["I"]["armor"], Defs.BELFRY["cover"], roundi(Defs.BELFRY["sapper"])]))
	t.append(_t("Heroes", "Skylancer",
		"From the Radiant Host (lair 41). He [b]flies straight for your den[/b] along a flight line (the faint dashed line), over roads, water and Lava. Chill holds him only half as well.
\nOnly towers in reach of his flight line can hit him, so build some along it and near the den. Gems he drops fall to the nearest road and roll home."))
	t.append(_t("Heroes", "Justicar",
		"From lair 42. Armoured and tough (%d health, carries 2 gems). Once, when he drops below %d%% health, a [b]holy shield[/b] makes him untouchable for %.1f seconds and heals him to %d%%. Dread doesn't touch him.
\nBurst him down past the shield in one go, or make him spend it early and finish him where your towers are thick." % [e["j"]["hp"], roundi(Defs.JUSTICAR["below"] * 100), Defs.JUSTICAR["dur"], roundi(Defs.JUSTICAR["heal"] * 100)]))
	t.append(_t("Heroes", "Spiriter",
		"From lair 45. When he takes a gem he doesn't run: he [b]chants at the cave mouth for %d seconds[/b] (the shrinking blue ring) and vanishes with it. Dread or death breaks the chant; a Spiriter whose chant is broken runs like anyone else.
\nDen charges and a Crypt with Dread near the den are your answer." % roundi(Defs.CHANT_TIME)))
	t.append(_t("Heroes", "The Seraph",
		"The boss of the Radiant Host (lair 50): [b]%d health[/b], armour %d, and she can carry 3 gems. She flies. At two thirds and one third of her health she [b]lands on the nearest road[/b], is untouchable for %d seconds and raises the last heroes you slew (six, then eight) at half health. Dread doesn't touch her.
\nOnce she has landed she walks the road like anyone else." % [e["S"]["hp"], e["S"]["armor"], roundi(Defs.SERAPH["dur"])]))
	t.append(_t("Heroes", "Heroes get stronger",
		"Each wave's heroes are tougher than the last. The game also watches how you play: when you crush a wave far from the cave, the next heroes come back much tougher; when a wave gets close, only a little. Heroes falling quickly toughen the rest of their own wave too.\n\n"
		+ "[b]Riches draw heroes too.[/b] Gold you leave unspent above %d makes every following wave stronger. Spend it on towers and upgrades instead of saving it.\n\n" % roundi(Defs.THREAT["rich"])
		+ "You see it in battle as [b]Resolve[/b] (×1.00 at the start). It never gets easier during a battle, and good defending alone never takes it past [b]×%.1f[/b], so a clean game always stays within reach. Only hoarded gold can push it further, up to [b]×%.1f[/b]. Your score for a win is multiplied by the Resolve the heroes reached: the tougher you made them, the more it is worth. Races and challenges don't use it: there both players meet the same heroes." % [Defs.THREAT["max"], Defs.THREAT["max_rich"]]))

	# ------------------------------------------------------------ water
	t.append(_t("The Marches", "Fords and bridges",
		"Where a road crosses [b]shallows[/b] it is a ford: heroes wade at %d%% speed and come out [b]soaked[/b] for %d seconds. Crypt chill lasts longer on a soaked hero, but Shrine beams heat up slower.

Where a road crosses [b]deep water[/b] it is a bridge. Tap it and [b]Collapse[/b] it (%d mana): heroes must swim the gap at %d%% speed, soaked, and no Herald can hurry them. An Engineer can rebuild it; collapse it again as often as you like." % [roundi(Defs.ZONE_SPEED["ford"] * 100), roundi(Defs.SOAK_TIME), Defs.COLLAPSE["mana"], roundi(Defs.ZONE_SPEED["swim"] * 100)]))
	t.append(_t("The Marches", "The tide",
		"On some lairs the water rises and falls. At [b]high tide[/b] the fords are too deep to wade, so heroes swim them, slowly, and Divers hide in them.

The tide clock beside the wave counter shows it: the blue arc is high tide, the hand is now."))
	t.append(_t("The Marches", "Wave routes",
		"On some lairs each wave takes only some of the roads. The [b]glowing road starts[/b] show where the next wave will come from, so you can get ready."))
	t.append(_t("The Marches", "Sluice Gates and Dark Altars",
		"A [b]Sluice Gate[/b] is yours from the start. Open it (%d mana) and a flood sweeps down its river: every boat on it is pushed back and loses [b]a third of its full health[/b], so three floods sink one. Open it when boats are on the water. It takes %d seconds to fill again.

A [b]Dark Altar[/b] is overgrown. Cut it free (%d mana) and towers within %.1f tiles deal %d%% more damage and grow battle-hardened faster." % [Defs.SITES["sluice"]["mana"], roundi(Defs.SITES["sluice"]["recharge"]), Defs.SITES["altar"]["cut"], Defs.SITES["altar"]["range"], roundi(Defs.SITES["altar"]["dmg"] * 100)]))

	# ------------------------------------------------------------ siege
	t.append(_t("The Siegeworks", "Stunned, buried, silenced",
		"Siege heroes can't destroy your towers, but they can stop them for a while. Tap a tower to see what is wrong with it:
\n[b]Stunned[/b] (a Sapper's keg): no firing for %d seconds.
[b]Buried[/b] (a Trebuchet's stone): no firing [b]until you Clear rubble[/b] for %d gold. A Trebuchet hits each tower only once.
[b]Silenced[/b] (an Inquisitor's censer): no ability, no battle-hardened bonus, slower, for as long as he is near.
\nThe [b]Sturdy Foundations[/b] skill (The Hoard) makes stuns and silence shorter and rubble cheaper to clear." % [roundi(Defs.STUN_TIME), Defs.RUBBLE_CLEAR]))
	t.append(_t("The Siegeworks", "Signal Fires and Workshops",
		"A [b]Signal Fire[/b] calls the heroes on: while it burns, every wave comes %d seconds sooner and barracks muster faster. Raze it (%d mana) for %d gold.
\nA [b]Siege Workshop[/b] builds Trebuchets and rolls them onto its road while waves are coming. Raze it (%d mana) to stop it, for %d gold." % [roundi(Defs.SITES["beacon"]["sooner"]), Defs.SITES["beacon"]["cut"], Defs.SITES["beacon"]["bounty"], Defs.SITES["workshop"]["cut"], Defs.SITES["workshop"]["bounty"]]))
	t.append(_t("The Siegeworks", "Dusk",
		"On some lairs [b]night falls during the battle[/b], as a set wave begins. From then on you can only build where your den, towers, mines and wells give light, just as on a night mission.
\nThe wave counter shows which wave brings the night. The towers you build by day decide where you can build after dark. The lair's own night mission is dark from the start."))

	# ------------------------------------------------------------ radiant
	t.append(_t("The Radiant Host", "Chapels and hallowed ground",
		"A [b]Chapel[/b] heals the heroes walking within %.1f tiles of it. Raze it (%d mana) for %d gold.
\nSome tiles are [b]hallowed ground[/b] (they glow pale gold). Towers built on them have %d%% less range and no ability until [b]every Chapel[/b] in the lair is razed; then the glow goes out and they work in full." % [Defs.SITES["chapel"]["r"], Defs.SITES["chapel"]["cut"], Defs.SITES["chapel"]["bounty"], roundi((1.0 - Defs.HALLOW_RANGE) * 100)]))
	t.append(_t("The Radiant Host", "Eclipse",
		"On some lairs [b]the sun goes dark[/b] for a while, again and again. While it is dark you can only build where your den, towers, mines and wells give light, as on a night mission. Towers already built keep fighting. The dial beside the wave counter shows it: the violet arc is the darkness, the hand is now.\n\nThe lair's night mission is dark all the time."))
	t.append(_t("The Radiant Host", "Flight lines",
		"Flyers ignore the roads and take a [b]flight line[/b] (a faint dashed line) straight to your den. Nothing blocks building under it.\n\nOnly towers in reach of the line can hit a flyer, so build some along it and near the den."))

	# ------------------------------------------------------------ your powers
	t.append(_t("Your powers", "Mana",
		"The purple bar. Mana refills slowly by itself (%.1f a second), faster with Mana Wells and the Mana Spring skill; kills give none. It pays for the Meteor and for cutting woods, mines and wells.\n\nIt stops filling when the bar is full, so spend it." % Defs.MANA_REGEN))
	t.append(_t("Your powers", "Meteor",
		"Costs [b]%d mana[/b]. Tap Meteor, then tap the map. A moment later it lands for [b]%d damage[/b] to every hero within %.1f tiles, through armour and shields.\n\n"
		% [Defs.METEOR["cost"], Defs.METEOR["dmg"], Defs.METEOR["radius"]]
		+ "Aim slightly ahead of a group, since it takes a moment to fall. Save it for a carrier about to escape or a Knight-heavy wave. The Starfall skill makes it stronger."))
	t.append(_t("Your powers", "Your den",
		"The cave fights back. It holds charges (the sparks above it) and fires a bolt at heroes within %.1f tiles, gem carriers first, for %d damage through armour. A spent charge comes back every %d seconds.\n\n"
		% [Defs.DEN["range"], Defs.DEN["dmg"], roundi(Defs.DEN["refill"])]
		+ "It starts with %d charge; the Hoard's Wrath skill adds more. It is your last line, not your first. Tap the cave to see how far its bolts reach." % Defs.DEN["charges"]))
	t.append(_t("Your powers", "Woods",
		"Woods block good building spots. Tap a patch and choose [b]Cut woods[/b] (%d mana): you get %d gold for the timber and the ground is free to build on.\n\n"
		% [Defs.CLEAR_MANA, Defs.CLEAR_GOLD]
		+ "The [b]Cut woods[/b] button in the panel clears a random patch without searching the map. Woods next to the road are worth more: tap those yourself."))
	t.append(_t("Your powers", "Mines and wells",
		"On later lairs the woods hide buildings. Cut them free with mana and they work for you:\n\n"
		+ "[b]Gold Mine[/b] (%d mana): %d gold the moment it is freed, then %d gold every %d seconds.\n" % [Defs.SITES["mine"]["cut"], Defs.SITES["mine"]["lode"], Defs.SITES["mine"]["gold"], roundi(Defs.SITES["mine"]["every"])]
		+ "[b]Mana Well[/b] (%d mana): a rush of +%d mana and +%d maximum mana, then +%.1f mana a second.\n\n" % [Defs.SITES["well"]["cut"], Defs.SITES["well"]["burst"], Defs.SITES["well"]["max"], Defs.SITES["well"]["regen"]]
		+ "The [b]Buried Gold[/b] and [b]Mana Spring[/b] skills make every mine and well pay more.\n\n"
		+ "Free them early: they pay back over the whole battle."))
	t.append(_t("Your powers", "Hero barracks",
		"A barracks keeps sending extra heroes onto its road, one after another, while the waves are still coming, and its squads grow as the waves go on.\n\n[b]Raze it[/b] (%d mana) to stop it for good and take %d gold from the ruins: the squad still lined up scatters, and its troops already on the road lose heart (a third of their health).\n\nFrom lair 5 on, buildings are sturdier: mines, wells and barracks take [b]2 cuts[/b], and [b]3[/b] from lair 7 (tap one to see how many are left). Each cut costs less, but the whole job costs more. Every cut on a barracks also slows its musters." % [Defs.SITES["camp"]["cut"], Defs.SITES["camp"]["bounty"]]))
	t.append(_t("Your powers", "Loot",
		"Slain heroes sometimes drop a [b]coin[/b] (gold, more from tougher kinds of hero) or a [b]mana potion[/b] (+%d mana).\n\nTap loot to take it at once. Anything still lying around is gathered by itself when the next wave starts, and in the last wave every drop is taken at once." % Defs.LOOT_POTION_MANA))

	# ------------------------------------------------------------ progress
	t.append(_t("Progress", "Dark Arts",
		"Your skills, opened from the map. [b]Every star is a skill point.[/b]\n\n"
		+ "Each tower kind has its own tab: damage, attack speed, range, faster ranks and a stronger ability. [b]The Hoard[/b] tab gives your den more charges, more starting gold and richer mines (Buried Gold), more mana, faster mana and stronger wells (Mana Spring), and the Meteor more damage. Buried Gold and Mana Spring open 3 more ranks with every chapter.\n\n"
		+ "Every star can always be spent: each tower tab ends with a [b]deep skill[/b] of %d small ranks (+%d%% damage each) and The Hoard with [b]Tithe[/b] (%d ranks of +%d starting gold), for the stars left once the rest is learned.\n\n" % [Defs.DRILL_MAX, roundi(Defs.DRILL_DMG * 100), Defs.TITHE_MAX, Defs.TITHE_GOLD]
		+ "More skills open as the campaign goes on: [b]The Land[/b] (cutting, raised tiles, Sluices and Altars) with Chapter II, and [b]tier II[/b] of every tree and the masteries with Chapter III (Floodmaster and Black Rites in The Land), Sturdy Foundations against siege heroes with Chapter IV, and [b]tier III[/b] with Chapter V: a Legend skill for each tower, Hoard's Fury for the den and Dragon's Patience for starting mana. A tier that is still shut shows which chapter opens it.

"
		+ "Tower skills apply to towers you build after buying them. [b]Refund all points[/b] any time to try a different plan."))
	t.append(_t("Progress", "Night missions",
		"Win a lair [b]Brilliant[/b] and its night mission opens (the moon on the map).\n\n"
		+ "Same lair, in darkness: you can only build where you can see. Your cave, towers, mines and wells light the ground around them, so each tower you build opens room for the next.\n\nNight missions earn their own stars."))
	t.append(_t("Progress", "Score and Hall of Fame",
		"Every won battle scores points:\n\n"
		+ "• up to [b]1000[/b] for the gems you kept\n"
		+ "• [b]+500[/b] for Wicked, [b]+1000[/b] for Brilliant\n"
		+ "• [b]5[/b] for every second you skip by calling waves early\n"
		+ "• [b]1[/b] for every gold coin left at the end (but hoarding gold makes heroes stronger)\n\n"
		+ "Each lair further along the campaign is worth [b]10%% more[/b], night missions [b]half as much again[/b], and the whole is multiplied by the heroes' [b]Resolve[/b] at the end (up to ×%.1f). Your best score on each mission adds up to your total.\n\n" % Defs.THREAT["max"]
		+ "The [b]Hall of Fame[/b] on the map has the online leaderboard (the total and every lair, day, night and Long Night: tap the board's name to pick one, tap a player to challenge them to a race), your [b]achievements[/b], and an optional account. Sign in to put your name on the board and to keep your scores and achievements on any device. Resetting progress keeps achievements and best scores."))
	t.append(_t("Progress", "The Long Night",
		"Once you have won a lair by day, its start card offers the [b]Long Night[/b]: the same lair, played by day with [b]your own Dark Arts[/b], but the waves never end. After the lair's own waves, its last %d come round again and again, each time with one more hero, and every wave past the end is [b]%d%% tougher[/b] than the one before. Its heroes are tougher than by day from the very first wave. Sooner or later the hoard falls; the question is when.\n\n" % [Defs.LONG["cycle"], roundi(Defs.LONG["grow"] * 100)]
		+ "Resolve plays no part (everyone meets the same waves) and hoarded gold draws nothing. You earn no stars: what counts is how many [b]waves you held[/b] (every hero of the wave slain or gone), shown in battle under the wave counter. Heroes slain break ties.\n\n"
		+ "Each lair's Long Night has [b]its own leaderboard[/b] in the Hall of Fame. It doesn't count toward your total score."))
	t.append(_t("Progress", "Online races",
		"[b]Race a friend[/b] on the map, or the [b]Race[/b] tab in the Hall of Fame, pits you against a friend (sign in first, under Account). One of you hosts a race on any lair they have cleared (or [b]Random lair[/b], or a night mission once it is open) and gets a code; the other types the code in, whatever lair it is, and the race begins for both at once.\n\n"
		+ "You play the same lair with the same heroes and [b]the same Dark Arts skills[/b]: a standard set for that lair instead of your own, so it is fair and there is nothing to choose. [b]Waves come faster[/b] than in the campaign and heroes are weaker to make up for it, so a race takes about 3 to 6 minutes. A badge on the map shows your rival's wave and gems.\n\n"
		+ "[b]Attack your rival:[/b] every [b]%d heroes[/b] you slay sends one like the last onto their road, and [b]Send heroes[/b] (in place of Pause) buys more with gold.\n\n" % Defs.RACE_KILL_SEND
		+ "[b]The race ends for both[/b] the moment one of you clears the last wave or falls. Clear it first and you win; fall, and your rival wins. If you both clear it within a moment of each other, each second sooner is worth [b]%d points[/b] on top of the score, and the most points win. Leaving a race counts as a loss.\n\n" % Defs.RACE_TIME_BONUS
		+ "[b]Challenge a player:[/b] tap anyone on the Leaderboard and [b]Challenge[/b] them to a race on a lair and at a time you pick. They see it on the Race page next time they play, and can accept, ask for another time or say no; the Race a friend button on the map shows when a challenge waits for you. At the agreed time (from 10 minutes before), both open the Race page and tap [b]Ready[/b]: the race starts once you both have.

"
		+ "Every race goes on your record: the [b]Races[/b] leaderboard ranks players by wins. Races need an account and don't change your campaign or lair scores."))
	t.append(_t("Progress", "Tips",
		"• Build your first towers near where the roads come close to the cave, so the den helps.\n"
		+ "• Mix towers: Crypts to slow, Huts for crowds, Shrines for Knights.\n"
		+ "• Upgrading a tower at a busy spot is often better than building a new one at a quiet spot.\n"
		+ "• Cut the woods next to the road early: more room for towers, and timber gold.\n"
		+ "• Spend your gold. Hoarding it makes the heroes stronger.\n"
		+ "• Keep enough mana for one Meteor when a dangerous wave is due.\n"
		+ "• Missed a Brilliant? Replay the lair: only your best rating counts."))
	t.append(_t("Progress", "Music credits",
		"[b]Kevin MacLeod[/b] (incompetech.com), licensed under Creative Commons: By Attribution 3.0 (creativecommons.org/licenses/by/3.0): Heroic Age, Curse of the Scarab, Volatile Reaction, Crusade, Five Armies, Black Vortex, Darkling, Final Battle of the Dark Wizards, Firebrand, Killers, Malicious, Ossuary 2 - Turn, Prelude and Action, Rynos Theme, Unholy Knight.

"
		+ "Public-domain recordings from Wikimedia Commons: Grieg, In the Hall of the Mountain King (Musopen); Wagner, Ride of the Valkyries; Beethoven, Symphony No. 5 (Musopen).\n\n"
		+ "[b]Matthew Pablo[/b] (matthewpablo.com), licensed under Creative Commons: By Attribution 3.0: Dark Descent (the map).

"
		+ "Public domain (CC0) from OpenGameArt.org: The Final Battle by skrjablin; QaziJamJam (orchestral battle theme) by Emma_MA.

"
		+ "From OpenGameArt.org under Creative Commons By Attribution 3.0: Battle Site by Tausdei; Death Is Just Another Path by Otto Halmén; The Wraiths of Winter by HitCtrl. Under By Attribution 4.0: Egipet Battle Music, music by Alex_089; Epic Orchestral Fantasy Theme by Markus Lindner."))
	return t


static func _t(group: String, name: String, text: String) -> Dictionary:
	return {"group": group, "name": name, "text": text}


## Pictures shown beside a topic's title (GameIcon keys), by topic name.
const ICONS := {
	"Your goal": ["gem"], "Waves": ["banner"], "Ratings and stars": ["star"], "Speed and pause": ["hourglass"],
	"Building": ["towers"], "Warband Hut": ["tower:moss"], "Bone Crypt": ["tower:frost"], "Cinder Shrine": ["tower:ash"],
	"High ground": ["hill"], "Ranks and abilities": ["skill:moss_ability", "skill:frost_ability", "skill:ash_ability"],
	"Gem carriers": ["hero:k"], "Peasant, Footman, Scout": ["hero:p", "hero:f", "hero:s"], "Cleric": ["hero:c"],
	"Knight": ["hero:k"], "Shieldbearer": ["hero:b"], "Cutpurse": ["hero:t"], "Warden": ["hero:w"], "Herald": ["hero:h"],
	"Berserker": ["hero:r"], "Champion": ["hero:x"], "Heroes get stronger": ["up"], "Mana": ["potion"],
	"Meteor": ["spell:meteor"], "Your den": ["orb"], "Woods": ["tree"], "Mines and wells": ["site:mine", "site:well"],
	"Hero barracks": ["site:camp"], "Loot": ["coins", "potion"], "Dark Arts": ["book"], "Night missions": ["moon"],
	"Score and Hall of Fame": ["trophy"], "Online races": ["flag"],
	"Sapper": ["hero:a"], "Pavior": ["hero:v"], "Inquisitor": ["hero:i"], "Trebuchet": ["hero:u"], "The Iron Belfry": ["hero:I"],
	"Stunned, buried, silenced": ["hero:u"], "Signal Fires and Workshops": ["site:beacon", "site:workshop"], "Dusk": ["moon"],
	"Skylancer": ["hero:y"], "Justicar": ["hero:j"], "Spiriter": ["hero:n"], "The Seraph": ["hero:S"],
	"Chapels and hallowed ground": ["site:chapel"], "Eclipse": ["moon"], "Flight lines": ["hero:y"],
	"Level IV: masteries": ["tower:moss", "tower:frost", "tower:ash"], "Who towers shoot": ["towers"],
	"Fenwalker": ["hero:m"], "Engineer": ["hero:e"], "Rainbringer": ["hero:q"], "Longboat": ["hero:l"], "Diver": ["hero:d"],
	"The Tidecaller": ["hero:T"], "Fords and bridges": ["hero:m"], "The tide": ["hero:T"], "Wave routes": ["banner"],
	"Sluice Gates and Dark Altars": ["site:sluice", "site:altar"],
}
