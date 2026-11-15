# Gemhold: notes for developers

The rules in detail, how the project is organised, tests, builds and publishing. For players, see the [README](../README.md).

A dark-lord tower defense for Windows, macOS, Linux, Android, iPhone and the web, built with **Godot 4.6**. You guard a cave of gems; heroes walk the roads to steal them. It has music and sound effects (the **Settings** button opens a window with separate volume sliders for effects and music and a screen shake switch), and the first lair teaches you as you play: each tip freezes the battle, darkens the screen and lights up the one thing to tap. The first time you have a skill point to spend, the map does the same for Dark Arts. The first time a mine, well or barracks shows up, or a new kind of hero walks onto the map, the battle stops and a tip lights it up and explains it. **Skip tutorial** ends the first-lair tips, **No more tips** ends the building and hero tips; **Reset progress** brings them all back.

The campaign opens on a level map: fifty lairs in five chapters of ten (the arrows beside the heading switch chapter). Lair 1 ("Mossfold Pass") is the tutorial, ported from the web prototype. From there each lair turns one or two difficulty levers further, and later lairs mix them, so no two play alike (see **Campaign** below). Clearing a level Brilliant unlocks its night mission. Progress saves automatically: unlocked levels, best rating per mission and skills. Each level guards 5 gems.

## What's in a battle

