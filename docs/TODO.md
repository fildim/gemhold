# Gemhold: to do

What is still open, in one place. Tick items off (`[x]`) as they are done; add new ones at the end of their section. Last gathered 2026-11-21 (version 0.9.4).

## Release and stores

Dropped: an App Store (iOS) release (owner, 2026-11-21).

- [ ] Upload `build/gemhold-0.9.4.aab` (version code 26) to the Play **Alpha** track.
- [ ] Apply for Google Play **production** once the 14-day closed test is over (from about 2026-12-02).
- [ ] Try the **ads** on a real phone (built in `scripts/core/ads.gd`, "Android Play" preset only).
- [ ] Build the **remove-ads purchase** (€2.99 suggested).
- [ ] **Chapters as purchases** (owner, 2026-11-21): lairs 1–5 free as the demo, every chapter €1.99 on its own, on Steam (DLC per chapter) and Google Play (one in-app product per chapter). Needs: gating by chapter instead of whole game (`Edition`), GodotSteam + Steam app, Google Play Billing plugin + payments profile, restore purchases; full-game codes unlock every chapter. Open: do mobile players who buy chapters still see ads? A bundle price for all chapters?
- [ ] **Steam**: make the store page, then fill in the store URLs in `scripts/core/edition.gd` (empty URLs show "coming soon").
- [ ] Switch the store accounts to **trader** status before selling anything paid.

## Game

- [ ] **Music** for lairs 26–50 (25 lairs have none). Candidates wait in `Desktop\Gemhold\Music to try\new`; the owner picks each lair's track.
- [x] In-game **feedback**: Info page (full screen) with the address, tap to copy, and Open mail app (2026-11-21).
- [ ] **Before every publish**: play-test all lairs with the bot (`tests/sim_test.gd`, every lair, day and night) and re-check **race_hp** (online races) after the 2026-11-18 and 2026-11-20 retunes.
- [ ] The bot still loses its day battle on lairs 18–20 and 50 (`tests/sim_test.gd`): look at whether they need easing.
- [ ] **Plunder** cap (+5 gold, `Defs.PLUNDER_MAX`): owner asked about +25. Bot measure 2026-11-21: lair 38 plundered 225 → 340 gold, lair 50 649 → 1312; no lair flips. Waiting for the owner's call.

## Ideas kept for later (not decided)

- [ ] **Heroic missions**: a third mission per lair with a twist (one tower type, no Meteor, one gem).
- [ ] **The Long Night**: endless waves on any beaten lair, with its own leaderboard.
- [ ] **Captive beasts**: a caged creature freed by cutting that blocks heroes on the road (needs heroes that stop to fight).
- [ ] **Per-tower targeting** in the tile panel (owner undecided; proposal: Auto / Strongest / Closest to the cave, gem carriers always first).
- [ ] **Weekly lair**: a fixed seed and rule mix shared by all players for a week.
