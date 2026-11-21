# Gemhold: to do

What is still open, in one place. Tick items off (`[x]`) as they are done; add new ones at the end of their section. Last gathered 2026-11-21 (version 0.9.4).

## Release and stores

Dropped: an App Store (iOS) release (owner, 2026-11-21).

- [ ] Upload `build/gemhold-0.9.4.aab` (version code 26) to the Play **Alpha** track.
- [ ] Apply for Google Play **production** once the 14-day closed test is over (from about 2026-12-02).
- [ ] Try the **ads** on a real phone (built in `scripts/core/ads.gd`, "Android Play" preset only).
- [ ] **Google Play: one purchase only, Remove ads** (owner, 2026-11-21): one-time, €3.99 (owner, 2026-11-21); no chapter purchases, no subscription. Needs the Google Play Billing plugin, a payments profile and a Restore purchases button; the full game stays free with ads.
- [ ] **Steam: chapters as DLC** (owner, 2026-11-21): the base game is free with lairs 1–5 (the demo), every chapter is DLC at €1.99, and a bundle of all chapters at −25%. Needs: gating by chapter instead of demo/full (`Edition`), GodotSteam + the Steam app (Steam Direct fee), DLC ownership checks; full-game codes unlock every chapter; races offer only owned lairs.
- [ ] **Steam**: make the store page, then fill in the store URLs in `scripts/core/edition.gd` (empty URLs show "coming soon").
- [ ] Switch the store accounts to **trader** status before selling anything paid.

## Game

- [ ] **Music** for lairs 26–50 (25 lairs have none). Candidates wait in `Desktop\Gemhold\Music to try\new`; the owner picks each lair's track.
- [x] In-game **feedback**: Info page (full screen) with the address, tap to copy, and Open mail app (2026-11-21).
- [ ] **Before every publish**: play-test all lairs with the bot (`tests/sim_test.gd`, every lair, day and night) and re-check **race_hp** (online races) after the 2026-11-18 and 2026-11-20 retunes.
- [ ] The bot still loses its day battle on lairs 18–20 and 50 (`tests/sim_test.gd`): look at whether they need easing.
- [x] **Plunder** (owner, 2026-11-21): +1 gold on a level IV Hut's first kill, one more each kill, up to +25; a tip explains it the first time a Hut reaches level IV.
- [x] **Retune after Plunder** (2026-11-21, Plunder +1 → +25): lairs 21–50 measured before and after; only The Long Siege (1.27 → 1.36) and Hallowed Fields (4.24 → 4.90) got clearly easier and were raised. Lairs 22 (×1.01) and 45 (×0.97) stay near the bot's limit.

## Ideas kept for later (not decided)

- [ ] **Heroic missions**: a third mission per lair with a twist (one tower type, no Meteor, one gem).
- [ ] **The Long Night**: endless waves on any beaten lair, with its own leaderboard.
- [x] **Per-tower aim** (2026-11-21): Aim button in the tower panel: Auto / Strongest / Closest to the cave; gem carriers always first; not on the Ossuary.
