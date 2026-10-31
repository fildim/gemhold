# Gemhold: notes for developers

The rules in detail, how the project is organised, tests, builds and publishing. For players, see the [README](../README.md).

A dark-lord tower defense for Windows, macOS, Linux, Android, iPhone and the web, built with **Godot 4.6**. You guard a cave of gems; heroes walk the roads to steal them. It has music and sound effects (the **Sound** button switches both on or off), and the first lair teaches you as you play: each tip freezes the battle, darkens the screen and lights up the one thing to tap. The first time you have a skill point to spend, the map does the same for Dark Arts. **Skip tutorial** turns the tips off; **Reset progress** brings them back.

The campaign opens on a level map: twenty lairs in two chapters of ten (the arrows beside the heading switch chapter). Lair 1 ("Mossfold Pass") is the tutorial, ported from the web prototype. From there each lair turns one or two difficulty levers further, and later lairs mix them, so no two play alike (see **Campaign** below). Clearing a level Brilliant unlocks its night mission. Progress saves automatically: unlocked levels, best rating per mission and skills. Each level guards 5 gems.

## What's in a battle

- **Towers** need their own ground (moss, frost, ash). **Raised tiles** are single tiles of pale, shimmering stone set higher than the rest: any of the three towers can be built on them, whatever the ground, and they give it extra range (Hut +0.8, Shrine +0.6, Crypt +0.5). Which tower to put up high is your call. The first tower of each type costs 50 gold and each more of that type standing costs 15 more (50, 65, 80…); upgrades cost 75 (level II) and 100 (level III).
- **Three ways to attack**, none stronger overall: the **Warband Hut** fires fast, light arrows (best on crowds, blunted by armour); the **Bone Crypt** fires slow, heavy bolts that slow heroes hard; the **Cinder Shrine** holds a continuous beam on one hero that ignores armour and heats up to 5× damage, but starts cold on every new target (best on knights). `tests/tower_test.gd` compares them. Every level starts with 230 gold.
- **Threat** (dynamic difficulty, never shown): after each wave the game checks how deep into your defence its heroes got, meaning how much of the stretch your towers and den can reach they walked through. The threat multiplies hero health and only ever rises: a lot after a wave you stopped early (up to +40%), only a little after one that got close (+1–3%). Riches draw heroes too: unspent gold above 250 adds to it after every wave (+5% per 100 gold, up to +25%), so hoarding is never the safe choice. It starts at ×1.0 each battle and tops out at ×4.0; tune it with `THREAT` in `defs.gd`.
- **Veterancy:** towers rank up from damage dealt, up to 3 ranks (+8% damage each). A tower at rank 3 that is also upgraded to level III unlocks its ability: Volley (Huts fire a second arrow), Dread (Crypt hits can terrify a hero) and Lava (heroes a Shrine kills have a 35% chance to leave a pool of burning ground).
- **Meteor** (60 mana): tap Meteor, then the map; a moment later it lands for 280 damage around that spot, through armour.
- **Cutting** costs mana. It clears woods, frees **Gold Mines** (gold over time) and **Mana Wells** (faster mana), and razes **Hero Barracks**, which otherwise send extra heroes while waves are coming. The **Cut woods** button clears a random patch of woods for the same mana, without hunting for one on the map. From lair 4 buildings can take several cuts (`site_cuts` in the level file, or `cuts` on one building, rising to 4 by the end); `cut_cost` in game_sim.gd spreads 1.5x/2x/2.5x of the base mana over 2/3/4 cuts, and each cut on a barracks slows its musters by 30%.
- **Heroes:** Peasant, Footman, Scout, Cleric (heals nearby heroes) and Knight (armoured, carries 2 gems), then the **Cutpurse** (lair 4: fast, fragile, carries 2 gems), the **Shieldbearer** (lair 5: other heroes within 1.2 tiles take 35% less damage) and the **Warden** (lair 5: his lantern clears slow and Dread from heroes around him). Chapter II adds the **Herald** (lair 11: heroes near his banner, himself included, walk 35% faster), the **Berserker** (lair 13: below half health he runs 2.1× as fast) and the **Champion** (lair 15: a 1500-health armoured boss who carries 3 gems; when he falls, three Footmen rise where he lay).
- **Loose gems:** a slain carrier drops his gems and they float back along the road to the hoard. Any hero on that road (or one joined to it) with room to carry turns toward them, even back the way he came, so kill the carrier where your towers can cover the gems.
- **Targeting:** towers shoot gem carriers first, then the special support heroes (Cleric, Shieldbearer, Warden), then whoever has the least health left.
- **Loot:** a slain hero drops a coin (32%), a mana potion (15%) or nothing, never both. Coins are worth 4 gold plus 1.4× the hero's bounty, growing with the wave number and the square root of the lair's `hp_mul`, but not with the threat, so doing well does not snowball into riches. Tap loot to pick it up at once; whatever is still lying on the map is gathered automatically when the next wave starts (on its timer or called early).
- **The end:** after the last wave, the battle is won the moment its last hero falls or flees; gems still rolling home count as home.
- **The den fights back:** your lair holds charges (1 to start). Each is a bolt it fires automatically at heroes within 2.6 tiles, gem carriers first, ignoring armour. Spent charges refill one every 8 s. The sparks circling above the cave show how many are ready.
- **Ratings and stars:** Survived ★ (you lost gems), Wicked ★★ (none lost, but a hero touched one, even if you got it back) and Brilliant ★★★ (no hero ever touched a gem).
- **Night missions:** clearing a level Brilliant unlocks the same level at night, with its own best rating and stars. Darkness is the challenge, so night heroes have 15% less health (`NIGHT_HP` in defs.gd). You can only build where you can see; the lair, your towers and your mines and wells light the ground around them. A moon on the map marks it: faint while locked, pale when open, gold once won.
- **Dark Arts** (skill tree, on the map): every star is a skill point to spend across the Hut, Crypt and Shrine trees, or on The Hoard: a den charge, +50 starting gold, +15 max mana or +25% meteor damage (Starfall) per point. Stars come from each mission's best rating, day and night counted separately, so replaying a lair for a better rating earns more points. There is no player XP.

