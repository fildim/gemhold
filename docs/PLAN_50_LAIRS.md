# Gemhold: the road to 50 lairs

Design plan, written 2026-11-13 against v0.8.10 (20 lairs, 11 heroes, 3 towers, 59 Dark Arts points, 229 achievements). It is meant to be handed to an implementer who has not seen the discussion behind it. Read `docs/DEVELOPMENT.md` first: it describes the game as it is today, the level format, the tests and how to publish.

The plan adds three chapters of ten lairs (21–50), fifteen new heroes, a fourth tower level with two masteries per tower, water, new map buildings, a larger Dark Arts tree, about 80 achievements and a graphics upgrade. It is split into five phases that can each ship as a version.

## 1. Rules the design must keep

These are decisions the owner has already made. Do not change them while implementing.

- **Three towers, different but equal.** Hut = fast and light, blunted by armour. Crypt = slow and heavy, chills. Shrine = one beam that ignores armour and heats up. Nothing new may make one tower the best overall; check every tower change with `tests/tower_test.gd`.
- **Raised tiles take any tower** and give a per-type range bonus.
- **Threat never falls** and is never shown.
- **Abilities need veteran rank 3 and upgrade level III.** Ranks stay hidden.
- **Every lair starts with 230 gold.** Kills give no mana. When in doubt, harder rather than easier, but never hopeless.
- **Level ids never change** (saves and leaderboards are keyed by them). New files are `level_21.json` … `level_50.json`, appended to `LEVELS` in campaign order.
- **Text stays big** (the owner plays on Android). The start card stays short: no story, no rule list. New rules are taught by spotlight tips, like buildings and heroes are today.
- **Names and art are original.** Take mechanics from the genre, never names, characters or looks from another game.
- **README is for players only.** Rules go in the in-game Guide (`scripts/data/guide.gd`) and `docs/DEVELOPMENT.md`; update both in every phase.
- After any gameplay change, rebuild `build/windows/Gemhold.exe`. Commit locally; push, tag, upload and deploy Firestore rules only when the owner says so.

## 2. What other games do well, and what Gemhold takes from it

| Source | Idea | Used here as |
|---|---|---|
| Kingdom Rush series | Two-way tower specialisation at the top level; bosses that stun towers; Heroic/Iron challenge stages | Masteries (§5); Sapper, Trebuchet, boss abilities (§4) |
| Cursed Treasure 2 | Champion that weakens nearby towers; speed-buffing bard; invisible ninja; fear spell | Inquisitor aura; Diver (hidden only in water); no new spells (§6) |
| Bloons TD 6 maps | Water areas, removable obstacles, paths that alternate by round, a map that changes over time | Water and fords; wave routes; Tide and Dusk lair rules (§3) |
| Infinitode 2 / TD Simulator | Healers and shields as priority targets; immunity to one damage style | Rainbringer completes the counter triangle: armour vs Hut, Warden vs Crypt, Rainbringer vs Shrine |
| Defender's Quest (Lars Doucet's design posts) | Every enemy must read at a glance and have one clear role | One new rule per hero, a distinct silhouette and a first-sight tip for each |
| Genre in general | Splitters and carriers that spill units; flyers that ignore the road | Longboat (sink it before it lands); Skylancer |

Rejected on purpose: enemies that permanently destroy towers or take away veterancy (feels unfair with a rising threat), random tower malfunctions, pay-to-skip mechanics, and a fourth tower type (it would break "three equal towers").

## 3. New systems

Build these as data-driven extensions of what exists: flags in `Defs.ENEMIES`, kinds in `Defs.SITES`, optional keys in the level JSON. All rules live in `scripts/core/game_sim.gd` so they stay testable headless. Numbers below are starting points; tune them with the tests in §11.

### 3.1 Level format v2 (backwards compatible)

Old files must load unchanged. New optional keys:

- **Wave objects.** A wave may be a string (as now) or `{"heroes": "6p,2f", "roads": [0, 2], "cargo": {"l": "2k,1c"}}`. `roads` limits the wave to those road indexes; without it, heroes are dealt round-robin over all land roads as now.
- **`path_info`**: an array parallel to `paths`, each `{"kind": "land" | "river" | "air"}`. Missing = land. River roads carry only boats. Air roads carry only flyers; if a level has flyers and no air road, generate one straight line per land road from its start to the lair centre.
- **Terrain letters** `w` (deep water) and `o` (shallows). Nothing is built on either and woods cannot stand there.
- **Marks** in the `trees` grid: `T` woods (as now), `H` hallowed ground (§3.6).
- **`rules`**: a list of lair rules, e.g. `[{"kind": "tide", "period": 40, "up": 14}, {"kind": "dusk", "wave": 9}]`.
- **`start.gems`** may be 5 to 7.

`tests/level_check.gd` must learn every new key: river roads lie on water tiles and end at a landing; boats only appear in waves that include a river road; `roads` indexes exist; hallowed tiles are buildable ground; every site kind is known.

### 3.2 Road zones

At load, sample each road every 0.1 tile and record zones `{from, to, kind}` by the tile under the sample:

- **Ford** (road over shallows): heroes walk at 70% speed and are **Soaked** while in it and for 4 s after. On a Soaked hero, Crypt chill lasts 50% longer and Shrine heat builds at 60% speed. Lava pools cannot form on water.
- **Bridge** (road over deep water): a normal road, but the player can **Collapse** it (40 mana, tile action on the bridge). Heroes then swim the gap at 40% speed, Soaked, and a Herald cannot haste them. An Engineer repairs it (§4). Each later collapse of the same bridge costs 20 mana more.
- **Paved** (laid by a Pavior, §4): +25% hero speed.

Zones are the single place speed modifiers are looked up, so tide, planks and paving are just zone state changes.

