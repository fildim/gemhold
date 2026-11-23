# Gemhold: to do

What is still open, in one place. Tick items off (`[x]`) as they are done; add new ones at the end of their section. Last gathered 2026-11-21 (version 0.9.5, published 2026-11-22).

## Release and stores

Dropped: an App Store (iOS) release (owner, 2026-11-21).

- [x] Upload the 0.9.5 bundle (version code 28) to the Play **Alpha** track (2026-11-22; product `remove_ads` active at €3.99 incl. VAT).
- [x] Upload the 0.9.6 bundle (version code 29) to the Play **Alpha** track (2026-11-22, full rollout, in review).
- [ ] Upload the 0.9.7 bundle (`build/gemhold-0.9.7.aab`, version code 30) to the Play **Alpha** track (published everywhere else 2026-11-22: race challenges, no battle frame cap).
- [ ] Upload the 0.9.8 bundle (`build/gemhold-0.9.8.aab`, version code 31) to the Play **Alpha** track (published everywhere else 2026-11-23: Resolve visible and capped, fixed race curve, Ossuary burst).
- [ ] Apply for Google Play **production** once the 14-day closed test is over (from about 2026-12-02).
- [ ] Try the **ads** on a real phone (built in `scripts/core/ads.gd`, "Android Play" preset only).
- [x] **Google Play: one purchase only, Remove ads** (owner, 2026-11-21): one-time, €3.99 (owner, 2026-11-21); no chapter purchases, no subscription. Needs the Google Play Billing plugin, a payments profile and a Restore purchases button; the full game stays free with ads.
- [ ] **Steam: chapters as DLC** (owner, 2026-11-21): the base game is free with lairs 1–5 (the demo), every chapter is DLC at €1.99, and a bundle of all chapters at −25%. Needs: gating by chapter instead of demo/full (`Edition`), GodotSteam + the Steam app (Steam Direct fee), DLC ownership checks; full-game codes unlock every chapter; races offer only owned lairs.
- [ ] **Steam**: make the store page, then fill in the store URLs in `scripts/core/edition.gd` (empty URLs show "coming soon").
- [ ] Switch the store accounts to **trader** status before selling anything paid.

## Game

- [ ] **Music** for lairs 26–50 (25 lairs have none). Candidates wait in `Desktop\Gemhold\Music to try\new`; the owner picks each lair's track.
- [x] In-game **feedback**: Info page (full screen) with the address, tap to copy, and Open mail app (2026-11-21).
- [x] Deploy `firestore.rules` with the `feedback` collection (2026-11-22). Messages: Firebase console > Firestore > feedback.
- [ ] **Before every publish** (last done 2026-11-22 with the fixed curve: day loss only lair 20, no night losses, all 50 races won): play-test all lairs with the bot (`tests/sim_test.gd`, every lair, day and night) and re-check **race_hp** (online races) after the 2026-11-18 and 2026-11-20 retunes.
- [ ] The bot still loses its day battle on lairs 18–20 (`tests/sim_test.gd`, 2026-11-23, dynamic difficulty back): it falls at wave 4 with 7–8 towers. Look at whether their openings need easing.
- [x] **Plunder** (owner, 2026-11-21): +1 gold on a level IV Hut's first kill, one more each kill, up to +25; a tip explains it the first time a Hut reaches level IV.
- [x] **Retune after Plunder** (2026-11-21, Plunder +1 → +25): lairs 21–50 measured before and after; only The Long Siege (1.27 → 1.36) and Hallowed Fields (4.24 → 4.90) got clearly easier and were raised. Lairs 22 (×1.01) and 45 (×0.97) stay near the bot's limit.

## Ideas kept for later (not decided)

- [ ] **Heroic missions**: a third mission per lair with a twist (one tower type, no Meteor, one gem).
- [ ] **The Long Night**: endless waves on any beaten lair, with its own leaderboard.
- [x] **Per-tower aim** (2026-11-21): Aim button in the tower panel: Auto / Strongest / Closest to the cave; gem carriers always first; the Ossuary got it too on 2026-11-22 (tester feedback): its stored bolts burst at the aimed target (2026-11-23).