## Campaign

Twenty lairs, in two chapters of ten. Each lair turns one or two levers further than the last: the roads (how many, how long, whether they join), raised tiles, woods crowding the roads, which ground dominates, buildings and how many cuts they take, how many waves and heroes, which hero abilities appear, and hero health (`hp_mul`). Hero health is tuned last, with `tests/difficulty.gd`, so the bot's headroom falls smoothly from about ×3.5 on the tutorial to about ×1.15 on the finale, assuming the player spends about 2.4 stars per lair beaten in Dark Arts (`Bot.points_before`).

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
  ui/hud.gd              stats bar, buttons, tile panel, start and end screens
  ui/level_select.gd     the campaign map (tap a lair to play it)
  ui/skill_tree.gd       Dark Arts, the skill tree
  ui/tutorial.gd         tips on the first lair, one at a time
  ui/guide_screen.gd     the Guide (topics on the left, a card on the right), opened from the map
  data/guide.gd          the Guide's topics and text
  ui/symbols.gd          drawn fallback glyphs (★ ● ○) so they show in browsers too
  audio/audio.gd         sound effects and music (autoload SfxPlayer, called as Sfx.play)
  core/prefs.gd          sound, music and tutorial settings in user://settings.cfg
  main.gd                connects everything, handles taps