### 3.3 Water

Water is the theme of Chapter III and returns later. It is drawn by a second mask texture in the ground shader (`r` deep, `g` shallows; `b` and `a` spare) with an animated ripple layer on top (§8). While adding the second sampler, declare both masks as uniforms instead of passing `TEXTURE` into functions: that also removes the shader error the headless tests print today.

River roads end at a **landing** (the first sample not over water). Dropped gems float home at the usual speed. Loot that falls in water behaves as on land.

### 3.4 Tower statuses

Towers can be hindered, never destroyed:

| Status | Caused by | Effect | Ends |
|---|---|---|---|
| Stunned | Sapper blast, Iron Belfry | No firing; beam and heat drop | After 7 s |
| Silenced | Inquisitor aura | Ability off, veteran damage bonus off, 30% slower fire or heating | When he leaves or dies |
| Rubble | Trebuchet stone | No firing | After 9 s, or at once with **Clear rubble** (15 gold, tile action) |

The tile panel names the status and what causes it. Each has its own look (§8). Towers on raised tiles cannot be reached by Sappers; that gives raised tiles a second use. Clear rubble from the tile panel; Stun wears off.

### 3.5 New map buildings

All use the existing cut system (`cuts`, `site_cuts`) and get a first-sight tip.

| Kind | Side | Effect | Cut |
|---|---|---|---|
| `altar` Dark Altar | Yours once freed | Towers within 2.2 tiles: +10% damage and rank up 20% faster | 30 mana |
| `sluice` Sluice Gate | Yours, reusable | Flood surge down its river or ford road: heroes in water zones are pushed back 2 tiles and take 120 damage through armour, boats take triple. Recharges in 45 s | 35 mana per use |
| `chapel` Chapel | Heroes | Heals heroes within 2 tiles (10 health/s × the lair's `hp_mul`). Keeps hallowed ground active | 60 mana, +30 gold |
| `beacon` Signal Fire | Heroes | While it stands, waves come 4 s sooner and barracks muster 25% faster | 50 mana, +30 gold |
| Workshop | Heroes | A barracks (`camp`) with `"look": "workshop"` that musters a Trebuchet every 60 s | as camp |

### 3.6 Lair rules

Each is taught by a tip the first time it appears.

- **Tide**: every `period` seconds the water rises for `up` seconds. Fords become deep (swim speed, like a collapsed bridge). A small tide clock sits beside the wave timer.
- **Routes**: not a rule key, just waves with `roads`. The HUD shows which roads the next wave will use (lit road starts), so the player can prepare.
- **Dusk**: at wave N a day mission turns to night (the existing light rules switch on, with a 3 s fade). The lair's night mission is dark from the start.
- **Eclipse**: darkness comes and goes on a timer (`period`, `dark`).
- **Hallowed ground** (`H` marks): towers standing on it have 20% less range and cannot use their ability until every Chapel in the lair is razed. The tiles glow pale gold until then.
- **Seven gems**: `start.gems` 6 or 7 on a few lairs. More to guard, more to lose.

## 4. New heroes

Twelve heroes and three bosses. Each has one rule, one counter, and a silhouette a player can read at phone size. Codes are single characters; bosses use capitals. Add each to `Defs.ENEMIES`, `Defs.HERO_TIPS`, `TUNIC` colours and drawing in `board.gd`, the Guide, and the race shop rules (boats, flyers, siege engines and bosses cannot be sent to a rival: flag `no_send`).

### Chapter III: the Drowned Marches

| Code | Hero | Health / speed / armour / gems / bounty | Rule | Counter |
|---|---|---|---|---|
| `m` | Fenwalker | 70 / 1.15 / 0 / 1 / 8 | Water does not slow or soak him; he swims collapsed bridges at full speed | Kill him on dry land; do not rely on fords |
| `e` | Engineer | 110 / 0.85 / 1 / 1 / 14 | Repairs a collapsed bridge (stands 4 s at the bank) and lays planks on a ford he crosses alive (no slow or soak for 40 s). Special target | Towers aim for him first; cover the bank |
| `q` | Rainbringer | 100 / 0.8 / 0 / 1 / 14 | A rain cloud 1.5 tiles wide: Shrine beams on heroes inside never heat past 35%, and Lava is put out. Special target | Arrows and bolts; a Shrine that reaches him before the crowd |
| `l` | Longboat | 520 / 1.25 / 2 / 0 / 20 | River roads only. Chill and Dread do not work on it. At the landing its crew steps ashore (default `"4f"`, set per wave with `cargo`). Sunk on the water, the crew drowns: you get their bounties and kills | Sink it early: towers along the river, Sluice, Meteor |
| `d` | Diver | 60 / 1.0 / 0 / 1 / 10 | Hidden from towers and the den while in a ford, a collapsed bridge or tide water (a ripple and a reed show where he is). Meteor and Sluice still hit | Guard the far bank; do not collapse a bridge when Divers are coming |

**Boss, lair 30: the Tidecaller** `T`: 2400 / 0.5 / 2 / 3 gems / 150. She carries a Rainbringer cloud 2 tiles wide. Every 12 s a surge clears chill and Dread from heroes within 2.5 tiles and lets them wade freely for 6 s. Where she falls, 3 Fenwalkers and 2 Divers rise.

### Chapter IV: the Siegeworks

| Code | Hero | Health / speed / armour / gems / bounty | Rule | Counter |
|---|---|---|---|---|
| `a` | Sapper | 55 / 1.35 / 0 / 0 / 9 | Runs to the first tower within 1.3 tiles of the road that is not on a raised tile, lights a fuse (1.2 s), and the blast stuns that tower for 7 s. He dies in it (no bounty). Slain while the fuse burns, the keg hurts heroes within 1 tile for 150. Special target | Kill him on the approach; put key towers on raised tiles or a tile back from the road |
| `v` | Pavior | 120 / 0.8 / 1 / 1 / 12 | The road behind him is paved: other heroes on it walk 25% faster. The paving fades 30 s after he dies or leaves. Special target | Kill him early; the paved stretch ends where he fell |
| `i` | Inquisitor | 260 / 0.6 / 3 / 1 / 22 | Censer smoke 1.8 tiles wide silences every tower inside it | Out-range him from raised tiles; Meteor; the den is never silenced |
| `u` | Trebuchet | 700 / 0.45 / 5 / 0 / 45 | Rolls until a tower is within 3.6 tiles (or 55% of the road), sets up for 1.5 s, then every 5 s buries the strongest tower in range under Rubble. Never goes for gems. When the last wave is out and no other hero remains, it packs up and retreats | Shrine beams; Meteor; clear the rubble |

**Boss, lair 40: the Iron Belfry** `I`: 4200 / 0.38 / 8 / 0 gems / 250. A siege tower. Heroes walking in the 1.5 tiles behind it cannot be targeted by towers (Meteor still hits). Every 12 s a Sapper jumps out. At the den it stops and unloads 6 Footmen; destroyed earlier, it spills 4 Footmen, 2 Knights and an Inquisitor.

**As built (Phase 3):** the Trebuchet and the Iron Belfry are `steady` (chill and Dread do not work on engines, like the Longboat). The Belfry, once it has unloaded its Footmen at the den, rolls away like a retreating Trebuchet, so the win check never waits on a 4,200-health tower parked at the cave. The Trebuchet's "strongest tower" is the one with the most gold in it (`Tower.spent`). The Workshop is its own site kind, `"workshop"` (same keys as a camp), rather than a camp with `"look": "workshop"`, so it gets its own tip, Guide entry and achievement count.

### Chapter V: the Radiant Host

| Code | Hero | Health / speed / armour / gems / bounty | Rule | Counter |
|---|---|---|---|---|
| `y` | Skylancer | 150 / 1.3 / 0 / 1 / 14 | Flies straight for the den along an air road, ignoring the roads, water, Lava and paving. Chill works at half strength. Gems he drops fall to the nearest road and roll home | Towers near the den and under the flight line (drawn as a faint dashed line); den charges |
| `j` | Justicar | 420 / 0.7 / 3 / 2 / 28 | Once, below 35% health, a holy shield makes him untouchable for 2.5 s and heals him to 60%. Immune to Dread | Burst him down past the shield, or pop it early and finish him in a covered stretch |
| `n` | Spiriter | 140 / 1.0 / 0 / 1 / 16 | When he takes a gem he does not run: he chants for 4 s at the cave mouth and vanishes with it. Dread or death break the chant (a broken chant makes him run like anyone else) | Den charges, a Crypt with Dread by the den |

**Boss, lair 50: the Seraph** `S`: 5200 / 0.55 / 4 / 5 gems / 400. She flies. At 66% and 33% health she lands on the nearest road, is untouchable for 4 s, and raises the last 6 (then 8) slain heroes where she stands with half health (no bosses, boats or engines). Immune to Dread.

**As built (Phase 4):** "untouchable" (Justicar's shield, the Seraph landing) means no damage of any kind lands, Meteor included; towers keep aiming at him, so a shield popped in a covered stretch wastes their shots. The Justicar's shield only rises on a hit he survives: a hit big enough to kill him outright from above 35% gets past it. The Seraph raises no flyers (they would have no road under them) besides no bosses, boats or engines, and once she has landed she stays on that road. Skylancers are `no_send` like the other flyers. On lairs with flyers but no air road, the generated flight lines run from each land road's start straight to the den.

### Implementation notes

- Keep the pattern of `rally` for anything that spawns heroes mid-wave (boat crews, Belfry, Seraph): queue it, spawn next frame, and add to `wave_left` before the spawner's own removal is counted, or `_judge_wave` fires early.
- Heroes that leave without being slain or escaping with gems (Sapper blast, boat landing, Trebuchet retreat) must not call `_judge_kill`.
- Hidden or covered heroes are skipped in `_pick_target` and the den's search, not made invulnerable: area damage still lands.
- The win check (`enemies.is_empty()`) must not hang on a deployed Trebuchet: hence the retreat rule.
- A flyer's dropped gems need a land road: use `Level.nearest_dist` over land roads.

## 5. Towers: level IV and masteries

A tower that is level III **and** has learned its ability can be upgraded once more (150 gold) into one of two masteries. The panel shows both with a one-line description; the choice is final for that tower (selling refunds as usual). Each mastery must first be unlocked in Dark Arts (§7), so they arrive gradually through Chapter III. The badge reads IV and the tower gets a distinct look (§8).

Level IV base stats (add a fourth entry to each array in `Defs.TOWERS`): Hut 22 damage, 3.0 range, 0.33 s; Crypt 66 damage, 2.9 range, 1.25 s, 70% slow; Shrine 18 damage/s, 2.7 range.

**As built (Phase 2):** these stats alone made every mastery about 30% better than level III in every group before its own effect, which breaks the targets below. The plain level IV step is now small: Hut 18 damage, 3.0 range, 0.35 s; Crypt 53 damage, 2.9 range, 1.3 s, 65% slow; Shrine 15 damage/s, 2.7 range; the masteries carry the gain. Measured with `tests/tower_test.gd -- iv` (two towers, very tough heroes, damage dealt, against a battle-hardened level III): Longhouse +29% crowd / +51% mixed / +11% knight; Hunter's Lodge +58% knight, about 0% elsewhere; Ossuary +39% / +41% / 0%; Mausoleum +29% / +42% / 0%; Twin Flame +55% / +40% / +17%; Sunlance +36% / +31% / +11%. The Lodge's average over all three groups trails the Longhouse by about 12%, because its niche is one group of three.

**Plunder** (the owner's idea, 2026-11-13; replaces the Scavengers skill). A level IV Hut, whichever mastery, loots what it kills: its first kill as level IV pays +1 gold on top of the bounty, the second +2, and so on, **up to +5 a kill** (`Defs.PLUNDER_MAX`). The count belongs to that Hut and is lost if it is sold. Show the current bonus in the tile panel ("Plunder: +3 a kill") and as the gold number that floats up.

Why it is capped: without a cap, 60 kills would pay 1,830 gold and 100 kills 5,050, against a target of the bot ending a lair with 0–400 gold; doubling each kill passes a million gold at the twentieth. Capped at +5, a Hut that makes 60 kills as level IV pays about 285 extra, roughly what it cost to get there, and it keeps the reward of steering kills to that Hut. Tune the cap with `tests/difficulty.gd` (bot's gold at the end, and the threat's rich-gold rule still biting). Plunder is extra to the Hut's fighting strength, so keep the combat balance targets below as they are and, if the Hut becomes the obvious first level IV in every lair, lower the cap before touching its damage.

| Tower | Mastery A | Mastery B |
|---|---|---|
| Warband Hut | **Longhouse**: every shot is three arrows at up to three heroes (the two extra at Volley strength). Crowd killer | **Hunter's Lodge**: one heavy javelin, 1.6× slower, 2.6× damage, ignores armour, aims at the healthiest hero after gem carriers, and marks him for 4 s (+15% damage from everything) |
| Bone Crypt | **Ossuary**: stores a bolt every reload even with no hero in sight, up to 4 charges, then looses them 0.3 s apart at different heroes, unchilled ones first. Drawn as skulls lighting up on the roof | **Mausoleum**: each bolt bursts, chilling and dealing half damage to heroes within 0.9 tiles; Dread rolls for each |
| Cinder Shrine | **Twin Flame**: two beams on two heroes, each with its own heat, each at 65% damage; with one hero in range both burn him | **Sunlance**: the beam passes through its target and burns every hero on the line to the edge of its range at half damage; it keeps half its heat when it changes target |

Balance targets, measured with `tests/tower_test.gd` (extend it with level IV rows and a crowd, a single-knight and a mixed group): each mastery is 35–45% better than level III in its own niche and no more than 15% better outside it; A and B of one tower are within 10% of each other over all groups; the three towers stay within 10% of each other at equal gold.

## 6. Spells

**Removed** (owner's decision, 2026-11-13): no new spells. The Meteor stays the only spell. Nightmare, Frenzy and their Dark Arts skills (Nightmare, Night Terrors, Frenzy, Bloodlust) are gone, with their achievements; Phase 2 built them and they were taken out again.

## 7. Dark Arts v2

Today there are 59 points to spend and 120 stars to earn, so a thorough player already runs out of things to buy. With 50 lairs there are 300 stars; a typical player (2.4 per lair) holds about 120 by the finale. The new tree holds 133 points of power.

**Screen:** five trees no longer fit as columns with big text. Use one tab per tree (Huts, Crypts, Shrines, The Hoard, The Land); each tab lists its skills as large buttons in tier sections. A locked tier shows its header ("Opens in Chapter III") with the skills dimmed, so the player sees what is coming. Keep Refund all.

**Tiers open with the campaign, not with stars** (owner's decision, 2026-11-13): The Land when Chapter II is reached (10 lairs beaten), tier II with Chapter III (20 beaten), tier III with Chapter V (40 beaten). Stars stay the skill points. Star gates were dropped because a typical player (2.4 stars a lair) would reach 60 stars only around lair 25 and 150 stars after the finale, so tier III would never open; chapter gates open each tier as the content that needs it arrives (the masteries with Chapter III's heroes), give a clear reward moment on the map (a spotlight tip when a tier opens), and let the bot and the tuning assume exactly which skills exist at each lair.

**Tier I** (open from the start): the 20 existing skills, unchanged (59 points).

**Tier II** (opens with Chapter III, 20 lairs beaten):

| Tree | Skill | Effect per rank | Max |
|---|---|---|---|
| Huts | Bodkin Points | Arrows ignore 1 armour | 2 |
| Huts | Keen Eyes | +10% damage to gem carriers | 3 |
| Huts | Mastery: Longhouse | Unlocks it | 1 |
| Huts | Mastery: Hunter's Lodge | Unlocks it | 1 |
| Crypts | Deep Freeze | Chill lasts 0.4 s longer | 3 |
| Crypts | Grave Cold | +5% damage to chilled or soaked heroes | 2 |
| Crypts | Lingering Dread | Dread lasts 0.3 s longer | 2 |
| Crypts | Mastery: Ossuary | Unlocks it | 1 |
| Crypts | Mastery: Mausoleum | Unlocks it | 1 |
| Shrines | Ember Memory | Keep 10% heat when changing target | 3 |
| Shrines | Molten Core | Top heat +0.4× | 2 |
| Shrines | Slow Cooling | Lava lasts 0.5 s longer | 2 |
| Shrines | Mastery: Twin Flame | Unlocks it | 1 |
| Shrines | Mastery: Sunlance | Unlocks it | 1 |
| Hoard | Gem Magnet | Loose gems roll home 20% faster | 3 |
| Hoard | Sturdy Foundations | Stun, Rubble and Silence weigh 15% less (shorter, or less slowdown) | 3 |

**The Land** (new tree, opens with Chapter II, 10 lairs beaten):

| Skill | Effect per rank | Max |
|---|---|---|
| Rich Veins | Gold mines pay +1 gold | 3 |
| Deep Springs | Mana wells give +0.1 mana/s | 3 |
| Sharp Axes | Cuts cost 10% less mana | 3 |
| Commanding Heights | Raised tiles give +0.1 more range | 2 |
| Spoils of War | Razing a hero building pays +15 gold | 2 |
| Lantern Oil | Lights reach 0.3 tiles further at night | 3 |
| Floodmaster | Sluices recharge 20% faster; collapsing a bridge costs 5 mana less | 2 |
| Black Rites | Dark Altars give +5% more damage | 2 |

**Tier III** (opens with Chapter V, 40 lairs beaten):

| Tree | Skill | Effect per rank | Max |
|---|---|---|---|
| Huts / Crypts / Shrines | Legend (one per tree) | +5% damage | 5 each |
| Hoard | Hoard's Fury | Den bolts +20% damage | 5 |
| Hoard | Dragon's Patience | +10 starting mana | 3 |

Totals: 59 + 31 (tier II) + 20 (The Land) + 23 (tier III) = 133. `SaveData._skill_max` already ignores unknown ids, so old saves load. A skill's gate is checked in `can_buy` against `SaveData.lairs_beaten()` (`Defs.TIER_BEATEN`, `Defs.TREE_BEATEN`, done in Phase 0); beaten lairs stay beaten, so a refund never locks a tier. When a tier opens, the map shows a Dark Arts spotlight tip once (its own Prefs key). The achievement "Omniscient" (`arts59`) counts the real total. **Renown** (a score-only sink of 150 ranks) was built in Phase 4 and removed by the owner on 2026-11-15, with its achievements.

Update `Bot.SKILL_ORDER` and `Bot.points_before` in `tests/bot.gd` to buy tier II and III skills at the pace of a 2.4-star player, once their chapter is reached (`Bot.skills(points, beaten)` already passes over shut tiers), and teach the bot to: take a mastery when offered (alternate A and B by tile), collapse bridges when no Diver is in the wave, use Sluices on boats, clear Rubble, and raze Chapels and Signal Fires before woods.

## 8. Graphics

**Where it stands.** Everything is drawn in code (`ground.gd`, `board.gd`, `paint.gd`) over a baked ground shader. The look is consistent and original, the download is tiny and there are no art licences to track. Its weak points: heroes are small and flat at phone size, nothing reacts when it is hit, the ground is the same noise everywhere, the night is a flat fog, and skills and achievements are text only.

**Recommendation: keep the drawn style and add depth, motion and icons to it.** Replacing it with asset packs would cost the game its identity and mix styles. A full switch to pre-rendered 3D is listed last as an option for the owner to decide.

**Licence rule for anything brought in:** CC0, MIT or CC-BY only, credited in the Guide's credits topic and a `CREDITS.md` next to the files. GPL *tools* are fine (their output is yours); GPL *assets or shaders* are not. No AI-generated art: the Play listing declares none.

### Passes

- **G1 Motion** (no new art). Hit flash and a small knock on heroes; death puff and a coin that pops; tower recoil when firing and a squash-and-settle when built or upgraded; arrow and bolt trails; meteor shockwave ring, scorch decal and a short screen shake (with an off switch in the Sound window, renamed Settings); gem sparkle; floating text that eases. Use `CPUParticles2D` (works the same on web and Android under the Compatibility renderer) with a hard cap on live particles.
- **G2 Ground and biomes.** A palette and prop set per chapter passed to the ground shader as uniforms: lowland green, crusade autumn, drowned marsh, siege mud and trampled earth, radiant gold-white. Animated water (ripples, foam where roads cross, shore line) as a second shader layer. Scatter drawn props from seeded positions: rocks, bones, reeds, ruined walls, banners, tents by barracks. Ambient particles per biome: fireflies, snow, embers, mist, rain on Rainbringer lairs. Cloud shadows drifting over day maps.
- **G3 Sprites, light and status looks.** Bake each hero kind's walk cycle and each tower level into a texture atlas once at load (draw the existing code into a `SubViewport`), then draw sprites. That cuts per-frame draw calls (needed for the larger waves of later lairs on phones) and lets one small shader do hit-flash, outline for the selected tower, dissolve on death and a soft drop shadow. Draw heroes about 20% larger. At night, replace the flat fog with `PointLight2D` lights and a `CanvasModulate`, keeping the build rule exactly as it is. Looks for Stun (smoke), Silence (pale motes, halo off), Rubble (stones), Soaked (drips), hidden Diver (ripple and reed), level IV towers and each mastery.
- **G4 Icons and frames.** An icon for every skill, spell, achievement, hero and building: the Hall of Fame and Dark Arts become pictures, not lists. Carved-frame nine-patch panels and buttons; a painted parchment map per chapter behind the lair markers.
- **G5 Pre-rendered 3D: not chosen.** The owner decided on 2026-11-13 to keep the drawn style; do not start this pass. Kept here for reference only. Model towers and props in Blender, render them to sprites with one fixed light and matching normal maps. Gives the most "premium" look and consistent lighting, costs the hand-drawn identity, a larger download and a real art pipeline. Only worth starting if G1–G4 are not enough.

**As built (Phase 3, G3):** heroes are baked (`HeroSprites`), drawn 20% larger, with the hit flash and Belfry cover as tints of the same picture; towers are still drawn shape by shape (few on the map, animated by state). Night is a soft light map (4 px a tile, a warm glow per light) instead of `PointLight2D` + `CanvasModulate`: Compatibility caps the lights per canvas item and the ground is one item, and the light map shows the build rule tile for tile. Dissolve on death and the selected-tower outline were left out: the death burst and the selection frame already do those jobs.

Check glow before relying on it: the game runs on the Compatibility renderer everywhere. Test any `WorldEnvironment` glow on an Android phone and in the web build first; the fallback is the additive glow sprites `Paint.glow` already draws.

### Free tools and sources

| Tool or source | What for | Licence |
|---|---|---|
| [Inkscape](https://inkscape.org) | Vector props, icons, map art, level IV tower designs as SVG (Godot imports SVG at any scale). Best match for the current style | GPL tool |
| [Krita](https://krita.org) | Painted chapter maps, parchment and panel textures | GPL tool |
| [Material Maker](https://www.materialmaker.org) ([source](https://github.com/RodZill4/material-maker)) | Procedural ground textures with normal maps (mud, moss, flagstones, snow); built on Godot | MIT |
| [Laigter](https://github.com/azagaya/laigter) | Normal and specular maps from finished sprites, for the night lights in G3 | GPL tool; its author states the output is free to use |
| [Pixelorama](https://github.com/Orama-Interactive/Pixelorama) | Sprite sheets and frame animation clean-up (built with Godot) | MIT |
| [Godot Shaders](https://godotshaders.com) | Water, heat haze over ash, dissolve, outline, god rays, fog. Each shader has its own licence: take CC0 or MIT only | per shader |
| [Kenney](https://kenney.nl) | Particle textures, UI pieces, placeholder props | CC0 |
| [game-icons.net](https://game-icons.net) | Thousands of single-colour icons for skills and achievements; tint and frame them to fit | CC BY 3.0: credit required, verify on the site |
| [ambientCG](https://ambientcg.com), [Poly Haven](https://polyhaven.com) | Photo textures to feed Material Maker or the ground shader | CC0 |
| [OpenGameArt](https://opengameart.org) | Assorted; check each item's licence | per item |
| [Blender](https://www.blender.org) with [BlenderSpriteGenerator](https://github.com/RubielGames/BlenderSpriteGenerator) or [blender-sprite-render](https://github.com/coreway-labs/blender-sprite-render) | G5 only: batch-render models to sprites from the command line. Quaternius and KayKit model packs are commonly CC0; verify per pack | GPL tool; check each add-on |

Installed on the owner's PC on 2026-11-13 as portable copies in `Desktop/Gemhold/tools`: `inkscape/inkscape/bin/inkscape.exe` (1.4.4), `krita/krita-x64-6.0.4.1/bin/krita.exe`, `material-maker/material_maker_1_8_windows/material_maker.exe` (1.8), `laigter/laigter-windows/laigter.exe` (1.14.0). Inkscape renders SVG from the command line (`inkscape in.svg --export-type=png --export-width=N`), so drawn art can be authored as SVG text and rasterised without the GUI. Krita is a painting program for a person; do not plan work that needs it driven by script. Anything else on the list still needs the owner's go-ahead to download.

## 9. The thirty new lairs

Chapter names for `CHAPTERS` in `level_select.gd`: **III: The Drowned Marches**, **IV: The Siegeworks**, **V: The Radiant Host**. The map already pages ten lairs a chapter.

Each lair turns one lever nobody has seen yet, then later lairs mix levers. Grids stay at most 18 × 10 so heroes do not shrink on phones. Wave counts are guides. `hp_mul` is tuned last (§11). Earlier heroes keep appearing; the "new" column is what the first-sight tip will teach.

### Chapter III: The Drowned Marches

| # | Lair | Roads | New | Waves | Notes |
|---|---|---|---|---|---|
| 21 | Reedmere Ford | 1 long, two fords | Water, fords, Soaked, Fenwalker | 14 | Frost banks beside the fords so Crypts shine; ash only far from water |
| 22 | Twin Bridges | 2, a bridge each | Collapse, Engineer | 15 | The far bank of each bridge is in reach of one raised tile |
| 23 | Rainmoor | 2 | Rainbringer | 15 | Nearly all ash: the Shrine player must protect his heat or adapt |
| 24 | The Sunken Causeway | 3 | Wave routes | 16 | Odd waves use the causeway, even waves the two hill roads; the HUD shows which is next |
| 25 | Oarsmen's Reach | 1 land, 1 river | Longboat | 16 | The river passes two build pockets before a landing 4 tiles from the den |
| 26 | Blackwater Fen | 2, long fords | Diver | 16 | Divers surface right at the den's edge on one road |
| 27 | Sluicegate | 1 land, 1 river | Sluice Gate, Dark Altar | 17 | Boats with Knight crews: the Sluice is the answer, its recharge the tension |
| 28 | Tidewrack Flats | 3 | Tide | 17 | High tide slows everyone but hides Divers everywhere |
| 29 | The Flooded Abbey | 2 land, 1 river, 1 bridge | A Champion arriving by boat | 18 | Every Chapter III hero with Clerics, Wardens and Heralds |
| 30 | Maelstrom Gate | 2 land, 1 river | Tidecaller (boss) | 18 | Tide and routes together; she comes in the last wave with a full escort |

### Chapter IV: The Siegeworks

| # | Lair | Roads | New | Waves | Notes |
|---|---|---|---|---|---|
| 31 | Powder Road | 2 | Sapper, tower Stun | 16 | Four raised tiles: the safe spots |
| 32 | The King's Highway | 1, the longest in the game | Pavior | 17 | Speed is the enemy: Heralds and Berserkers on paved road |
| 33 | Censer Vale | 2, joined | Inquisitor, Silence | 17 | Raised tiles that out-range the smoke; little other good ground |
| 34 | Beacon Hill | 3 | Signal Fire | 17 | The fire stands at the far end and takes 3 cuts: spend mana there or on Meteors |
| 35 | Stonefall Quarry | 2 | Trebuchet, Rubble | 18 | Few build tiles, so each buried tower hurts |
| 36 | The Workshops | 2 | Workshop | 18 | Two workshops (4 cuts each) and a barracks: a race against the engines |
| 37 | Duskwall | 2 | Dusk | 18 | Night falls at wave 9: towers built by day decide where you can build after dark |
| 38 | Hollow Gate | 2, over a moat | Siege heroes on water | 19 | Bridges and Engineers return, with Sappers behind Shieldbearers |
| 39 | The Long Siege | 3 | Endurance | 22 | Short gaps (18 s), two mines, the threat does the rest |
| 40 | The Iron Belfry | 1 long, 1 short | Iron Belfry (boss) | 20 | The Belfry takes the long road while Trebuchets hold the short one |

### Chapter V: The Radiant Host

| # | Lair | Roads | New | Waves | Notes |
|---|---|---|---|---|---|
| 41 | Gryphon Aerie | 2 land, 2 air | Skylancer | 18 | Flight lines cross open ground away from the roads |
| 42 | Oathkeeper's Stair | 1 long | Justicar | 18 | One winding road: the question is where his shield gets spent |
| 43 | The Chapel Road | 2 | Chapel | 19 | Two Chapels and a barracks: more to raze than mana allows |
| 44 | Hallowed Fields | 2 | Hallowed ground | 19 | The best tiles are hallowed until both Chapels fall |
| 45 | The Reliquary | 3 short | Spiriter, seven gems | 19 | Short roads and chanting thieves: den charges and Dread matter most here |
| 46 | Pilgrim's Flood | 1 land, 1 river, 1 air | Water, boats and flyers together | 20 | Three kinds of road at once |
| 47 | The Sun Gate | 2 | Siege with the Host | 20 | Trebuchets guarded by Justicars; Inquisitors on hallowed ground |
| 48 | Eclipse | 3 | Eclipse | 20 | Dark for 25 s in every 70 |
| 49 | The Last Procession | 4 land, 1 river, 2 air | Every hero in the game | 22 | Each wave revisits one earlier chapter |
| 50 | The Seraph's Descent | 3 land, 2 air | Seraph (boss) | 24 | Seven gems. Champions in waves 18 and 21, the Seraph in 24 |

**Music.** Decided 2026-11-13: lairs without a chosen track play no battle music. Change the fallback in `main.gd` (`MUSIC.get(level.id, "mountain")`) to silence. The owner is auditioning candidates in `Desktop/Gemhold/Music to try/new` (52 tracks on 2026-11-13, each with source and licence in `SOURCES.txt`: CC0, CC-BY or OGA-BY only). Some downloads are the site's preview encodes; when a track is chosen, fetch the best original from its source page before cutting it. Give a lair its track only when the owner names it, then follow the usual workflow (cut the loudest 150 s, -14 LUFS, credit, remove from the folder).

## 10. Achievements v2

### Fix first (these assume 20 lairs)

| Id | Problem | Change |
|---|---|---|
| `chapter2` | Checked as "every lair beaten"; with 50 lairs nobody could earn "Defend all twenty lairs" at lair 20 | Check `beaten >= 20` |
| `brilliant_last`, `night_final` | Check `number >= 20` | Check the real last lair; players who hold them keep them; reword to "the Hoard Throne" and add new ones for lair 50 |
| `stars120` | "Earn all 120 stars" | "Earn 120 stars" |
| `night_brilliant20` | "all twenty night missions" | "20 night missions" |
| `arts59` | Goal 59 is the old tree | Goal = every skill, computed from `Defs.SKILLS` |
| `all_brilliant`, `all_night` | Now mean all 50: fine, keep | none |

### New (about 80; ids are suggestions)

- **Campaign:** `beaten25` Halfway to Dominion, `chapter3` Lord of the Marches, `beaten35`, `chapter4` Siegebreaker, `beaten45`, `chapter5` Light Extinguished (all fifty), `brilliant25`, `brilliant40`, `night25`, `night40`, `night_brilliant35`, `night_brilliant50` Fifty Shades of Night, `final_brilliant` Not a Feather Touched (lair 50 Brilliant), `final_night` (lair 50 by night).
- **Stars and score:** `stars150`, `stars200`, `stars250`, `stars300` Every Star There Is; `score30000`, `score40000`; `total500000`, `total1000000`.
- **Dark Arts:** `arts80`, `arts110`, `branch_land` Landlord, `tier3` Forbidden Knowledge (buy a tier III skill).
- **Masteries:** one for building each of the six, `mastery_all` (all six in one battle), `mastery_one_each`, `ossuary_burst` (four heroes slain by one Ossuary volley), `twin_kills` (Twin Flame slays two heroes within a second), `sunlance3` (three heroes burning on one Sunlance), `hunter_champion` (a Hunter's Lodge lands the killing blow on a Champion), lifetime `masteries25`, `masteries100`.
- **Water:** `sink1` Davy Jones (sink a Longboat before it lands), `sink_all` (win a river lair with no boat landing), `drowned100` lifetime crew drowned, `collapse_kill` (a hero dies swimming a collapsed bridge), `collapses25`, `sluice5` (five heroes slain by one surge), `dry_feet` (win Reedmere Ford with no hero slain in water), `diver_meteor` (slay a hidden Diver with a Meteor).
- **Siege:** `sapper_keg` Own Goal (a Sapper's keg slays three heroes), `no_stun` (win a Sapper lair with no tower ever stunned), `rubble10` (clear 10 Rubbles in one battle), `trebuchet_fast` (destroy a Trebuchet before its first stone), `silence_proof` (slay an Inquisitor with a tower he was silencing), `pavior_early` (slay a Pavior before he paves three tiles), `belfry` Belfry Breaker.
- **Radiant:** `skylancer10` (ten Skylancers in one battle), `shield_waste` (make a Justicar spend his shield outside every tower's range), `chant_broken5`, `chapel_first` (raze every Chapel before wave 5), `hallowed_none` (win Hallowed Fields without building on hallowed ground), `seven_kept` (win a seven-gem lair Brilliant), `seraph` Fallen Angel, `seraph_no_raise` (slay the Seraph before her second rising).
- **Heroes slain, lifetime:** two tiers for each of the twelve new heroes (100 and 1,000; Longboats and Trebuchets 25 and 250) and one per boss.
- **Land:** `altars10`, `chapels25`, `beacons10`, `workshops10`, `sluices50`.

Add the stats these need to `GameSim` and `Achievements.record`. `firestore.rules` allows 500 achievement ids and 300 stat keys; this plan stays near 310 and 110.

## 11. Things in the code that assume 20 lairs or today's rules

Fix in Phase 0, before any content:

- **Firestore rules**: done. `best` and `scores` now allow 150 entries (raised from 100 and deployed 2026-11-13), which leaves room beyond the 100 missions of 50 lairs.
- **Achievements**: the table in §10.
- **Score**: each lair is worth 10% more than the last, so lair 50 scores ×5.9. Keep it (late lairs should dominate the board) and add the higher score achievements.
- **`tests/bot.gd`**: `SKILL_ORDER` has 56 entries and `points_before` caps there.
- **`tests/difficulty.gd` and `sim_test.gd`** run every lair one after another; 50 lairs by day, with skills and by night will take well over an hour. Add a `--chapter N` filter and print results as they come.
- **Board drawing** redraws every hero with many primitives each frame. Waves grow in later chapters: do G3's sprite baking before Chapter IV, and measure frame time on a phone at lair 30.
- **Races**: `race_shop` offers every hero in a lair's waves; honour `no_send`. A rival on an older version already gets "That lair is not in this version".
- **Demo**: stays the first 5 lairs. No change.
- **Guide and tips**: every new hero, building, rule and mastery needs a Guide entry and a first-sight tip. "No more tips" must cover the new kinds (it loops over `Defs.SITES` and `Defs.ENEMIES` already; lair rules and spells need their own Prefs keys in that loop).

### Tuning method

1. Build the lair, pass `tests/level_check.gd`.
2. Tune towers and masteries first (`tower_test.gd`), then heroes, then `hp_mul` last with `tests/difficulty.gd`.
3. Target bot margin: continue the existing curve. It falls from ×3.9 (lair 1) to ×1.2 (lair 20); restart each new chapter a little easier and end it harder: III ×1.6 → ×1.2, IV ×1.5 → ×1.15, V ×1.4 → ×1.1. The bot is much stronger than a person, so a margin of ×1.1 is already very hard.
4. The bot should end day lairs with roughly 0–400 gold. More means the lair is too generous.
5. Night missions keep `NIGHT_HP` 0.85.

## 12. Phases

Each phase ends with all tests green, the Guide and `DEVELOPMENT.md` updated, a rebuilt `Gemhold.exe`, and a local commit. Publishing is the owner's call.

| Phase | Contents | Done when |
|---|---|---|
| **0 Groundwork** | §11 fixes; level format v2 loader and `level_check`; road zones; Dark Arts screen with tabs and tier gates (tier I only filled); `--chapter` test filter | The 20 existing lairs play exactly as before (bot results unchanged for the same seeds) |
| **1 Feel** | G1 motion and G4 icons for what exists | Screenshots before and after; no frame-time loss on Android |
| **2 The Drowned Marches** | Water, fords, bridges, river roads, Tide, routes; five heroes and the Tidecaller; Altar and Sluice; level IV and the six masteries; Dark Arts tier II and The Land; G2 biomes and water; lairs 21–30; their achievements | Bot wins 21–30 inside the margin targets; `tower_test` balance targets met |
| **3 The Siegeworks** | Tower statuses; four heroes and the Iron Belfry; Signal Fire, Workshop; Dusk; G3 sprites, lights and status looks; lairs 31–40; achievements | As above, plus stable frame time at lair 40 on a phone |
| **4 The Radiant Host** | Flyers and air roads; three heroes and the Seraph; Chapel, hallowed ground, Eclipse, seven gems; Dark Arts tier III; lairs 41–50; the remaining achievements; chapter map art | Bot wins 41–50; the whole campaign difficulty curve printed and smooth |

Phase 1 can run alongside Phase 0. Phases 2–4 are in order because each chapter's lairs reuse the systems of the one before.

## 13. Ideas kept for later

Not part of this plan; they need decisions or new backend rules.

- **Heroic missions**: a third mission per lair with a twist (one tower type, no Meteor, one gem). Needs the Firestore caps raised first.
- **The Long Night**: endless waves on any beaten lair, with its own leaderboard.
- **Captive beasts**: a caged troll freed by cutting that walks the road and blocks heroes. Needs a blocker system (heroes stopping to fight).
- **Per-tower targeting choice** (weakest, strongest, nearest the den) in the tile panel.
- **Weekly lair**: a fixed seed and rule mix shared by all players for a week.

## 14. Decisions for the owner

1. **Music**: decided: no music on a new lair until the owner picks its track (§9).
2. **Firestore caps**: done, raised to 150 and deployed.
3. **Graphics direction**: decided 2026-11-13: keep the drawn style, passes G1–G4 only.
4. **Tools**: Inkscape, Krita, Material Maker and Laigter are installed (§8).
5. **Plunder** (§5): the cap of +5 gold is a starting value; the owner may want it higher once the bot's end-of-lair gold is measured.
6. **Dark Arts tiers**: decided 2026-11-13: they open with chapters, not stars: The Land with Chapter II, tier II with Chapter III, tier III with Chapter V (§7).
7. **Spells**: decided 2026-11-13: no new spells; Nightmare and Frenzy removed (§6).
8. **Renown**: decided 2026-11-15: no score-only skill; Renown removed (§7).