- **Towers** need their own ground (moss, frost, ash). **Raised tiles** are single tiles of pale, shimmering stone set higher than the rest: any of the three towers can be built on them, whatever the ground, and they give it extra range (Hut +0.8, Shrine +0.6, Crypt +0.5). Which tower to put up high is your call. The first tower of each type costs 50 gold and each more of that type standing costs 15 more (50, 65, 80…); upgrades cost 75 (level II) and 100 (level III).
- **Three ways to attack**, none stronger overall: the **Warband Hut** fires fast, light arrows (best on crowds, blunted by armour); the **Bone Crypt** fires slow, heavy bolts that slow heroes hard; the **Cinder Shrine** holds a continuous beam on one hero that ignores armour and heats up to 5× damage, but starts cold on every new target (best on knights). `tests/tower_test.gd` compares them. Every level starts with 230 gold.
- **Threat** (dynamic difficulty, never shown): after each wave the game checks how deep into your defence its heroes got, meaning how much of the stretch your towers and den can reach they walked through. The threat multiplies hero health and only ever rises: a lot after a wave you stopped early (up to +40%), only a little after one that got close (+1–3%). Riches draw heroes too: unspent gold above 250 adds to it after every wave (+5% per 100 gold, up to +25%), so hoarding is never the safe choice. It starts at ×1.0 each battle and tops out at ×4.0; tune it with `THREAT` in `defs.gd`.
- **Veterancy:** towers rank up from damage dealt (240, 800, 1900), up to 3 ranks (+8% damage each). Ranks are hidden from the player: towers show only their upgrade level (a Roman numeral badge). A tower at rank 3 that is also upgraded to level III unlocks its ability: Volley (Huts fire a second arrow), Dread (Crypt hits can terrify a hero) and Lava (heroes a Shrine kills have a 35% chance to leave a pool of burning ground).
- **Meteor** (50 mana): tap Meteor, then the map; a moment later it lands for 650 damage around that spot, through armour.
- **Level IV and masteries:** a level III tower that has learned its ability can become one of two masteries (150 gold), each first unlocked in Dark Arts (`mastery_<id>`), offered as actions in its tile panel; the choice is final. Huts: **Longhouse** (three arrows at three heroes, the extras at `LONGHOUSE_SHARE`) or **Hunter's Lodge** (slower heavy javelin through armour that marks its hero: +15% damage from everything). Crypts: **Ossuary** (stores up to 4 bolts, looses them at different heroes, unchilled first) or **Mausoleum** (bolts burst over heroes close by). Shrines: **Twin Flame** (two beams, each its own heat) or **Sunlance** (burns every hero on the line behind its target, keeps some heat when it switches). A level IV Hut **plunders**: +1 gold on its first kill as level IV, +2 on the next, up to +5 (`PLUNDER_MAX`). The plain level IV step is small (a few points of damage and +0.1 range, `Defs.TOWERS` fourth entries): the plan's larger level IV stats made every mastery about 30% better everywhere before its own effect, against the balance target of +35-45% in its niche and at most 15% elsewhere. `tests/tower_test.gd -- iv` measures each mastery against a battle-hardened level III on a crowd, one Knight and a mixed group (very tough heroes, damage dealt): roughly +30-55% in their niches, +0-17% outside, A and B of a tower within about 12% on average. Tuning numbers: `LODGE`, `OSSUARY`, `MAUSOLEUM`, `TWIN_DMG`, `TWIN_SAME`, `SUNLANCE` in `defs.gd`.
- **Cutting** costs mana. It clears woods, frees **Gold Mines** (gold over time) and **Mana Wells** (faster mana), and razes **Hero Barracks**, which otherwise send extra heroes while waves are coming. The **Cut woods** button clears a random patch of woods for the same mana, without hunting for one on the map. From lair 4 buildings can take several cuts (`site_cuts` in the level file, or `cuts` on one building, rising to 4 by the end); `cut_cost` in game_sim.gd spreads 1.5x/2x/2.5x of the base mana over 2/3/4 cuts, and each cut on a barracks slows its musters by 30%. The building's tile panel shows the cuts as a bar of blocks with "2 of 3 cuts left" (`"cuts"` in its `cell_info`).
- **Heroes:** Peasant, Footman, Scout, Cleric (heals nearby heroes) and Knight (armoured, carries 2 gems), then the **Cutpurse** (lair 4: fast, fragile, carries 2 gems), the **Shieldbearer** (lair 5: other heroes within 1.2 tiles take 35% less damage) and the **Warden** (lair 5: his lantern clears slow and Dread from heroes around him). Chapter II adds the **Herald** (lair 11: heroes near his banner, himself included, walk 35% faster), the **Berserker** (lair 13: below half health he runs 2.1× as fast) and the **Champion** (lair 15: a 1500-health armoured boss who carries 3 gems; when he falls, three Footmen rise where he lay). Chapter III adds the **Fenwalker** (water does not slow or soak him), the **Engineer** (rebuilds collapsed bridges after standing at the bank 4 s, lays planks over fords he crosses: no slow or soak there for 40 s), the **Rainbringer** (under her cloud Shrine beams never heat past 35% and Lava goes out), the **Longboat** (river roads only; chill and Dread do not work on it; at its landing its crew, `"4f"` or the wave's `cargo`, steps ashore; sunk on the water, the crew drowns and pays), the **Diver** (hidden from towers and the den in fords, collapsed bridges and high-tide water; meteors and sluices still hit) and the boss **Tidecaller** (a wide rain cloud; every 12 s her surge clears chill and Dread around her and lets heroes wade freely; 3 Fenwalkers and 2 Divers rise where she falls).
- **Water (Chapter III):** fords slow and soak, bridges can be collapsed from their tile panel (40 mana, 20 more each later time; heroes swim the gap), the **Tide** rule floods fords on a timer (tide clock in the HUD), and **wave routes** send waves down some roads only (the next wave's road starts glow). Two new buildings: the **Sluice Gate** (yours from the start; 35 mana sends a surge down its waterway: heroes in the water are pushed back 2 tiles and take 120 damage through armour, boats triple; 45 s to refill) and the **Dark Altar** (cut free: towers within 2.2 tiles +10% damage and rank up 20% faster).
- **Siege (Chapter IV):** heroes never destroy towers, but three **tower statuses** stop them for a while (`Tower.stun`, `Tower.rubble`, `Tower.silence`; the tile panel names each and its cause, `GameSim.tower_status`). **Stunned** and **buried** towers don't fire and a beam goes out and cools; **Clear rubble** (15 gold, `RUBBLE_CLEAR`) is the first action in a buried tower's panel. **Silenced**: no ability, no battle-hardened damage bonus, 30% slower fire or heating (`SILENCE_SLOW`). **Sturdy Foundations** (tier II, The Hoard) takes 15% per rank off all three (`STURDY`, `GameSim.sturdy_mul`). Heroes: the **Sapper** (`SAPPER`: runs off the road at the nearest tower within 1.3 tiles that is not on a raised tile and that no other Sapper is after, lights a 1.2 s fuse and stuns it for 7 s, dying in the blast with no bounty and no threat; slain while the fuse burns, the keg deals 150 to heroes within 1 tile), the **Pavior** (the road behind him is paved, +25% speed, `GameSim.paved` stretches that fade `PAVE_FADE` 30 s after he falls, leaves or turns back), the **Inquisitor** (censer smoke 1.8 tiles wide silences every tower inside it; the den is never silenced), the **Trebuchet** (`TREBUCHET`: rolls until a tower is within 3.6 tiles or 55% of its road is behind it, sets up for 1.5 s, then every 5 s throws a stone that buries the tower with the most gold in it under Rubble for 9 s; never takes gems; once the last wave is out and only engines are left it rolls away, which counts neither as escaping nor toward the threat, so the win check never hangs on it) and the boss **Iron Belfry** (`BELFRY`: heroes within 1.5 tiles behind it on its road are `covered`, skipped by towers and the den like hidden Divers, though area damage still lands; a Sapper jumps out every 12 s; at the den it unloads 6 Footmen and rolls away; broken open earlier it spills 4 Footmen, 2 Knights and an Inquisitor). Trebuchets and the Belfry are `steady` (no chill or Dread). Buildings: the **Signal Fire** (`beacon`, a hero building: while it stands, waves come 4 s sooner and barracks muster 25% faster; raze it for 30 gold) and the **Siege Workshop** (`workshop`, a barracks that musters Trebuchets; `Defs.HERO_SITES` are razed for a bounty, `Defs.MUSTER_SITES` send troops). The **Dusk** rule (`{"kind": "dusk", "wave": 9}`) turns a day mission to night as that wave starts (`GameSim.dark`, `dusk_t`; the darkness fades in over 3 s); the lair's night mission is dark from the start.
- **The Radiant Host (Chapter V):** **flyers** (`"fly"`: the **Skylancer** and the Seraph) take an air road (`path_info` kind `air`, or one straight line per land road from its start to the lair if the lair has flyers and no air road). Air roads mark no road tiles, so building is allowed under them; `Level.wave_air` deals flyers over the air roads a wave may use. Flyers are drawn `FLY_LIFT` above their shadow, chill holds them at `FLY_CHILL` (half), Lava does not reach them, and gems they drop fall to the nearest land road (`GameSim._nearest_land`). The **Justicar** (`JUSTICAR`): once, below 35% health, a holy shield makes him untouchable (`Enemy.untouch`: `hurt` does nothing) for 2.5 s and heals him to 60%; `fearless` (no Dread). The **Spiriter** (`"chant"`): when he takes a gem he chants 4 s at the cave mouth (`Enemy.chant`) and vanishes with it (lost); Dread breaks the chant and he runs like anyone else. The boss **Seraph** (`SERAPH`): flies; at 66% and 33% health she lands on the nearest land road (`grounded`, she walks from then on), is untouchable 4 s and raises the last 6, then 8, slain heroes at half health (`GameSim.fallen`: no bosses, boats, engines or flyers). The **Chapel** (a hero building) heals heroes within 2 tiles (10 health a second × `hp_mul`) and keeps **hallowed ground** holy: `H` tiles where towers have 80% range and no ability (`Tower.holy`, `GameSim.hallow_on`) until every Chapel in the lair is razed. The **Eclipse** rule darkens the last `dark` seconds of every `period` (`GameSim.eclipse`; `dark_t`/`dark_k` fade the view both ways; `can_dark` decides whether lights are kept). Every lair holds 5 gems (the level format still allows `start.gems` 5 to 7; the owner chose to keep 5 everywhere, 2026-11-15). **Dark Arts tier III** (40 lairs beaten): Legend +5% damage per tower kind (`LEGEND_DMG`), Hoard's Fury +20% den damage (`FURY_DMG`), Dragon's Patience +10 starting mana. Renown (score only) was planned and removed by the owner (2026-11-15).
- **Loose gems:** a slain carrier drops his gems and they float back along the road to the hoard. Any hero on that road (or one joined to it) with room to carry turns toward them, even back the way he came, so kill the carrier where your towers can cover the gems.
- **Targeting:** towers shoot gem carriers first, then the special support heroes (Cleric, Shieldbearer, Warden), then whoever has the least health left.
- **Loot:** a slain hero drops a coin (32%), a mana potion (15%) or nothing, never both. Coins are worth 4 gold plus 1.4× the hero's bounty, growing with the wave number and the square root of the lair's `hp_mul`, but not with the threat, so doing well does not snowball into riches. Tap loot to pick it up at once; whatever is still lying on the map is gathered automatically when the next wave starts (on its timer or called early). In the last wave drops are taken the moment they fall.
- **The end:** after the last wave, the battle is won the moment its last hero falls or flees (an engine rolling away is not waited for); gems still rolling home count as home.
- **The den fights back:** your lair holds charges (1 to start). Each is a bolt it fires automatically at heroes within 2.6 tiles, gem carriers first, ignoring armour. Spent charges refill one every 8 s. The sparks circling above the cave show how many are ready.
- **Ratings and stars:** Survived ★ (you lost gems), Wicked ★★ (none lost, but a hero touched one, even if you got it back) and Brilliant ★★★ (no hero ever touched a gem).
- **Night missions:** clearing a level Brilliant unlocks the same level at night, with its own best rating and stars. Darkness is the challenge, so night heroes have 15% less health (`NIGHT_HP` in defs.gd). You can only build where you can see; the lair, your towers and your mines and wells light the ground around them. A moon on the map marks it: faint while locked, pale when open, gold once won.
- **Dark Arts** (skill tree, on the map): every star is a skill point to spend across the Hut, Crypt and Shrine trees, or on The Hoard: a den charge, +50 starting gold, +15 max mana or +25% meteor damage (Starfall) per point. The screen has one tab per tree (`Defs.SKILL_TREES`; a tree shows once it has skills), each listing its skills in tier sections. A skill may set `"tier"` (default 1); tiers open with the campaign, not with stars: tier II once 20 lairs are beaten (Chapter III reached), tier III once 40 are (Chapter V), and The Land tree once 10 are (Chapter II) (`Defs.TIER_BEATEN`, `Defs.TREE_BEATEN`; lairs beaten = `SaveData.lairs_beaten()`, one less than the lairs open). `SaveData.can_buy` checks the gate; beaten lairs stay beaten, so a refund never shuts a tier. A shut tier shows its header ("Opens in Chapter III") with its skills dimmed. "Omniscient" asks for every rank of every skill (`Defs.skill_points_all()`, 133). Stars come from each mission's best rating, day and night counted separately, so replaying a lair for a better rating earns more points. There is no player XP.

## Campaign

Fifty lairs, in five chapters of ten. Each lair turns one or two levers further than the last: the roads (how many, how long, whether they join), raised tiles, woods crowding the roads, which ground dominates, buildings and how many cuts they take, how many waves and heroes, which hero abilities appear, and hero health (`hp_mul`). Hero health is tuned last, with `tests/difficulty.gd`, so the bot's headroom falls smoothly from about ×3.5 on the tutorial to about ×1.15 on the finale, assuming the player spends about 2.4 stars per lair beaten in Dark Arts (`Bot.points_before`, not capped; `Bot.skills` buys `Bot.SKILL_ORDER` in order, passing over skills whose tier has not opened by that lair). From Chapter III the bot also takes masteries (alternating A and B by tile), opens a Sluice on boats or three heroes in its water, collapses bridges while no Diver is about, and from Chapter IV clears Rubble at once (the first action a buried tower offers) and razes Siege Workshops and Signal Fires, like barracks, before cutting woods (`tests/bot.gd`). Chapter achievements count lairs, not "every lair": "Crusade Crushed" is the first 20, and "Flawless Finale" and "Dawn Never Comes" are earned on the Hoard Throne itself (`Achievements.THRONE`), so they keep their meaning as chapters are added.

| # | Lair | File | Roads | Raised | Buildings (cuts) | Waves | What's new |
|---|---|---|---|---|---|---|---|
| 1 | Mossfold Pass | 01 | 2 | 0 | none | 12 | Tutorial |
| 2 | Rimewater Ford | 02 | 2 | 0 | mine, well (1) | 12 | Easy buildings; frost around the den |
| 3 | Gloamwood Hollow | 03 | 2 | 3 | barracks, mine, well (1) | 14 | Raised tiles, first barracks |
| 4 | Thornback Ridge | 09 | 1 long | 3 | barracks (2), mine, well (1) | 14 | Cutpurse; a building taking 2 cuts |
| 5 | Cinderfall Steps | 04 | 2 | 3 | barracks (2), mine, well (1) | 15 | Shieldbearer, Warden |
| 6 | Saltmarsh Crossing | 06 | 1 long | 3 | barracks, mine, well (2) | 14 | Fast swarms |
| 7 | Emberfen | 10 | 2 | 4 | barracks, mine (2), well (1) | 15 | Nearly all ash: raised tiles are the only Hut and Crypt ground |
| 8 | The Iron Column | 07 | 2, joined | 3 | barracks, mine, well (3) | 14 | Armour |
| 9 | The Three Gates | 11 | 3 short | 5 | barracks (3), mine, well (2) | 15 | Three roads, little time |
| 10 | Gloomspire Summit | 08 | 4 | 4 | 2 barracks, mine, well (3) | 16 | Four roads |
| 11 | Heraldmoor | 12 | 2, joined | 3 | barracks (3), mine, well (2) | 16 | Herald; thick woods |
| 12 | Frostfang Pass | 13 | 2 | 5 | barracks (3), mine, well (2) | 16 | Nearly all frost, against Wardens |
| 13 | Redwater Crossing | 14 | 2 long | 3 | 2 barracks, mine, well (2) | 16 | Berserker |
| 14 | The Sunken Abbey | 15 | 3 | 4 | 2 barracks (2), mine, well (3) | 16 | Every support hero at once |
| 15 | The Champion's Road | 16 | 1 long | 3 | 2 barracks (3), mine (3), well (2) | 17 | Champion |
| 16 | Ashen Maze | 17 | 2 | 7 | 2 barracks, mine, well (3) | 17 | Woods everywhere, many raised tiles |
| 17 | Howling Steppe | 18 | 3 | 1 | 3 barracks (4), mine, well (2) | 17 | Barracks-heavy, open ground |
| 18 | Lanternfall Vale | 19 | 4 short | 4 | 2 barracks, mine, well (3) | 18 | Every hero, four roads |
| 19 | The Last Bridge | 20 | 3, joined | 3 | 3 barracks, mine, well (3) | 18 | Three roads meet on one bridge |
| 20 | The Hoard Throne | 05 | 3 | 3 | 2 barracks (4), mine, well (3) | 20 | Finale: three Champions in the last wave |
| 21 | Reedmere Ford | 21 | 1 long, two fords | 2 | mine, well (2) | 14 | Water, fords, Fenwalker |
| 22 | Twin Bridges | 22 | 2, a bridge each | 3 | barracks, mine, well (2) | 15 | Collapsing bridges, Engineer |
| 23 | Rainmoor | 23 | 2 | 4 | barracks, mine, well (2) | 15 | Rainbringer; nearly all ash |
| 24 | The Sunken Causeway | 24 | 3 | 4 | barracks, mine, well (2) | 16 | Wave routes: odd waves the causeway, even waves the hill roads |
| 25 | Oarsmen's Reach | 25 | 1 land, 1 river | 3 | mine, well (2) | 16 | Longboat |
| 26 | Blackwater Fen | 26 | 2, long fords | 3 | barracks, mine, well (2) | 16 | Diver |
| 27 | Sluicegate | 27 | 1 land, 1 river | 3 | sluice, altar, mine, well (3) | 17 | Sluice Gate, Dark Altar; boats with Knight crews |
| 28 | Tidewrack Flats | 28 | 3 | 3 | barracks, mine, well (3) | 17 | Tide |
| 29 | The Flooded Abbey | 29 | 2 land, 1 river, a bridge | 3 | barracks, mine, well, altar (3) | 18 | A Champion arriving by boat |
| 30 | Maelstrom Gate | 30 | 2 land, 1 river | 4 | altar, sluice, mine, well (3) | 18 | Finale of Chapter III: the Tidecaller, tide and routes |
| 31 | Powder Road | 31 | 2 | 4 | mine, well (3) | 16 | Sapper, tower Stun: the raised tiles are the safe spots |
| 32 | The King's Highway | 32 | 1, the longest (18 wide) | 4 | barracks, mine, well (3) | 17 | Pavior; Heralds and Berserkers on paved road |
| 33 | Censer Vale | 33 | 2, joined | 3 | mine, well (3) | 17 | Inquisitor, Silence; thick woods, raised tiles out-range the smoke |
| 34 | Beacon Hill | 34 | 3 | 4 | Signal Fire (3 cuts), mine, well (3) | 17 | Signal Fire at the far edge |
| 35 | Stonefall Quarry | 35 | 2 | 3 | mine, well (3) | 18 | Trebuchet, Rubble; few build tiles |
| 36 | The Workshops | 36 | 2 | 3 | 2 Siege Workshops (4), barracks, mine (3) | 18 | Siege Workshop: a race against the engines |
| 37 | Duskwall | 37 | 2 | 3 | mine, well (3) | 18 | Dusk: night falls at wave 9 |
| 38 | Hollow Gate | 38 | 2, over a moat | 3 | mine, well (3) | 19 | Bridges and Engineers again, Sappers behind Shieldbearers |
| 39 | The Long Siege | 39 | 3 | 4 | 2 mines, well (3) | 22 | Endurance: 18 s gaps |
| 40 | The Iron Belfry | 40 | 1 long, 1 short | 4 | mine, well (3) | 20 | Finale of Chapter IV: the Iron Belfry on the long road, Trebuchets on the short one |
| 41 | Gryphon Aerie | 41 | 2 land, 2 air | 4 | mine, well (3) | 18 | Skylancer: flight lines cross open ground |
| 42 | Oathkeeper's Stair | 42 | 1 long, winding | 4 | barracks, mine, well (3) | 18 | Justicar |
| 43 | The Chapel Road | 43 | 2 | 3 | 2 Chapels, barracks, mine (3) | 19 | Chapel |
| 44 | Hallowed Fields | 44 | 2 | 3 | 2 Chapels, mine, well (3) | 19 | Hallowed ground: the best tiles, until both Chapels fall |
| 45 | The Reliquary | 45 | 3 short | 4 | mine, well (3) | 19 | Spiriter |
| 46 | Pilgrim's Flood | 46 | 1 land, 1 river, 1 air | 3 | sluice, mine, well (3) | 20 | Boats and flyers together |
| 47 | The Sun Gate | 47 | 2 | 3 | Chapel (4), mine, well (3) | 20 | Trebuchets guarded by Justicars; hallowed raised tiles |
| 48 | Eclipse | 48 | 3 | 4 | mine, well (3) | 20 | Eclipse: dark for 25 s in every 70 |
| 49 | The Last Procession | 49 | 4 land, 1 river, 2 air (18 wide) | 4 | barracks, mine, well (3) | 22 | Every hero; the waves walk through the chapters in turn |
| 50 | The Seraph's Descent | 50 | 3 land, 2 air | 5 | Chapel, barracks, mine, well (3) | 24 | Finale: Champions in waves 18 and 21, the Seraph in 24 |

## Open and play

1. Install [Godot 4.6](https://godotengine.org/download) (the standard build, not .NET).
2. In the Project Manager, choose **Import**, pick this folder's `project.godot`, then **Import & Edit**.
3. Press **F5** (or the ▶ button) to play on your computer. To start over, use **Reset progress** on the map (tap twice).

## How the project is organized

```
project.godot            engine settings (landscape, mobile-friendly renderer)
scenes/main.tscn         the one scene: map, level select, HUD layer
levels/level_NN.json     map grids, roads, starting gold, waves, intro text
scripts/
  data/defs.gd           all balance numbers: towers, heroes, spells
  core/level.gd          loads a level file
  core/save_data.gd      campaign progress, stars and skills, saved as JSON in user://save.json
  core/game_sim.gd       the rules of a battle (no drawing, testable)
  view/ground.gd         terrain, roads, woods, lair (redrawn only when woods are cleared)
  view/board.gd          towers, heroes, shots, effects (redrawn every frame)
  view/paint.gd          drawing helpers
  view/art.gd            towers, heroes and map buildings, drawn on any canvas (the board and the icons share them)
  view/bursts.gd         pooled, capped particle bursts (CPUParticles2D) for deaths, building, loot and meteors
  ui/game_icon.gd        round framed icons for heroes, towers, buildings, skills, spells and achievements
  ui/frames.gd           carved nine-patch frames for buttons and panels, drawn in code
  ui/hud.gd              stats bar, buttons, tile panel, start and end screens
  ui/level_select.gd     the campaign map (tap a lair to play it)
  ui/skill_tree.gd       Dark Arts, the skill tree
  ui/tutorial.gd         tips on the first lair, one at a time
  ui/guide_screen.gd     the Guide (topics on the left, a card on the right), opened from the map
  data/guide.gd          the Guide's topics and text
  ui/symbols.gd          drawn fallback glyphs (★ ● ○) so they show in browsers too
  audio/audio.gd         sound effects and music (autoload SfxPlayer, called as Sfx.play)
  core/prefs.gd          sound, music and tutorial settings in user://settings.cfg
  core/online.gd         optional account + leaderboard (Firebase Auth and Firestore over REST), login in user://account.cfg
  data/achievements.gd   the achievements and when each is earned
  ui/hall.gd             Hall of Fame: leaderboard, achievements, account, online races
  main.gd                connects everything, handles taps
tests/                   headless checks (see below); tests/fixtures/ holds test-only level files
assets/fonts/            Grenze Gotisch and Alegreya Sans (SIL Open Font License, see OFL.txt)
assets/audio/            sound effects and music, all made by tools/make_audio.gd
tools/make_audio.gd      synthesises every sound; edit it and run it to change them
```

**Tuning balance:** edit `scripts/data/defs.gd`.
**Chapter III difficulty** (tests/difficulty.gd, bot headroom, target ×1.6 falling to ×1.2): 21 ×1.64, 22 ×1.49, 23 ×1.52, 24 ×1.49, 25 ×1.44, 26 ×1.36, 27 ×1.39, 28 ×1.31, 29 ×1.26, 30 ×1.19. Heroes on a river road before its landing (a crew running back out) must swim. By night the bot loses Tidewrack Flats (it finds too few lit tiles off the water) and The Flooded Abbey.
**Chapter IV difficulty** (target ×1.5 falling to ×1.15): 31 ×1.49, 32 ×1.49, 33 ×1.41, 34 ×1.39, 35 ×1.31, 36 about ×1.45 (hp_mul 1.55; at 1.70 it measured ×1.35 but its seeds swing from ×0.9 to ×1.8, so it was eased until the bot wins every seed), 37 ×1.22, 38 ×1.19, 39 ×1.15, 40 ×1.15. Hero health spreads widely (The Long Siege 1.13, The King's Highway 4.36) because the levers do: 22 waves with Trebuchets against one long road. By night the bot loses Stonefall Quarry.
**Chapter V difficulty** (target ×1.4 falling to ×1.1): 41 ×1.36, 42 ×1.39, 43 ×1.34, 44 ×1.26, 45 ×1.24, 46 ×1.17, 47 ×1.19, 48 ×1.19, 49 ×1.31, 50 ×1.11. The Last Procession has a cliff: ×1.13 at hp_mul 1.72 (and the bot loses its seed-0 battle there) but ×1.31 at 1.69, so it stays a little easier than its neighbours. By night the bot loses The Sun Gate.
**The whole curve** (tests/difficulty.gd on all 50 lairs, 2026-11-15): I 3.40, 2.52, 2.25, 2.13, 1.52, 1.55, 1.98, 1.64, 1.52, 1.39; II 1.36, 1.39, 1.31, 1.20, 1.09, 1.13, 1.19, 1.11, 1.03, 1.09; III 1.64, 1.49, 1.52, 1.49, 1.44, 1.36, 1.39, 1.31, 1.26, 1.19; IV 1.49, 1.49, 1.41, 1.39, 1.31, 1.47, 1.22, 1.19, 1.15, 1.15; V 1.36, 1.39, 1.34, 1.26, 1.24, 1.17, 1.19, 1.19, 1.31, 1.11. Each chapter starts a little easier and ends harder; measure it again after any balance change.

**Chapter III, IV and V lairs** are generated from compact specs: `tools/lair_specs.gd` (ground and water as rectangles, raised tiles, roads, buildings, waves, rules) and `godot --headless --path . -s res://tools/make_lairs.gd -- 25` (just lair 25; no numbers for all). Woods are scattered from a seed, never on roads, water, buildings, raised tiles or next to the lair. A tuned `hp_mul` already in the file is kept. New lairs have no music until the owner picks a track (`MUSIC` falls back to silence).

**Adding a level:** copy a level file, give it a new `id`, edit it, and add its path to `LEVELS` in `scripts/main.gd`. `LEVELS` is the campaign order; file numbers only say when a map was made, so ids (and players' saved stars) never move when lairs are reordered. The map shows ten lairs a chapter (`PER_PAGE`, `SPOTS` and `CHAPTERS` in `scripts/ui/level_select.gd`); every chapter zigzags left to right, entering from the previous chapter at the left edge and leaving for the next at the right (chapter buttons sit beside the heading). A lair's name gets at most the room halfway to its neighbours on the same row (`Marker.room`): it shrinks a little to stay on one line, and only wraps to two lines (shrinking down to 18) when it must. Optional `intro` story text is kept in the file but not shown. Check the new lair with `tests/difficulty.gd` (below) so it fits the curve.
In the level file, `terrain` uses `m` moss, `f` frost, `a` ash and `L` lair; a capital `M`, `F` or `A` is a raised tile of that ground. Add `"hp_mul": 1.4` to make heroes tougher on a later level. `"night": true` makes a level night-only (normally night is the unlockable mission). `sites` lists map buildings: `{"kind": "mine"|"well", "cell": [x, y]}` or `{"kind": "camp", "cell": [x, y], "path": 0, "spawn": "2p,1f", "every": 30}` (a `"workshop"` takes the same keys: `Defs.MUSTER_SITES`), `{"kind": "beacon", "cell": [x, y]}` (a Signal Fire), `"sluice"` (with `"path"`) or `"altar"`; any building can add `"cuts": 3` to override the level's `site_cuts`. In `trees`, `T` marks woods. `paths` lists each road's corner tiles; roads start off the map edge and end next to the lair. Waves use hero codes: `p` peasant, `f` footman, `s` scout, `c` cleric, `k` knight, `b` shieldbearer, `t` cutpurse, `w` warden, `h` herald, `r` berserker, `x` champion, then `m` Fenwalker, `e` Engineer, `q` Rainbringer, `l` Longboat, `d` Diver and `T` the Tidecaller, then `a` Sapper, `v` Pavior, `i` Inquisitor, `u` Trebuchet and `I` the Iron Belfry, then `y` Skylancer, `j` Justicar, `n` Spiriter and `S` the Seraph. For example, `"6p,2f"` is 6 peasants and 2 footmen.

**Level format v2** (all keys optional; old files load unchanged, `tests/fixtures/level_v2.json` uses every one):

- **Terrain letters** `w` (deep water) and `o` (shallows) need no legend entry. Nothing is built on water and woods cannot stand there.
- **Marks** in `trees`: `T` woods, `H` hallowed ground (`Level.hallowed`).
- **`path_info`**: parallel to `paths`, each `{"kind": "land" | "river" | "air"}` (missing = land). Heroes are dealt only over land roads (`Level.land_roads`). River roads must enter the map on water and reach a landing (`Level.landing`). If a wave has flyers (`"fly"` in `Defs.ENEMIES`) and the level has no air road, one straight air road is added per land road, from its start to the lair centre.
- **Wave objects**: a wave may be `{"heroes": "6p,2f", "roads": [0, 2], "cargo": {"2": "2k,1c"}}`. `roads` limits the wave to those roads; its walkers are dealt round-robin over the land roads among them (`Level.wave_walk`), and without `roads` over every land road, as before. `cargo` maps a river road to the heroes its boats carry (`Level.wave_cargo`).
- **`rules`**: lair rules such as `[{"kind": "tide", "period": 40, "up": 14}, {"kind": "dusk", "wave": 9}]` (`tide`, `dusk`, `eclipse`), read into `Level.rules`. `dusk` must name a later wave (`level_check`); `eclipse` (`{"kind": "eclipse", "period": 70, "dark": 25}`) darkens the last `dark` seconds of every `period`.
- **`start.gems`** may be 5 to 7.

**Road zones:** at load each road is sampled every 0.1 tile and split into zones (`Level.zones`): a **ford** where it crosses shallows, a **bridge** where it crosses deep water. `GameSim._zone_mul` is the one place hero speed changes with the ground: a ford slows to 70% and soaks; a flooded ford (`GameSim.tide_up`) or a collapsed bridge (`GameSim.collapsed`, by water tile) is swum at 40% with no Herald haste; paving (`GameSim.paved`, stretches per road) speeds up 25% (`Defs.ZONE_SPEED`). **Soaked** lasts while in water and `SOAK_TIME` (4 s) after: Crypt chill lasts 1.5× longer and a Shrine heats at 0.6× speed. Lava never forms on water. In races, heroes marked `no_send` (the Champion) are not in the Send shop, and `send_as` names what their kills send instead.

## Tests

From this folder, with Godot on your PATH:

```
godot --headless --import
godot --headless --script res://tests/sim_test.gd     # the bot (tests/bot.gd) plays every lair by day and at night, with the skill points a player would have by then; prints each battle as it ends
godot --headless --script res://tests/sim_test.gd -- 6 7  # just those campaign lairs, without and with skills
godot --headless --script res://tests/sim_test.gd -- --chapter 2  # one chapter of ten, day and night (difficulty.gd takes --chapter too)
godot --headless --script res://tests/difficulty.gd    # how much headroom the bot has on each lair (the difficulty curve)
godot --headless --script res://tests/level_check.gd  # level files: grid sizes, woods on roads, roads reaching the lair, v2 keys
godot --headless --script res://tests/level_v2_test.gd  # level format v2 and road zones on tests/fixtures/level_v2.json, Dark Arts tiers
godot --headless --script res://tests/water_test.gd     # Chapter III rules: boats, bridges and Engineers, Fenwalkers, Divers, rain, the Tidecaller, the Tide, Sluice and Altar
godot --headless --script res://tests/siege_test.gd     # Chapter IV rules on tests/fixtures/level_siege.json: Sappers, Paviors, Inquisitors, Trebuchets, the Iron Belfry, Sturdy Foundations, Signal Fire, Siege Workshop, Dusk
godot --headless --script res://tests/radiant_test.gd   # Chapter V rules on tests/fixtures/level_radiant.json: flyers, Justicar, Spiriter, Seraph, Chapel and hallowed ground, Eclipse, seven gems, tier III
godot --headless --script res://tests/save_test.gd    # unlocking, ratings, stars as skill points, loot, damaged save files
godot --headless --script res://tests/scene_test.gd   # boots the real scene, taps tiles, casts spells, plays the night level
godot --headless --script res://tests/tower_test.gd   # the three tower types side by side against set groups of heroes
godot --headless --script res://tests/tutorial_test.gd  # the first-lair tips: where they point and how they move on
```

The online test runs against the local Firebase emulators (needs Java 21+), never the real project:

```
firebase emulators:exec --only auth,firestore "godot --headless --path . -s res://tests/online_test.gd"
```

## Leaderboard and accounts

Firebase project `gemhold`: **Authentication** (Email/Password) for accounts and **Firestore** for the leaderboard. Each signed-in player has one document `players/<uid>` with `name`, `total` (sum of best scores), `stars`, `scores` (best per mission; night keys end in `_night`) and `ach` (achievement ids), plus the campaign when `Online.SYNC_PROGRESS` is on: `unlocked`, `best`, `skills`, `skills_t`, `reset_t` and `stats`. Every upload first pulls the document and merges it (`SaveData.merge_online`): the best of each value, the newest whole Dark Arts build (never mixed, so it always fits the stars), and an Erase progress spreads via `reset_t`. A device's save belongs to the first account that signs in on it (`owner` in `user://account.cfg`, kept after sign-out, cleared by deleting the account); a different account gets a clean slate and the old progress waits in `save_<uid>.json` until its owner returns (`SaveData.switch_owner`). `SYNC_PROGRESS` needs the rules deployed; clients from before it remove the campaign fields when they upload, until a newer client writes them again. Anyone can read it; only its owner can write it (`firestore.rules`). Change the rules, then deploy them with `firebase deploy --only firestore:rules`. The web API key in `online.gd` is public by design. Scores are reported by the game, so a player who edits their save could fake one: fine for friends; delete a bad document in the Firebase console.

**Online races** (Hall of Fame → Race): a host opens `races/<code>` (5 letters from `Online.RACE_LETTERS`) with `host`, `host_name`, `level`, `state: "open"`, `created` and its progress `h`; a guest joins once, writing `guest`, `guest_name`, `g` and `state: "on"`; after that each racer may write only their own progress map (`{wave, gems, kills, score, done, won, time, out}`, `Online.race_progress`). Both clients poll every 2–2.5 s (main.gd `_race_tick`, hall.gd while hosting). Races run with the lair's standard Dark Arts for both racers (`Loadout.for_lair`, the set the lair's hero health is tuned for; without skills nobody could win lair 11 or later) and no tutorial, by day or (`night: true`) at night, and end for both the moment one racer is done: the other is stopped (`GameSim.race_stop`, `stopped: true` in their progress). Each result is counted once in `stats` (`race_wins`, `race_losses`, `race_draws`; leaving early is a loss) and uploaded as `rw`/`rl` on `players/<uid>` for the "Races: most wins" board; on sign-in the larger of local and online counts is kept. `time` is wall-clock seconds since the race began, frozen at the finish (pausing is replaced by Send, so the clock is fair). `out` lists the hero codes sent so far: one per `Defs.RACE_KILL_SEND` kills (like the hero just slain; a Champion sends a Knight) plus any bought with Send (`RACE_SEND_COST` × bounty); the rival spawns the new ones at a road start (`GameSim.race_receive`). `Online.race_compare` decides the winner: survivor > stopped > fallen; survivors by race points (score + `RACE_TIME_BONUS` per second finished before the rival), then gems, then kills; fallen by waves, then kills. Finished races are left in Firestore (a TTL policy on `created` could clear them).

## Putting it on your Android phone

The Android tools live in `tools/` next to this folder (on this PC: `Desktop\Gemhold\tools`):
Godot 4.6.2, JDK 17 (`jdk-17`) and the Android SDK (`android-sdk`: platform-tools,
build-tools 35.0.1, Android 36). Godot's export templates are installed, and its editor settings
point at the JDK and SDK. On a new PC, set **Editor > Editor Settings > Export > Android**
(Java SDK path and Android SDK path) and install templates from **Editor > Manage Export Templates**.

Build a debug APK (the Android preset exports `com.fildim.gemhold`, 64-bit ARM, landscape):

```
godot --headless --export-debug "Android" build/gemhold.apk
```

Install it on your phone:

1. On the phone: **Settings > About phone**, tap **Build number** 7 times, then turn on
   **Developer options > USB debugging**.
2. Plug the phone in and allow the computer when it asks.
3. `../tools/android-sdk/platform-tools/adb install -r build/gemhold.apk`

Or, with the phone plugged in, press the small Android button in the editor's top-right bar.
Debug builds are signed with Godot's debug keystore and are only for testing.

## Full-game codes

Demo builds (exports with the `demo` feature: GitHub, web, Steam demo) stop after `Edition.DEMO_LAIRS` lairs. A full-game code, typed under **Info** on the map, unlocks the rest for good on that device (`Prefs` key `full`). The game holds only SHA-256 hashes of the codes (`scripts/data/unlock_codes.gd`); the codes themselves are kept outside this public repository. Make more with `godot --headless --path . -s res://tools/make_codes.gd -- 50 "<private codes file>"`, which appends the codes to that file and their hashes to `unlock_codes.gd`; they work from the next published version. A code is not tied to a person, so a shared one keeps working until its hash is removed. When the player is signed in, the unlock is also kept on their account (`full: true` on `players/<uid>`) and unlocks every device they sign in on.

## Google Play

The **Android Play** export preset builds the store file: a Gradle build, `.aab` format, target SDK 36 (Play has required API 36 since August 31, 2026). The plain **Android** preset stays a quick debug APK for Firebase testers and CI.

- **Build template:** `android/build/` is not in git. Godot installs it on the first Play export with `--install-android-build-template`.
- **Upload key:** `Desktop\Gemhold\Play key\gemhold-upload.jks` (alias `upload`; the password is in the README next to it). Keep backups. Never commit it. Godot reads it from environment variables, so no password goes in `export_presets.cfg`:

  ```bash
  export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="C:/Users/fil/Desktop/Gemhold/Play key/gemhold-upload.jks"
  export GODOT_ANDROID_KEYSTORE_RELEASE_USER=upload
  export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=...   # from the README
  godot --headless --path . --install-android-build-template --export-release "Android Play" build/gemhold-X.Y.Z.aab
  ```
  The first build downloads Gradle (about 10 minutes). Bump `version/code` in **both** Android presets each release. Play rejects a code it has already seen.
- **Store pages:** `site/privacy.html` and `site/delete-account.html` are copied into the GitHub Pages build by `web.yml`. They are live at `fildim.github.io/gemhold/privacy.html` and `/delete-account.html`. Play requires both: Gemhold has accounts, so players must be able to delete them outside the game too.
- **Icon:** `icon.svg` is the main icon. Android uses separate layers in `assets/icons/` (background, foreground scaled into the safe circle, monochrome, legacy 192). Re-render them when the icon changes.
- **Listing text, graphics and Play Console answers:** `Desktop\Gemhold\Play store\`.
- **Rules:** new personal accounts must run a closed test with 12+ testers for 14 days before going public. Keep the art and name original.

## Roadmap toward Cursed Treasure 2–level depth

- [x] Save system: unlocked levels, best rating per level
- [x] Level select map
- [x] Levels 2–5
- [x] Skill tree: stars (1–3 per mission) are the skill points
- [x] Towers rank up from damage; abilities (Volley, Dread, Lava)
- [x] Raised tiles that give towers extra range
- [x] Mana wells and gold mines freed by cutting; hero barracks that spawn troops
- [x] Loot drops (coins, potions)
- [x] Night missions, unlocked by a Brilliant clear: build only where you can see
- [x] Three ratings: gems lost, gem touched, untouched
- [x] New heroes: Shieldbearer, Cutpurse, Warden
- [x] Twenty lairs in two chapters, tuned to a smooth difficulty curve (`tests/difficulty.gd`)
- [x] Chapter II heroes: Herald, Berserker, Champion
- [x] Sound effects and music
- [x] Tutorial tips on the first lair
- [x] Builds for Windows, macOS, Linux, Android, iPhone and the web

## Publishing a new version

Raise the version in `export_presets.cfg` (Android `version/*`, Windows `application/*_version`, macOS and iOS `application/short_version` and `application/version`) and `project.godot`, commit, then tag and push:

```
git tag v0.4.0
git push origin main v0.4.0
```

GitHub Actions (`.github/workflows/release.yml`) then builds every platform and publishes them as one release; the README's download buttons always point at the newest one. The web version is separate (`.github/workflows/web.yml`): every push to `main` rebuilds it on GitHub Pages, because Pages only accepts deployments from the default branch.

**One-time setup** (repository settings on github.com):

- **Web version:** Settings > Pages > Build and deployment > Source: **GitHub Actions**. (Done for this repository.)
- **Android APK in releases:** Settings > Secrets and variables > Actions > New repository secret, named `ANDROID_DEBUG_KEYSTORE`, holding the debug keystore as base64 (`base64 -w0 debug.keystore`). It's the same key the Firebase test builds use, so the APK installs over them. Without the secret the release has no APK.

## iPhone app

Apple only lets apps onto an iPhone through the App Store, TestFlight or a signed install, and signing normally needs the $99/year developer program. The free options:

1. **Browser (easiest):** open [fildim.github.io/gemhold](https://fildim.github.io/gemhold/) in Safari, then Share > **Add to Home Screen**. It runs full screen from its own icon, offline after the first visit.
2. **Sideload the app:** every release includes `Gemhold-iOS-unsigned.ipa`, built on a GitHub Mac. Install [AltStore](https://altstore.io) or [Sideloadly](https://sideloadly.io) on a Windows PC or Mac, sign in with any free Apple ID, and install the IPA with the iPhone plugged in. With a free Apple ID the app stops opening after 7 days until you install it again from the computer (AltStore can refresh it over Wi-Fi). Turn on **Settings > Privacy & Security > Developer Mode** on the iPhone when it asks.

With a paid Apple developer account, the same workflow could sign the build and send it to TestFlight.

## Graphics

Everything is drawn in code; there are no sprite files. `view/art.gd` (`Art`) holds the figures (towers, heroes, map buildings) and draws them on any canvas, so the board and the icons always show the same picture.

- **Motion (G1):** the rules stay free of drawing, but carry a few view-only fields and one signal: `Enemy.hit` and `Enemy.knock` (hit flash and a small knock-back from Hut and Crypt hits), `Tower.born` (towers squash and settle after being built or upgraded) and `GameSim.burst(kind, pos, code)`, which `view/bursts.gd` turns into particles: dust and scraps where a hero falls, dust when a tower goes up, sparks for loot picked up, debris from a meteor. Emitters are pooled and capped (`MAX_EMITTERS` × `MAX_AMOUNT`). Meteors also leave a `shock` ring and a `scorch` decal (`Fx` kinds) and shake the screen for 0.35 s (`main.gd`, Prefs `shake`, the switch in Settings). Shots leave trails, dropped coins pop up, and floating text pops in and eases out.
- **Icons and frames (G4):** `ui/game_icon.gd` (`GameIcon.make(key, px, lit)`) draws a round framed icon for `hero:<code>`, `tower:<type>`, `site:<kind>`, `skill:<id>`, `spell:meteor`, `ach:<id>` (achievements map to a picture by id in `ACH` and `ACH_PREFIX`) or a plain glyph name. They show on Hall of Fame achievement cards, Dark Arts skill buttons, Guide topics (`Guide.ICONS`) and the Meteor button. `ui/frames.gd` (`Frames.carved`) draws the carved nine-patch the theme uses for buttons and panels. The campaign map is an old map on dark parchment, with ink sketches for each chapter (`level_select.gd`, `_draw_parchment`).
- **Ground and water (G2):** `ground.gdshader` takes both masks as uniforms (`terrain_mask`, `water_mask`: r deep, g shallows) and a `biome` per chapter (0 lowland, 1 the crusade's warmer autumn, 2 the dark, wet marsh; `main.gd` sets `ground.biome`). Water is drawn into the baked ground; `water_fx.gdshader` adds moving light on one quad over the map (no redraw). Roads over water: plank bridges with rails (broken stumps once collapsed), stepping stones on fords, no dirt track on rivers before the landing. Reeds grow along the shore.
- **Sprites, light and status looks (G3):** `view/hero_sprites.gd` (`HeroSprites`) bakes every hero's walk cycle (8 frames, 1.5× board size, facing right) into one atlas at start-up by drawing `Art.hero` into a `SubViewport`; the board then draws each hero as one picture (mirrored when walking left) on a child layer that sits behind the board's own drawing (`show_behind_parent`) and blends `PREMULT_ALPHA`, because a SubViewport's transparent output is premultiplied. Health bars, chill, Dread, carried gems and the like still go on top. The hit flash draws the same picture again with an over-bright modulate (clamped to white); heroes in the Belfry's shadow are tinted dark. Trebuchet and Belfry are not baked (their looks follow what they are doing). Headless runs never bake, and until the atlas is ready the board draws heroes shape by shape as before. Heroes are drawn 20% larger than their body radius (`Board.HERO_SCALE`). **Night** is a soft light map instead of the old one-pixel-per-tile fog: `GameSim.lights` (den, towers, freed buildings) each clear a soft-edged pool at 4 px a tile, with a warm glow, and the darkness fades in over `DUSK_FADE` after Dusk. The plan suggested `PointLight2D` and a `CanvasModulate`; the light map was kept because Compatibility caps lights per canvas item (the ground is one item, a lair can have thirty towers) and because it shows the build rule tile for tile. Status looks: Rubble is a heap of stones with dust, Stun is smoke with circling sparks, Silence is pale motes drifting down (and no ability ring); a Sapper's lit fuse sparks, an Inquisitor's censer ring and paved road (cobbles that fade) are drawn on the ground; `Fx` kinds `stone` (a Trebuchet's stone in flight) and `smoke`. Chapter IV's `biome` 3 is churned brown mud. The map's Chapter IV page has palisade, castle and siege-engine sketches. Chapter V: flyers have feathered wings (`Art._wings`) and fly above their shadow, flight lines are faint dashed lines that drift toward the den (`Board._draw_sky`, and `ground.gd` draws no dirt track for air roads), hallowed tiles glow pale gold while a Chapel stands, untouchable heroes shine inside a gold ring, a chanting Spiriter has a blue ring that closes in, `biome` 4 is pale sunlit gold, and the map page has chapel spires, suns and wings.
- **Checking:** frame time was measured windowed at 1720×720 on the PC: a battle averaged 21.4 ms a frame before G1/G4 and 21.7 ms after. Phase 3 (lair 40, 38 heroes and 25 towers, vsync off, 1720×720 on the PC): 30.1 ms a frame with baked heroes, 45.7 ms drawing them shape by shape. Not yet measured on a phone. Check on an Android phone before publishing.

## Sound

Sound effects are synthesised by `tools/make_audio.gd` (oscillators, noise and plucked strings). The music is public-domain, CC0 and CC-BY (credited in the Guide) orchestral tracks from Wikimedia Commons and OpenGameArt.org in `assets/music/` (sources and licences in `assets/music/CREDITS.md`), looped in `audio.gd`. The level map plays Matthew Pablo's *Dark Descent*, and each lair has its own piece (`MUSIC` in `main.gd`, keyed by level id):

| Lair | Music |
|---|---|
| 1 Mossfold Pass | Grieg, *In the Hall of the Mountain King* |
| 2 Rimewater Ford | Kevin MacLeod, *Heroic Age* |
| 3 Gloamwood Hollow | Kevin MacLeod, *Curse of the Scarab* |
| 4 Thornback Ridge | Kevin MacLeod, *Prelude and Action* |
| 5 Cinderfall Steps | Kevin MacLeod, *Volatile Reaction* |
| 6 Saltmarsh Crossing | Kevin MacLeod, *Crusade* |
| 7 Emberfen | Kevin MacLeod, *Firebrand* |
| 8 The Iron Column | Beethoven, *Symphony No. 5* |
| 9 The Three Gates | Kevin MacLeod, *Killers* |
| 10 Gloomspire Summit | Kevin MacLeod, *Five Armies* |
| 11 Heraldmoor | Kevin MacLeod, *Rynos Theme* |
| 12 Frostfang Pass | Kevin MacLeod, *Darkling* |
| 13 Redwater Crossing | Kevin MacLeod, *Malicious* |
| 14 The Sunken Abbey | Kevin MacLeod, *Ossuary 2 - Turn* |
| 15 The Champion's Road | Kevin MacLeod, *Unholy Knight* |
| 16 Ashen Maze | Kevin MacLeod, *Black Vortex* |
| 17 Howling Steppe | Emma_MA, *QaziJamJam* (CC0) |
| 18 Lanternfall Vale | Kevin MacLeod, *Final Battle of the Dark Wizards* |
| 19 The Last Bridge | skrjablin, *The Final Battle* (CC0) |
| 20 The Hoard Throne | Wagner, *Ride of the Valkyries* |

To swap a piece, drop an .ogg (its most intense 2:30, normalised to -14 LUFS) into `assets/music/` (cut with ffmpeg; tracks still waiting for a lair are in `Desktop\Gemhold\Music to try`, and a track's source is deleted from there once it is in the game), put its name in `MUSIC` and add it to CREDITS.md. To change a sound effect, edit its function in `tools/make_audio.gd` and rebuild:

```
godot --headless -s res://tools/make_audio.gd -- coin boom   # just these, or no names for all
godot --headless --import
```

Volumes and how often each may repeat are in `SFX` at the top of `scripts/audio/audio.gd`. The music and the Shrine's crackle loop; that is set in their `.wav.import` files (`edit/loop_mode=2`).
