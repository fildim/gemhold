# Gemhold

<p align="center">
  <a href="https://fildim.github.io/gemhold/"><img src="https://img.shields.io/badge/Play_in_your_browser-iPhone_·_iPad_·_any_device-e2683a?style=for-the-badge&logo=googlechrome&logoColor=white" alt="Play Gemhold in your browser" height="48"></a>
  <br><br>
  <a href="https://github.com/fildim/gemhold/releases/latest/download/Gemhold.exe"><img src="https://img.shields.io/badge/Windows-Gemhold.exe-e8b84a?style=for-the-badge&logo=windows&logoColor=white" alt="Download for Windows" height="36"></a>
  <a href="https://github.com/fildim/gemhold/releases/latest/download/Gemhold-macOS.zip"><img src="https://img.shields.io/badge/macOS-Gemhold--macOS.zip-e8b84a?style=for-the-badge&logo=apple&logoColor=white" alt="Download for macOS" height="36"></a>
  <a href="https://github.com/fildim/gemhold/releases/latest/download/Gemhold-Linux.zip"><img src="https://img.shields.io/badge/Linux-Gemhold--Linux.zip-e8b84a?style=for-the-badge&logo=linux&logoColor=white" alt="Download for Linux" height="36"></a>
  <a href="https://github.com/fildim/gemhold/releases/latest/download/Gemhold.apk"><img src="https://img.shields.io/badge/Android-Gemhold.apk-e8b84a?style=for-the-badge&logo=android&logoColor=white" alt="Download for Android" height="36"></a>
  <br>
  <sub>Always the latest version · <a href="https://github.com/fildim/gemhold/releases/latest">release notes and all files</a></sub>
</p>

