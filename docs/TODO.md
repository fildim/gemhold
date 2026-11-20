# Gemhold: to do

What is still open, in one place. Tick items off (`[x]`) as they are done; add new ones at the end of their section. Last gathered 2026-11-21 (version 0.9.4).

## Release and stores

- [ ] Upload `build/gemhold-0.9.4.aab` (version code 26) to the Play **Alpha** track.
- [ ] Apply for Google Play **production** once the 14-day closed test is over (from about 2026-12-02).
- [ ] Try the **ads** on a real phone (built in `scripts/core/ads.gd`, "Android Play" preset only).
- [ ] Build the **remove-ads purchase** (€2.99 suggested).
- [ ] **Steam**: make the store page (full game €4.99), then fill in the store URLs in `scripts/core/edition.gd` (empty URLs show "coming soon").
- [ ] Switch the store accounts to **trader** status before selling anything paid.
- [ ] **iOS**: only an unsigned IPA exists; a real App Store release needs an Apple developer account.

## Game

- [ ] **Music** for lairs 26–50 (25 lairs have none). Candidates wait in `Desktop\Gemhold\Music to try\new`; the owner picks each lair's track.
- [ ] In-game **feedback button** (testers now use Play private reviews or contactgemhold@gmail.com).
- [ ] Re-check **race_hp** (online races) after the 2026-11-18 and 2026-11-20 retunes.
- [ ] The bot still loses its day battle on lairs 18–20 and 50 (`tests/sim_test.gd`): look at whether they need easing.
- [ ] **Plunder** cap (+5 gold, `Defs.PLUNDER_MAX`) was a starting value: raise it or keep it.

## Ideas kept for later (not decided)

- [ ] **Heroic missions**: a third mission per lair with a twist (one tower type, no Meteor, one gem).
- [ ] **The Long Night**: endless waves on any beaten lair, with its own leaderboard.
- [ ] **Captive beasts**: a caged creature freed by cutting that blocks heroes on the road (needs heroes that stop to fight).
- [ ] **Per-tower targeting** (weakest, strongest, nearest the cave) in the tile panel.
- [ ] **Weekly lair**: a fixed seed and rule mix shared by all players for a week.
