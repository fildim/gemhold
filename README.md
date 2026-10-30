# Gemhold

<p align="center">
  <a href="https://github.com/fildim/gemhold/releases/latest/download/Gemhold.exe"><img src="https://img.shields.io/badge/Download_for_Windows-Gemhold.exe-e8b84a?style=for-the-badge&logo=windows&logoColor=white" alt="Download Gemhold for Windows" height="48"></a>
  <br>
  <sub>Always the latest version · <a href="https://github.com/fildim/gemhold/releases/latest">release notes</a> · no install needed, just double-click</sub>
</p>

> **Windows may say "Windows protected your PC"** because the game isn't code-signed. Click **More info**, then **Run anyway**.

A dark-lord tower defense for Windows and Android, built with **Godot 4.6**. You guard a cave of gems; heroes walk the roads to steal them.

The campaign opens on a level map. Level 1 ("Mossfold Pass") is ported from the web prototype with the same rules and balance; levels 2–5 (Rimewater Ford, Gloamwood Hollow, Cinderfall Steps and The Hoard Throne) are new. Clearing a level Brilliant unlocks its night mission. Progress saves automatically: unlocked levels, best rating per mission and skills. Each level guards 5 gems.

## What's in a battle

- **Towers** need their own ground (moss, frost, ash). **High ground** takes any of the three.
- **Veterancy:** towers rank up from damage dealt, up to 3 ranks (+8% damage each). Rank 2 unlocks an ability: Volley (Huts fire a second arrow), Dread (Crypt hits can terrify a hero) and Lava (Shrine fireballs leave burning ground).
- **Cutting** costs mana. It clears woods, frees **Gold Mines** (gold over time) and **Mana Wells** (faster mana), and razes **Hero Barracks**, which otherwise send extra heroes while waves are coming.
- **Heroes:** Peasant, Footman, Scout, Cleric (heals nearby heroes) and Knight (armoured, carries 2 gems), plus three that arrive from level 4: the **Shieldbearer** (other heroes within 1.2 tiles take 35% less damage), the **Cutpurse** (fast, fragile, carries 2 gems) and the **Warden** (his lantern clears slow and Dread from heroes around him).
- **Loot:** a slain hero drops a coin (35%), a mana potion (15%) or nothing, never both. Loot stays on the ground until you tap it, and calling the next wave early gathers all of it at once.
- **The den fights back:** your lair holds charges (1 to start). Each is a bolt it fires automatically at heroes within 2.6 tiles, gem carriers first, ignoring armour. Spent charges refill one every 8 s. The sparks above the cave show how many are ready.
- **Ratings and stars:** Survived ★ (you lost gems), Wicked ★★ (none lost, but a hero touched one, even if you got it back) and Brilliant ★★★ (no hero ever touched a gem).
- **Night missions:** clearing a level Brilliant unlocks the same level at night, with its own best rating and stars. You can only build where you can see; the lair, your towers and your mines and wells light the ground around them. A moon on the map marks it: faint while locked, pale when open, gold once won.
- **Dark Arts** (skill tree, on the map): every star is a skill point to spend across the Hut, Crypt and Shrine trees, or on the Den (each point there is one more den charge, up to 5). Stars come from each mission's best rating, day and night counted separately, so replaying a lair for a better rating earns more points. There is no player XP.

## Open and play

1. Install [Godot 4.6](https://godotengine.org/download) (the standard build, not .NET).
2. In the Project Manager, choose **Import**, pick this folder's `project.godot`, then **Import & Edit**.
3. Press **F5** (or the ▶ button) to play on your computer. To start over, use **Reset progress** on the map (tap twice).

## How the project is organized

```
project.godot            engine settings (landscape, mobile-friendly renderer)
scenes/main.tscn         the one scene: map, level select, HUD layer
levels/level_0N.json     map grids, roads, starting gold, waves, intro text
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
  main.gd                connects everything, handles taps
tests/                   headless checks (see below)
assets/fonts/            Grenze Gotisch and Alegreya Sans (SIL Open Font License, see OFL.txt)
```

**Tuning balance:** edit `scripts/data/defs.gd`.
**Adding a level:** copy `levels/level_02.json`, give it a new `id`, edit it, and add its path to `LEVELS` in `scripts/main.gd`. The map has five spots; add more to `SPOTS` in `scripts/ui/level_select.gd`. Optional `intro` text shows on the start card.
In the level file, `terrain` uses `m` moss, `f` frost, `a` ash, `h` high ground and `L` lair. Add `"hp_mul": 1.4` to make heroes tougher on a later level. `"night": true` makes a level night-only (normally night is the unlockable mission). `sites` lists map buildings: `{"kind": "mine"|"well", "cell": [x, y]}` or `{"kind": "camp", "cell": [x, y], "path": 0, "spawn": "2p,1f", "every": 30}`. In `trees`, `T` marks woods. `paths` lists each road's corner tiles; roads start off the map edge and end next to the lair. Waves use hero codes: `p` peasant, `f` footman, `s` scout, `c` cleric, `k` knight, `b` shieldbearer, `t` cutpurse, `w` warden. For example, `"6p,2f"` is 6 peasants and 2 footmen.

## Tests

From this folder, with Godot on your PATH:

```
godot --headless --import
godot --headless --script res://tests/sim_test.gd     # plays every level by day, and at night with mid-game skills
godot --headless --script res://tests/level_check.gd  # level files: grid sizes, woods on roads, roads reaching the lair
godot --headless --script res://tests/save_test.gd    # unlocking, ratings, stars as skill points, loot, damaged save files
godot --headless --script res://tests/scene_test.gd   # boots the real scene, taps tiles, casts spells, plays the night level
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
- [x] High ground tiles that accept every tower
- [x] Mana wells and gold mines freed by cutting; hero barracks that spawn troops
- [x] Loot drops (coins, potions)
- [x] Night missions, unlocked by a Brilliant clear: build only where you can see
- [x] Three ratings: gems lost, gem touched, untouched
- [x] New heroes: Shieldbearer, Cutpurse, Warden
- [ ] Sound and music

## Publishing a new version

Raise the version in `export_presets.cfg` (both presets) and `project.godot`, commit, then tag and push:

```
git tag v0.2.2
git push origin main v0.2.2
```

GitHub Actions (`.github/workflows/release.yml`) builds `Gemhold.exe` and publishes it as a release; the download button above always points at the newest one.