tests/                   headless checks (see below)
assets/fonts/            Grenze Gotisch and Alegreya Sans (SIL Open Font License, see OFL.txt)
assets/audio/            sound effects and music, all made by tools/make_audio.gd
tools/make_audio.gd      synthesises every sound; edit it and run it to change them
```

**Tuning balance:** edit `scripts/data/defs.gd`.
**Adding a level:** copy a level file, give it a new `id`, edit it, and add its path to `LEVELS` in `scripts/main.gd`. `LEVELS` is the campaign order; file numbers only say when a map was made, so ids (and players' saved stars) never move when lairs are reordered. The map shows ten lairs a chapter (`PER_PAGE`, `SPOTS` and `CHAPTERS` in `scripts/ui/level_select.gd`). Optional `intro` text shows on the start card. Check the new lair with `tests/difficulty.gd` (below) so it fits the curve.
In the level file, `terrain` uses `m` moss, `f` frost, `a` ash and `L` lair; a capital `M`, `F` or `A` is a raised tile of that ground. Add `"hp_mul": 1.4` to make heroes tougher on a later level. `"night": true` makes a level night-only (normally night is the unlockable mission). `sites` lists map buildings: `{"kind": "mine"|"well", "cell": [x, y]}` or `{"kind": "camp", "cell": [x, y], "path": 0, "spawn": "2p,1f", "every": 30}`; any building can add `"cuts": 3` to override the level's `site_cuts`. In `trees`, `T` marks woods. `paths` lists each road's corner tiles; roads start off the map edge and end next to the lair. Waves use hero codes: `p` peasant, `f` footman, `s` scout, `c` cleric, `k` knight, `b` shieldbearer, `t` cutpurse, `w` warden, `h` herald, `r` berserker, `x` champion. For example, `"6p,2f"` is 6 peasants and 2 footmen.

## Tests

From this folder, with Godot on your PATH:

```
godot --headless --import
godot --headless --script res://tests/sim_test.gd     # the bot (tests/bot.gd) plays every lair by day and at night, with the skill points a player would have by then
godot --headless --script res://tests/sim_test.gd -- 6 7  # just those campaign lairs, without and with skills
godot --headless --script res://tests/difficulty.gd    # how much headroom the bot has on each lair (the difficulty curve)
godot --headless --script res://tests/level_check.gd  # level files: grid sizes, woods on roads, roads reaching the lair
godot --headless --script res://tests/save_test.gd    # unlocking, ratings, stars as skill points, loot, damaged save files
godot --headless --script res://tests/scene_test.gd   # boots the real scene, taps tiles, casts spells, plays the night level
godot --headless --script res://tests/tower_test.gd   # the three tower types side by side against set groups of heroes
godot --headless --script res://tests/tutorial_test.gd  # the first-lair tips: where they point and how they move on
```

## Putting it on your Android phone

The Android tools live in `tools/` next to this folder (on this PC: `Desktop\tools`):
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

## Getting ready for Google Play

- **Use a Gradle build:** in the Android export preset, enable **Gradle Build > Use Gradle Build**, then **Project > Install Android Build Template**.
- **Target Android 16 (API 36):** the quick debug build above targets API 35, which is fine for testing on your phone. Since August 31, 2026, Google Play requires new apps and updates to target API 36. Set **Target SDK** to 36 in the export preset's Gradle Build section. If Play Console still warns, check the Godot forum thread on targeting the latest SDK.
- **Export an `.aab` file** (Google Play only accepts App Bundles for new apps).
- **Make a release keystore** with `keytool` (comes with the JDK) and enter it under **Keystore > Release**. Back it up with its passwords somewhere safe. Without it you can never update the app.
- **Developer account:** a one-time $25 fee at play.google.com/console.
- **Closed test first:** new personal accounts must run a closed test with at least 12 testers opted in for 14 days in a row before the app can go public.
- **Keep the art and name original.** Mechanics like Cursed Treasure's are fine; its name, characters and graphics are not.

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

## Sound

Sound effects are synthesised by `tools/make_audio.gd` (oscillators, noise and plucked strings). The music is public-domain and CC-BY (Kevin MacLeod, credited in the Guide) orchestral tracks from Wikimedia Commons in `assets/music/` (sources and licences in `assets/music/CREDITS.md`), looped in `audio.gd`. The level map plays Mussorgsky's *Promenade*, and each lair has its own piece (`MUSIC` in `main.gd`):

| Lair | Music |
|---|---|
| 1 Mossfold Pass | Grieg, *In the Hall of the Mountain King* |
| 2 Rimewater Ford | Kevin MacLeod, *Heroic Age* |
| 3 Gloamwood Hollow | Kevin MacLeod, *Curse of the Scarab* |
| 4 Cinderfall Steps | Kevin MacLeod, *Volatile Reaction* |
| 5 The Hoard Throne | Wagner, *Ride of the Valkyries* |
| 6 Saltmarsh Crossing | Kevin MacLeod, *Crusade* |
| 7 The Iron Column | Beethoven, *Symphony No. 5* |
| 8 Gloomspire Summit | Kevin MacLeod, *Five Armies* |

To swap a piece, drop an .ogg (its most intense 2:30, normalised to -14 LUFS) into `assets/music/` (ready ones wait in `assets/music/spare/`), put its name in `MUSIC` and add it to CREDITS.md. To change a sound effect, edit its function in `tools/make_audio.gd` and rebuild:

```
godot --headless -s res://tools/make_audio.gd -- coin boom   # just these, or no names for all
godot --headless --import
```

Volumes and how often each may repeat are in `SFX` at the top of `scripts/audio/audio.gd`. The music and the Shrine's crackle loop; that is set in their `.wav.import` files (`edit/loop_mode=2`).