| System | How to start it |
|---|---|
| **Windows** | Double-click `Gemhold.exe`. If it says "Windows protected your PC" (the game isn't code-signed), click **More info**, then **Run anyway**. |
| **macOS** | Unzip, then right-click **Gemhold** and choose **Open**, then **Open** again. Only needed the first time, because the app isn't notarised by Apple. |
| **Linux** | Unzip and run `Gemhold.x86_64`. |
| **Android** | Download `Gemhold.apk` on the phone and open it. Allow installing apps from your browser when asked. |
| **iPhone / iPad** | Open the **browser version** in Safari, tap **Share**, then **Add to Home Screen**: it opens full screen like an app and keeps your progress. Or sideload `Gemhold-iOS-unsigned.ipa` from the release (see [iPhone app](#iphone-app)). |
| **Any browser** | [fildim.github.io/gemhold](https://fildim.github.io/gemhold/). Nothing to install; progress is saved in the browser. |

A dark-lord tower defense for Windows, macOS, Linux, Android, iPhone and the web, built with **Godot 4.6**. You guard a cave of gems; heroes walk the roads to steal them. It has music and sound effects (the **Sound** button cycles Sound on, Music off and Muted), and the first lair teaches you as you play: each tip freezes the battle, darkens the screen and lights up the one thing to tap. The first time you have a skill point to spend, the map does the same for Dark Arts. **Skip tutorial** turns the tips off; **Reset progress** brings them back.

The campaign opens on a level map. Level 1 ("Mossfold Pass") is ported from the web prototype with the same rules and balance; levels 2–8 (Rimewater Ford, Gloamwood Hollow, Cinderfall Steps, The Hoard Throne, Saltmarsh Crossing, The Iron Column and Gloomspire Summit) are new. Saltmarsh Crossing is one long road full of fast swarms, The Iron Column sends armoured heroes down two roads that join before the den, and Gloomspire Summit brings heroes up four roads at once. Clearing a level Brilliant unlocks its night mission. Progress saves automatically: unlocked levels, best rating per mission and skills. Each level guards 5 gems.

## What's in a battle

- **Towers** need their own ground (moss, frost, ash). **Raised tiles** are single tiles of pale, shimmering stone set higher than the rest: any of the three towers can be built on them, whatever the ground, and they give it extra range (Hut +0.8, Shrine +0.6, Crypt +0.5). Which tower to put up high is your call. The first tower of each type costs 50 gold and each more of that type standing costs 15 more (50, 65, 80…); upgrades cost 75 (level II) and 100 (level III).
- **Three ways to attack**, none stronger overall: the **Warband Hut** fires fast, light arrows (best on crowds, blunted by armour); the **Bone Crypt** fires slow, heavy bolts that slow heroes hard; the **Cinder Shrine** holds a continuous beam on one hero that ignores armour and heats up to 5× damage, but starts cold on every new target (best on knights). `tests/tower_test.gd` compares them. Every level starts with 230 gold.
- **Threat** (dynamic difficulty): after each wave the game checks how deep into your defence its heroes got, meaning how much of the stretch your towers and den can reach they walked through. The threat multiplies hero health and only ever rises: a lot after a wave you stopped early (up to +35%), only a little after one that got close (+1–2%), so it keeps pushing without feeling impossible. It shows next to the wave counter, starts at ×1.0 each battle and tops out at ×3.0; tune it with `THREAT` in `defs.gd`.
- **Veterancy:** towers rank up from damage dealt, up to 3 ranks (+8% damage each). A tower at rank 3 that is also upgraded to level III unlocks its ability: Volley (Huts fire a second arrow), Dread (Crypt hits can terrify a hero) and Lava (heroes a Shrine kills have a 35% chance to leave a pool of burning ground).
- **Cutting** costs mana. It clears woods, frees **Gold Mines** (gold over time) and **Mana Wells** (faster mana), and razes **Hero Barracks**, which otherwise send extra heroes while waves are coming.
- **Heroes:** Peasant, Footman, Scout, Cleric (heals nearby heroes) and Knight (armoured, carries 2 gems), plus three that arrive from level 4: the **Shieldbearer** (other heroes within 1.2 tiles take 35% less damage), the **Cutpurse** (fast, fragile, carries 2 gems) and the **Warden** (his lantern clears slow and Dread from heroes around him).
- **Loose gems:** a slain carrier drops his gems and they float back along the road to the hoard. Any hero on that road (or one joined to it) with room to carry turns toward them, even back the way he came, so kill the carrier where your towers can cover the gems.
- **Targeting:** towers shoot gem carriers first, then the special support heroes (Cleric, Shieldbearer, Warden), then whoever has the least health left.
- **Loot:** a slain hero drops a coin (35%), a mana potion (15%) or nothing, never both. Coins are worth 5 gold plus 1.5× the hero's bounty, scaled by how tough the hero is this wave. Tap loot to pick it up at once; whatever is still lying on the map is gathered automatically when the next wave starts (on its timer or called early).
- **The den fights back:** your lair holds charges (1 to start). Each is a bolt it fires automatically at heroes within 2.6 tiles, gem carriers first, ignoring armour. Spent charges refill one every 8 s. The sparks circling above the cave show how many are ready.
- **Ratings and stars:** Survived ★ (you lost gems), Wicked ★★ (none lost, but a hero touched one, even if you got it back) and Brilliant ★★★ (no hero ever touched a gem).
- **Night missions:** clearing a level Brilliant unlocks the same level at night, with its own best rating and stars. You can only build where you can see; the lair, your towers and your mines and wells light the ground around them. A moon on the map marks it: faint while locked, pale when open, gold once won.
- **Dark Arts** (skill tree, on the map): every star is a skill point to spend across the Hut, Crypt and Shrine trees, or on The Hoard: a den charge, +50 starting gold or +15 max mana per point. Stars come from each mission's best rating, day and night counted separately, so replaying a lair for a better rating earns more points. There is no player XP.

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
  ui/tutorial.gd         tips on the first lair, one at a time
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
**Adding a level:** copy `levels/level_02.json`, give it a new `id`, edit it, and add its path to `LEVELS` in `scripts/main.gd`. The map has five spots; add more to `SPOTS` in `scripts/ui/level_select.gd`. Optional `intro` text shows on the start card.
In the level file, `terrain` uses `m` moss, `f` frost, `a` ash and `L` lair; a capital `M`, `F` or `A` is a raised tile of that ground. Add `"hp_mul": 1.4` to make heroes tougher on a later level. `"night": true` makes a level night-only (normally night is the unlockable mission). `sites` lists map buildings: `{"kind": "mine"|"well", "cell": [x, y]}` or `{"kind": "camp", "cell": [x, y], "path": 0, "spawn": "2p,1f", "every": 30}`. In `trees`, `T` marks woods. `paths` lists each road's corner tiles; roads start off the map edge and end next to the lair. Waves use hero codes: `p` peasant, `f` footman, `s` scout, `c` cleric, `k` knight, `b` shieldbearer, `t` cutpurse, `w` warden. For example, `"6p,2f"` is 6 peasants and 2 footmen.

## Tests

From this folder, with Godot on your PATH:

```
godot --headless --import
godot --headless --script res://tests/sim_test.gd     # plays every level by day, and at night with mid-game skills
godot --headless --script res://tests/sim_test.gd -- 6 7  # just those levels, without and with skills
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
- [x] Sound effects and music
- [x] Tutorial tips on the first lair
- [x] Builds for Windows, macOS, Linux, Android, iPhone and the web

## Publishing a new version

Raise the version in `export_presets.cfg` (Android `version/*`, Windows `application/*_version`, macOS and iOS `application/short_version` and `application/version`) and `project.godot`, commit, then tag and push:

```
git tag v0.4.0
git push origin main v0.4.0
```

GitHub Actions (`.github/workflows/release.yml`) then builds every platform and publishes them as one release; the download buttons above always point at the newest one. It also puts the web version on GitHub Pages.

**One-time setup** (repository settings on github.com):

- **Web version:** Settings > Pages > Build and deployment > Source: **GitHub Actions**. Until then the Pages step is skipped and the rest still publishes.
- **Android APK in releases:** Settings > Secrets and variables > Actions > New repository secret, named `ANDROID_DEBUG_KEYSTORE`, holding the debug keystore as base64 (`base64 -w0 debug.keystore`). It's the same key the Firebase test builds use, so the APK installs over them. Without the secret the release has no APK.

## iPhone app

Apple only lets apps onto an iPhone through the App Store, TestFlight or a signed install, and signing normally needs the $99/year developer program. The free options:

1. **Browser (easiest):** open [fildim.github.io/gemhold](https://fildim.github.io/gemhold/) in Safari, then Share > **Add to Home Screen**. It runs full screen from its own icon, offline after the first visit.
2. **Sideload the app:** every release includes `Gemhold-iOS-unsigned.ipa`, built on a GitHub Mac. Install [AltStore](https://altstore.io) or [Sideloadly](https://sideloadly.io) on a Windows PC or Mac, sign in with any free Apple ID, and install the IPA with the iPhone plugged in. With a free Apple ID the app stops opening after 7 days until you install it again from the computer (AltStore can refresh it over Wi-Fi). Turn on **Settings > Privacy & Security > Developer Mode** on the iPhone when it asks.

With a paid Apple developer account, the same workflow could sign the build and send it to TestFlight.

## Sound

Every sound effect and both music loops are synthesised by `tools/make_audio.gd` (oscillators, noise and plucked strings), so they are original. To change one, edit its function there and rebuild:

```
godot --headless -s res://tools/make_audio.gd -- coin boom   # just these, or no names for all
godot --headless --import
```

Volumes and how often each may repeat are in `SFX` at the top of `scripts/audio/audio.gd`. The music and the Shrine's crackle loop; that is set in their `.wav.import` files (`edit/loop_mode=2`).
