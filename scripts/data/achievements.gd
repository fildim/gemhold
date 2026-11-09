class_name Achievements
extends RefCounted
## The achievements: badges with no effect on play. LIST is the order they are shown in.
## An entry with "stat" and "goal" is earned once values()[stat] reaches goal, and its card shows
## the progress; the others are decided in check_battle() or check_progress().
## record() adds a finished battle to the lifetime stats. check_battle() runs when a battle ends,
## check_progress() whenever the campaign changes; both mark new ones in the save and return their
## ids so the game can announce them.

const LIST: Array[Dictionary] = [
	# The campaign
	{"id": "first_win", "name": "First Blood", "text": "Defend your first lair."},
	{"id": "beaten3", "name": "A Foothold", "text": "Defend the first 3 lairs.", "stat": "beaten", "goal": 3},
	{"id": "beaten5", "name": "Rising Dread", "text": "Defend the first 5 lairs.", "stat": "beaten", "goal": 5},
	{"id": "beaten7", "name": "Seven Seals", "text": "Defend the first 7 lairs.", "stat": "beaten", "goal": 7},
	{"id": "chapter1", "name": "Lowland Lord", "text": "Defend every lair of Chapter I."},
	{"id": "beaten13", "name": "Unlucky for Some", "text": "Defend the first 13 lairs.", "stat": "beaten", "goal": 13},
	{"id": "beaten15", "name": "Deep in the Crusade", "text": "Defend the first 15 lairs.", "stat": "beaten", "goal": 15},
	{"id": "beaten18", "name": "Almost Home", "text": "Defend the first 18 lairs.", "stat": "beaten", "goal": 18},
	{"id": "chapter2", "name": "Crusade Crushed", "text": "Defend all twenty lairs."},

	# Ratings
	{"id": "brilliant", "name": "Untouched", "text": "Win a lair Brilliant: no hero lays a hand on a gem."},
	{"id": "brilliant5", "name": "Clean Hands", "text": "Win 5 lairs Brilliant.", "stat": "brilliant", "goal": 5},
	{"id": "brilliant10", "name": "Spotless", "text": "Win 10 lairs Brilliant.", "stat": "brilliant", "goal": 10},
	{"id": "brilliant15", "name": "Immaculate", "text": "Win 15 lairs Brilliant.", "stat": "brilliant", "goal": 15},
	{"id": "all_brilliant", "name": "Perfectionist", "text": "Win every lair Brilliant."},
	{"id": "wicked", "name": "Close Shave", "text": "Win a lair Wicked: a hero touched a gem, but none got away."},
	{"id": "survived", "name": "Battered but Standing", "text": "Win a lair after losing gems."},
	{"id": "last_gem", "name": "By a Thread", "text": "Win with a single gem left."},
	{"id": "brilliant_fast", "name": "Showing Off", "text": "Win Brilliant after calling 8 waves early."},
	{"id": "purist", "name": "Purist", "text": "Win lair 3 or later Brilliant with one kind of tower."},
	{"id": "brilliant_last", "name": "Flawless Finale", "text": "Win the last lair Brilliant."},

	# The night
	{"id": "night_win", "name": "Creature of the Night", "text": "Win a night mission."},
	{"id": "night5", "name": "Night Owl", "text": "Win 5 night missions.", "stat": "nights", "goal": 5},
	{"id": "night10", "name": "Moonlit Reign", "text": "Win 10 night missions.", "stat": "nights", "goal": 10},
	{"id": "night15", "name": "The Long Dark", "text": "Win 15 night missions.", "stat": "nights", "goal": 15},
	{"id": "all_night", "name": "Eternal Night", "text": "Win every night mission."},
	{"id": "night_brilliant", "name": "Moonlit Perfection", "text": "Win a night mission Brilliant.", "stat": "night_brilliant", "goal": 1},
	{"id": "night_brilliant5", "name": "Unseen", "text": "Win 5 night missions Brilliant.", "stat": "night_brilliant", "goal": 5},
	{"id": "night_brilliant10", "name": "Shadow Sovereign", "text": "Win 10 night missions Brilliant.", "stat": "night_brilliant", "goal": 10},
	{"id": "night_brilliant20", "name": "Master of Darkness", "text": "Win all twenty night missions Brilliant.", "stat": "night_brilliant", "goal": 20},
	{"id": "night_thread", "name": "Thread by Moonlight", "text": "Win a night mission with a single gem left."},
	{"id": "night_one", "name": "Lone Lantern", "text": "Win a night mission with one kind of tower."},
	{"id": "night_final", "name": "Dawn Never Comes", "text": "Win the last lair by night."},

	# Stars and score
	{"id": "stars10", "name": "Stargazer", "text": "Earn 10 stars.", "stat": "stars", "goal": 10},
	{"id": "stars30", "name": "Constellation", "text": "Earn 30 stars.", "stat": "stars", "goal": 30},
	{"id": "stars60", "name": "Milky Way", "text": "Earn 60 stars.", "stat": "stars", "goal": 60},
	{"id": "stars90", "name": "Night Sky", "text": "Earn 90 stars.", "stat": "stars", "goal": 90},
	{"id": "stars120", "name": "Every Star in Heaven", "text": "Earn all 120 stars.", "stat": "stars", "goal": 120},
	{"id": "score3000", "name": "Worth Counting", "text": "Score 3,000 points in one battle."},
	{"id": "score", "name": "High Roller", "text": "Score 6,000 points in one battle."},
	{"id": "score10000", "name": "Treasure Keeper", "text": "Score 10,000 points in one battle."},
	{"id": "score15000", "name": "Golden Tally", "text": "Score 15,000 points in one battle."},
	{"id": "score20000", "name": "Beyond Counting", "text": "Score 20,000 points in one battle."},
	{"id": "total10000", "name": "On the Board", "text": "Reach a total score of 10,000.", "stat": "total", "goal": 10000},
	{"id": "total50000", "name": "Climbing the Ranks", "text": "Reach a total score of 50,000.", "stat": "total", "goal": 50000},
	{"id": "total100000", "name": "Six Figures", "text": "Reach a total score of 100,000.", "stat": "total", "goal": 100000},
	{"id": "total200000", "name": "Hall of Legends", "text": "Reach a total score of 200,000.", "stat": "total", "goal": 200000},

	# Dark Arts
	{"id": "arts1", "name": "First Lesson", "text": "Spend a skill point in Dark Arts.", "stat": "spent", "goal": 1},
	{"id": "arts10", "name": "Apprentice", "text": "Spend 10 skill points in Dark Arts.", "stat": "spent", "goal": 10},
	{"id": "arts20", "name": "Dark Scholar", "text": "Spend 20 skill points in Dark Arts."},
	{"id": "arts40", "name": "Grand Warlock", "text": "Spend 40 skill points in Dark Arts.", "stat": "spent", "goal": 40},
	{"id": "arts59", "name": "Omniscient", "text": "Learn every Dark Art to its limit.", "stat": "spent", "goal": 59},
	{"id": "branch_moss", "name": "Warlord", "text": "Fill the whole Warband Hut tree."},
	{"id": "branch_frost", "name": "Necromancer", "text": "Fill the whole Bone Crypt tree."},
	{"id": "branch_ash", "name": "High Priest", "text": "Fill the whole Cinder Shrine tree."},
	{"id": "branch_den", "name": "Dragon of the Den", "text": "Fill the whole Hoard tree."},

	# How you fight
	{"id": "only_moss", "name": "Warband Only", "text": "Win lair 3 or later with Warband Huts as your only towers."},
	{"id": "only_frost", "name": "Crypt Keeper", "text": "Win lair 3 or later with Bone Crypts as your only towers."},
	{"id": "only_ash", "name": "Fire Worshipper", "text": "Win lair 3 or later with Cinder Shrines as your only towers."},
	{"id": "all_three", "name": "Balance of Power", "text": "Win with all three kinds of tower."},
	{"id": "few3", "name": "Trinity", "text": "Win with never more than 3 towers standing."},
	{"id": "few", "name": "Few but Fierce", "text": "Win lair 5 or later with never more than 5 towers standing."},
	{"id": "few_late", "name": "Lean and Mean", "text": "Win lair 15 or later with never more than 8 towers standing."},
	{"id": "towers10", "name": "Outpost", "text": "Have 10 towers standing at once."},
	{"id": "towers15", "name": "Stronghold", "text": "Have 15 towers standing at once."},
	{"id": "towers20", "name": "Citadel", "text": "Have 20 towers standing at once."},
	{"id": "maxed3", "name": "Quality Counts", "text": "End a battle with 3 towers at level III."},
	{"id": "maxed6", "name": "Iron Ring", "text": "End a battle with 6 towers at level III."},
	{"id": "maxed10", "name": "Fully Armed", "text": "End a battle with 10 towers at level III."},
	{"id": "no_upgrades", "name": "Bargain Bin", "text": "Win lair 3 or later without upgrading a tower."},
	{"id": "no_meteor", "name": "Mana Miser", "text": "Win lair 3 or later without casting a meteor."},
	{"id": "no_woods", "name": "Tree Hugger", "text": "Win lair 3 or later without cutting any woods."},
	{"id": "no_early", "name": "Patience", "text": "Win lair 3 or later without calling a wave early."},
	{"id": "no_sites", "name": "Leave Them Be", "text": "Win a lair with three or more buildings without touching one."},
	{"id": "fire_sale", "name": "Fire Sale", "text": "Sell 5 towers in one battle."},
	{"id": "hill", "name": "King of the Hill", "text": "Win with a tower on every raised tile of a lair that has three or more."},
	{"id": "ability", "name": "Battle-Hardened", "text": "Have a tower learn its ability."},
	{"id": "ability_moss", "name": "Twin Arrows", "text": "Have a Warband Hut learn Volley."},
	{"id": "ability_frost", "name": "Fear Itself", "text": "Have a Bone Crypt learn Dread."},
	{"id": "ability_ash", "name": "The Floor Is Lava", "text": "Have a Cinder Shrine learn Lava."},
	{"id": "ability_all", "name": "Masters of War", "text": "Have all three abilities learned in one battle."},
	{"id": "abilities5", "name": "Veteran Corps", "text": "Have 5 towers learn their ability in one battle."},

	# Great moments
	{"id": "kills100", "name": "Bloodbath", "text": "Slay 100 heroes in one battle."},
	{"id": "kills200", "name": "Massacre", "text": "Slay 200 heroes in one battle."},
	{"id": "kills300", "name": "No Survivors", "text": "Slay 300 heroes in one battle."},
	{"id": "meteor3", "name": "Falling Star", "text": "Slay 3 heroes with one meteor."},
	{"id": "meteor5", "name": "Rain of Fire", "text": "Slay 5 heroes with one meteor."},
	{"id": "meteor8", "name": "Extinction Event", "text": "Slay 8 heroes with one meteor."},
	{"id": "meteor12", "name": "Wrath of the Sky", "text": "Slay 12 heroes with one meteor."},
	{"id": "meteors5", "name": "Skywatcher", "text": "Cast 5 meteors in one battle."},
	{"id": "meteors10", "name": "Meteor Shower", "text": "Cast 10 meteors in one battle."},
	{"id": "den10", "name": "Guard Dog", "text": "Slay 10 heroes with the den in one battle."},
	{"id": "den25", "name": "Three-Headed Hound", "text": "Slay 25 heroes with the den in one battle."},
	{"id": "saved1", "name": "Not So Fast", "text": "Slay a hero carrying a gem."},
	{"id": "saved5", "name": "Gem Snatcher", "text": "Win back 5 gems from heroes in one battle."},
	{"id": "champion", "name": "Kingslayer", "text": "Slay a Champion."},
	{"id": "early8", "name": "Impatient", "text": "Call 8 waves early in one battle."},
	{"id": "early12", "name": "In a Hurry", "text": "Call 12 waves early in one battle."},
	{"id": "early16", "name": "Can't Wait", "text": "Call 16 waves early in one battle."},
	{"id": "early_all", "name": "Bring Them All", "text": "Win after calling every wave but one early."},
	{"id": "skip100", "name": "Time Is Gold", "text": "Skip 100 seconds of countdown in one battle."},
	{"id": "skip200", "name": "Hourglass Breaker", "text": "Skip 200 seconds of countdown in one battle."},
	{"id": "skip300", "name": "Tomorrow Is Today", "text": "Skip 300 seconds of countdown in one battle."},
	{"id": "rich", "name": "Dragon's Hoard", "text": "Win with 1,000 gold or more left over."},
	{"id": "rich1500", "name": "Midas", "text": "Win with 1,500 gold or more left over."},
	{"id": "broke", "name": "Broke and Proud", "text": "Win with 5 gold or less left over."},
	{"id": "so_close", "name": "So Close", "text": "Lose your last gem during the final wave."},
	{"id": "overrun", "name": "Overrun", "text": "Lose every gem within the first 5 waves."},

	# The land
	{"id": "raze", "name": "Barracks Breaker", "text": "Raze a hero barracks."},
	{"id": "raze2", "name": "Demolition Crew", "text": "Raze 2 barracks in one battle."},
	{"id": "raze3", "name": "Scorched Earth", "text": "Raze 3 barracks in one battle."},
	{"id": "landlord", "name": "Lord of the Land", "text": "Free or raze every building in a lair that has three or more."},
	{"id": "woods10", "name": "Lumberjack", "text": "Cut 10 patches of woods in one battle."},
	{"id": "woods25", "name": "Deforestation", "text": "Cut 25 patches of woods in one battle."},
	{"id": "camps10", "name": "Wrecking Crew", "text": "Raze 10 barracks in all.", "stat": "camps", "goal": 10},
	{"id": "camps50", "name": "Barracks Bane", "text": "Raze 50 barracks in all.", "stat": "camps", "goal": 50},
	{"id": "camps150", "name": "Nothing Left Standing", "text": "Raze 150 barracks in all.", "stat": "camps", "goal": 150},
	{"id": "mines10", "name": "Prospector", "text": "Free 10 gold mines in all.", "stat": "mines", "goal": 10},
	{"id": "mines50", "name": "Mine Baron", "text": "Free 50 gold mines in all.", "stat": "mines", "goal": 50},
	{"id": "wells10", "name": "Water Diviner", "text": "Free 10 mana wells in all.", "stat": "wells", "goal": 10},
	{"id": "wells50", "name": "Wellspring", "text": "Free 50 mana wells in all.", "stat": "wells", "goal": 50},
	{"id": "woods100", "name": "Timber Trader", "text": "Cut 100 patches of woods in all.", "stat": "woods", "goal": 100},
	{"id": "woods500", "name": "The Great Clearing", "text": "Cut 500 patches of woods in all.", "stat": "woods", "goal": 500},

	# Heroes slain, all battles together
	{"id": "kills_all100", "name": "Blooded", "text": "Slay 100 heroes in all.", "stat": "kills", "goal": 100},
	{"id": "kills_all500", "name": "Butcher", "text": "Slay 500 heroes in all.", "stat": "kills", "goal": 500},
	{"id": "kills1000", "name": "Hero Bane", "text": "Slay 1,000 heroes in all.", "stat": "kills", "goal": 1000},
	{"id": "kills2500", "name": "Grim Harvest", "text": "Slay 2,500 heroes in all.", "stat": "kills", "goal": 2500},
	{"id": "kills5000", "name": "Scourge of the Realm", "text": "Slay 5,000 heroes in all.", "stat": "kills", "goal": 5000},
	{"id": "kills10000", "name": "Legend Eater", "text": "Slay 10,000 heroes in all.", "stat": "kills", "goal": 10000},
	{"id": "kills25000", "name": "Empty Villages", "text": "Slay 25,000 heroes in all.", "stat": "kills", "goal": 25000},
	{"id": "kills50000", "name": "Doom of Nations", "text": "Slay 50,000 heroes in all.", "stat": "kills", "goal": 50000},
	{"id": "kills100000", "name": "The End of Heroes", "text": "Slay 100,000 heroes in all.", "stat": "kills", "goal": 100000},
	{"id": "slain_p1", "name": "Pitchforks Down", "text": "Slay 250 Peasants.", "stat": "slain_p", "goal": 250},
	{"id": "slain_p2", "name": "Bad Harvest", "text": "Slay 2,500 Peasants.", "stat": "slain_p", "goal": 2500},
	{"id": "slain_f1", "name": "Rank and File", "text": "Slay 250 Footmen.", "stat": "slain_f", "goal": 250},
	{"id": "slain_f2", "name": "The Broken Line", "text": "Slay 2,500 Footmen.", "stat": "slain_f", "goal": 2500},
	{"id": "slain_s1", "name": "Eyes Put Out", "text": "Slay 100 Scouts.", "stat": "slain_s", "goal": 100},
	{"id": "slain_s2", "name": "Nobody Reports Back", "text": "Slay 1,000 Scouts.", "stat": "slain_s", "goal": 1000},
	{"id": "slain_c1", "name": "No Last Rites", "text": "Slay 100 Clerics.", "stat": "slain_c", "goal": 100},
	{"id": "slain_c2", "name": "Faith Healer", "text": "Slay 1,000 Clerics.", "stat": "slain_c", "goal": 1000},
	{"id": "slain_k1", "name": "Dented Armour", "text": "Slay 100 Knights.", "stat": "slain_k", "goal": 100},
	{"id": "slain_k2", "name": "Chivalry Is Dead", "text": "Slay 1,000 Knights.", "stat": "slain_k", "goal": 1000},
	{"id": "slain_b1", "name": "Shields Splintered", "text": "Slay 100 Shieldbearers.", "stat": "slain_b", "goal": 100},
	{"id": "slain_b2", "name": "Nothing to Hide Behind", "text": "Slay 1,000 Shieldbearers.", "stat": "slain_b", "goal": 1000},
	{"id": "slain_t1", "name": "Stop, Thief!", "text": "Slay 100 Cutpurses.", "stat": "slain_t", "goal": 100},
	{"id": "slain_t2", "name": "Crime Doesn't Pay", "text": "Slay 1,000 Cutpurses.", "stat": "slain_t", "goal": 1000},
	{"id": "slain_w1", "name": "Wards Broken", "text": "Slay 100 Wardens.", "stat": "slain_w", "goal": 100},
	{"id": "slain_w2", "name": "Warden's Last Watch", "text": "Slay 1,000 Wardens.", "stat": "slain_w", "goal": 1000},
	{"id": "slain_h1", "name": "Shoot the Messenger", "text": "Slay 100 Heralds.", "stat": "slain_h", "goal": 100},
	{"id": "slain_h2", "name": "No More News", "text": "Slay 1,000 Heralds.", "stat": "slain_h", "goal": 1000},
	{"id": "slain_r1", "name": "Cooled Off", "text": "Slay 100 Berserkers.", "stat": "slain_r", "goal": 100},
	{"id": "slain_r2", "name": "Anger Management", "text": "Slay 1,000 Berserkers.", "stat": "slain_r", "goal": 1000},
	{"id": "slain_x1", "name": "Regicide", "text": "Slay 10 Champions.", "stat": "slain_x", "goal": 10},
	{"id": "slain_x2", "name": "Champion of Champions", "text": "Slay 50 Champions.", "stat": "slain_x", "goal": 50},

	# Your weapons, all battles together
	{"id": "by_moss1", "name": "Arrow Storm", "text": "Slay 100 heroes with Warband Huts.", "stat": "by_moss", "goal": 100},
	{"id": "by_moss2", "name": "Sky Full of Arrows", "text": "Slay 1,000 heroes with Warband Huts.", "stat": "by_moss", "goal": 1000},
	{"id": "by_moss3", "name": "Warband Legend", "text": "Slay 5,000 heroes with Warband Huts.", "stat": "by_moss", "goal": 5000},
	{"id": "by_frost1", "name": "Cold Comfort", "text": "Slay 100 heroes with Bone Crypts.", "stat": "by_frost", "goal": 100},
	{"id": "by_frost2", "name": "Bone Collector", "text": "Slay 1,000 heroes with Bone Crypts.", "stat": "by_frost", "goal": 1000},
	{"id": "by_frost3", "name": "Crypt Legend", "text": "Slay 5,000 heroes with Bone Crypts.", "stat": "by_frost", "goal": 5000},
	{"id": "by_ash1", "name": "Slow Burn", "text": "Slay 100 heroes with Cinder Shrines.", "stat": "by_ash", "goal": 100},
	{"id": "by_ash2", "name": "Ashes to Ashes", "text": "Slay 1,000 heroes with Cinder Shrines.", "stat": "by_ash", "goal": 1000},
	{"id": "by_ash3", "name": "Shrine Legend", "text": "Slay 5,000 heroes with Cinder Shrines.", "stat": "by_ash", "goal": 5000},
	{"id": "den_all50", "name": "Bad Neighbour", "text": "Slay 50 heroes with the den.", "stat": "den_kills", "goal": 50},
	{"id": "den_all500", "name": "Do Not Disturb", "text": "Slay 500 heroes with the den.", "stat": "den_kills", "goal": 500},
	{"id": "den_all2000", "name": "Home Sweet Home", "text": "Slay 2,000 heroes with the den.", "stat": "den_kills", "goal": 2000},
	{"id": "meteor_all25", "name": "Amateur Astronomer", "text": "Cast 25 meteors.", "stat": "meteors", "goal": 25},
	{"id": "meteor_all100", "name": "Star Caller", "text": "Cast 100 meteors.", "stat": "meteors", "goal": 100},
	{"id": "meteor_all500", "name": "Sky Breaker", "text": "Cast 500 meteors.", "stat": "meteors", "goal": 500},
	{"id": "meteor_kills100", "name": "Impact Crater", "text": "Slay 100 heroes with meteors.", "stat": "meteor_kills", "goal": 100},
	{"id": "meteor_kills1000", "name": "Cratered Landscape", "text": "Slay 1,000 heroes with meteors.", "stat": "meteor_kills", "goal": 1000},
	{"id": "dread100", "name": "Boo!", "text": "Terrify 100 heroes with Dread.", "stat": "dreads", "goal": 100},
	{"id": "dread1000", "name": "Nightmare Fuel", "text": "Terrify 1,000 heroes with Dread.", "stat": "dreads", "goal": 1000},
	{"id": "lava25", "name": "Hot Spring", "text": "Leave 25 pools of Lava.", "stat": "lavas", "goal": 25},
	{"id": "lava250", "name": "River of Fire", "text": "Leave 250 pools of Lava.", "stat": "lavas", "goal": 250},
	{"id": "abilities25", "name": "War College", "text": "Have 25 towers learn their ability.", "stat": "abilities", "goal": 25},
	{"id": "abilities100", "name": "Old Guard", "text": "Have 100 towers learn their ability.", "stat": "abilities", "goal": 100},

	# Building and treasure, all battles together
	{"id": "built50", "name": "Foreman", "text": "Build 50 towers.", "stat": "built", "goal": 50},
	{"id": "built250", "name": "Master Mason", "text": "Build 250 towers.", "stat": "built", "goal": 250},
	{"id": "built1000", "name": "Empire of Stone", "text": "Build 1,000 towers.", "stat": "built", "goal": 1000},
	{"id": "built_moss", "name": "Hut Raiser", "text": "Build 100 Warband Huts.", "stat": "built_moss", "goal": 100},
	{"id": "built_frost", "name": "Grave Digger", "text": "Build 100 Bone Crypts.", "stat": "built_frost", "goal": 100},
	{"id": "built_ash", "name": "Fire Tender", "text": "Build 100 Cinder Shrines.", "stat": "built_ash", "goal": 100},
	{"id": "high10", "name": "Room with a View", "text": "Build 10 towers on raised ground.", "stat": "high_built", "goal": 10},
	{"id": "high50", "name": "High Ground", "text": "Build 50 towers on raised ground.", "stat": "high_built", "goal": 50},
	{"id": "upgrades25", "name": "Home Improvement", "text": "Upgrade towers 25 times.", "stat": "upgrades", "goal": 25},
	{"id": "upgrades100", "name": "Bigger and Better", "text": "Upgrade towers 100 times.", "stat": "upgrades", "goal": 100},
	{"id": "upgrades500", "name": "Never Good Enough", "text": "Upgrade towers 500 times.", "stat": "upgrades", "goal": 500},
	{"id": "sold1", "name": "Change of Heart", "text": "Sell a tower.", "stat": "sold", "goal": 1},
	{"id": "sold25", "name": "Second Thoughts", "text": "Sell 25 towers.", "stat": "sold", "goal": 25},
	{"id": "sold100", "name": "Everything Must Go", "text": "Sell 100 towers.", "stat": "sold", "goal": 100},
	{"id": "spent10k", "name": "Big Spender", "text": "Spend 10,000 gold on towers.", "stat": "gold_spent", "goal": 10000},
	{"id": "spent100k", "name": "War Economy", "text": "Spend 100,000 gold on towers.", "stat": "gold_spent", "goal": 100000},
	{"id": "spent1m", "name": "Millionaire's Folly", "text": "Spend 1,000,000 gold on towers.", "stat": "gold_spent", "goal": 1000000},
	{"id": "coins100", "name": "Pocket Change", "text": "Pick up 100 coins.", "stat": "coins", "goal": 100},
	{"id": "coins1000", "name": "Coin Purse", "text": "Pick up 1,000 coins.", "stat": "coins", "goal": 1000},
	{"id": "coins5000", "name": "Counting House", "text": "Pick up 5,000 coins.", "stat": "coins", "goal": 5000},
	{"id": "potions50", "name": "Sip of Mana", "text": "Pick up 50 potions.", "stat": "potions", "goal": 50},
	{"id": "potions500", "name": "Alchemist's Shelf", "text": "Pick up 500 potions.", "stat": "potions", "goal": 500},
	{"id": "saved10", "name": "Finders Keepers", "text": "Win back 10 gems from heroes in all.", "stat": "gems_saved", "goal": 10},
	{"id": "saved100", "name": "Gem Hunter", "text": "Win back 100 gems from heroes in all.", "stat": "gems_saved", "goal": 100},
	{"id": "saved500", "name": "What's Mine Is Mine", "text": "Win back 500 gems from heroes in all.", "stat": "gems_saved", "goal": 500},
	{"id": "lost50", "name": "Butterfingers", "text": "Lose 50 gems in all.", "stat": "gems_lost", "goal": 50},

	# Time served
	{"id": "battles10", "name": "Getting Started", "text": "Fight 10 battles.", "stat": "battles", "goal": 10},
	{"id": "battles50", "name": "Regular", "text": "Fight 50 battles.", "stat": "battles", "goal": 50},
	{"id": "battles100", "name": "Campaigner", "text": "Fight 100 battles.", "stat": "battles", "goal": 100},
	{"id": "battles250", "name": "Veteran of the Dark", "text": "Fight 250 battles.", "stat": "battles", "goal": 250},
	{"id": "battles500", "name": "Endless War", "text": "Fight 500 battles.", "stat": "battles", "goal": 500},
	{"id": "wins5", "name": "Winning Streak", "text": "Win 5 battles.", "stat": "wins", "goal": 5},
	{"id": "wins25", "name": "Conqueror", "text": "Win 25 battles.", "stat": "wins", "goal": 25},
	{"id": "wins50", "name": "Dark Lord", "text": "Win 50 battles.", "stat": "wins", "goal": 50},
	{"id": "wins100", "name": "Overlord", "text": "Win 100 battles.", "stat": "wins", "goal": 100},
	{"id": "wins250", "name": "Undying Tyrant", "text": "Win 250 battles.", "stat": "wins", "goal": 250},
	{"id": "losses1", "name": "A Bitter Taste", "text": "Lose a battle.", "stat": "losses", "goal": 1},
	{"id": "losses10", "name": "Learning the Hard Way", "text": "Lose 10 battles.", "stat": "losses", "goal": 10},
	{"id": "losses50", "name": "Never Give Up", "text": "Lose 50 battles.", "stat": "losses", "goal": 50},
	{"id": "hour1", "name": "Settling In", "text": "Spend an hour on the battlefield.", "stat": "seconds", "goal": 3600},
	{"id": "hour5", "name": "Dedicated", "text": "Spend 5 hours on the battlefield.", "stat": "seconds", "goal": 18000},
	{"id": "hour24", "name": "A Full Day of Darkness", "text": "Spend 24 hours on the battlefield.", "stat": "seconds", "goal": 86400},
	{"id": "skipped1000", "name": "Clock Watcher", "text": "Skip 1,000 seconds of countdown in all.", "stat": "skipped", "goal": 1000},
	{"id": "skipped5000", "name": "Time Thief", "text": "Skip 5,000 seconds of countdown in all.", "stat": "skipped", "goal": 5000},

	# Online races
	{"id": "race1", "name": "Off the Line", "text": "Finish an online race.", "stat": "races", "goal": 1},
	{"id": "race10", "name": "Rival Hunter", "text": "Finish 10 online races.", "stat": "races", "goal": 10},
	{"id": "race50", "name": "Racing Season", "text": "Finish 50 online races.", "stat": "races", "goal": 50},
	{"id": "race_win1", "name": "First Past the Post", "text": "Win an online race.", "stat": "race_wins", "goal": 1},
	{"id": "race_win5", "name": "Front Runner", "text": "Win 5 online races.", "stat": "race_wins", "goal": 5},
	{"id": "race_win25", "name": "Race Master", "text": "Win 25 online races.", "stat": "race_wins", "goal": 25},
	{"id": "race_win100", "name": "Undisputed", "text": "Win 100 online races.", "stat": "race_wins", "goal": 100},
	{"id": "race_loss", "name": "Good Sport", "text": "Lose an online race.", "stat": "race_losses", "goal": 1},
	{"id": "race_draw", "name": "Dead Heat", "text": "Draw an online race.", "stat": "race_draws", "goal": 1},
]

const SCORE_GOAL := 6000


static func find(id: String) -> Dictionary:
	for a in LIST:
		if a["id"] == id:
			return a
	return {}


## Adds a finished battle to the lifetime stats. Online races don't count here.
static func record(save: SaveData, sim: GameSim) -> void:
	save.add_stat("kills", sim.kills)
	save.add_stat("battles", 1)
	save.add_stat("wins", 1 if sim.won else 0)
	save.stats["losses"] = int(save.stats["battles"]) - int(save.stats["wins"])
	for code: String in sim.kills_by:
		save.add_stat("slain_" + code, sim.kills_by[code])
	for type: String in sim.kills_tower:
		save.add_stat("by_" + type, sim.kills_tower[type])
	save.add_stat("den_kills", _den_kills(sim))
	save.add_stat("meteors", sim.meteors)
	save.add_stat("meteor_kills", sim.meteor_kills)
	save.add_stat("built", sim.towers_built)
	save.add_stat("high_built", sim.high_built)
	save.add_stat("upgrades", sim.upgrades)
	save.add_stat("sold", sim.sold)
	save.add_stat("gold_spent", sim.gold_spent)
	save.add_stat("woods", sim.woods_cut)
	save.add_stat("coins", sim.coins)
	save.add_stat("potions", sim.potions)
	save.add_stat("gems_saved", sim.gems_saved)
	save.add_stat("gems_lost", sim.lost)
	save.add_stat("dreads", sim.dreads)
	save.add_stat("lavas", sim.lavas)
	save.add_stat("abilities", sim.abilities)
	save.add_stat("skipped", sim.skipped)
	save.add_stat("seconds", int(sim.time))
	for type: String in sim.built_count:
		save.add_stat("built_" + type, sim.built_count[type])
	for s: GameSim.Site in sim.sites.values():
		if s.owned:
			save.add_stat({"mine": "mines", "well": "wells", "camp": "camps"}[s.kind], 1)


## Slain by neither a tower nor a meteor: the den's bolts.
static func _den_kills(sim: GameSim) -> int:
	var n := sim.kills - sim.meteor_kills
	for type: String in sim.kills_tower:
		n -= int(sim.kills_tower[type])
	return n


## After a battle (already recorded in the save, stats included). number is the lair's place in
## the campaign, from 1. Returns the ids earned just now.
static func check_battle(save: SaveData, sim: GameSim, number: int) -> Array[String]:
	var got: Array[String] = []
	var kinds := sim.built.size()
	var razed := 0
	var owned := 0
	for s: GameSim.Site in sim.sites.values():
		if s.owned:
			owned += 1
			if s.kind == "camp":
				razed += 1
	var maxed := 0
	var on_high := 0
	for tw: GameSim.Tower in sim.towers.values():
		if tw.lvl >= 3:
			maxed += 1
		if sim.level.high.has(tw.cell):
			on_high += 1
	for n in [100, 200, 300]:
		_try(save, got, "kills%d" % n, sim.kills >= n)
	for n in [3, 5, 8, 12]:
		_try(save, got, "meteor%d" % n, sim.best_meteor >= n)
	for n in [5, 10]:
		_try(save, got, "meteors%d" % n, sim.meteors >= n)
	for n in [10, 25]:
		_try(save, got, "den%d" % n, _den_kills(sim) >= n)
		_try(save, got, "woods%d" % n, sim.woods_cut >= n)
	for n in [1, 5]:
		_try(save, got, "saved%d" % n, sim.gems_saved >= n)
	for n in [8, 12, 16]:
		_try(save, got, "early%d" % n, sim.early_calls >= n)
	for n in [100, 200, 300]:
		_try(save, got, "skip%d" % n, sim.skipped >= n)
	for n in [10, 15, 20]:
		_try(save, got, "towers%d" % n, sim.most_towers >= n)
	for n in [3, 6, 10]:
		_try(save, got, "maxed%d" % n, maxed >= n)
	_try(save, got, "ability", sim.abilities > 0)
	for type: String in ["moss", "frost", "ash"]:
		_try(save, got, "ability_" + type, sim.learned.has(type))
	_try(save, got, "ability_all", sim.learned.size() >= 3)
	_try(save, got, "abilities5", sim.abilities >= 5)
	_try(save, got, "champion", int(sim.kills_by.get("x", 0)) > 0)
	_try(save, got, "fire_sale", sim.sold >= 5)
	_try(save, got, "raze", razed > 0)
	_try(save, got, "raze2", razed >= 2)
	_try(save, got, "raze3", razed >= 3)
	if sim.won:
		var rank := sim.rank()
		var night := sim.level.night
		var last_gem := sim.level.gems - sim.lost == 1
		_try(save, got, "first_win", true)
		_try(save, got, "brilliant", rank == "Brilliant")
		_try(save, got, "wicked", rank == "Wicked")
		_try(save, got, "survived", rank == "Survived")
		_try(save, got, "brilliant_fast", rank == "Brilliant" and sim.early_calls >= 8)
		_try(save, got, "purist", rank == "Brilliant" and number >= 3 and kinds == 1)
		_try(save, got, "brilliant_last", rank == "Brilliant" and number >= 20)
		_try(save, got, "night_win", night)
		_try(save, got, "night_thread", night and last_gem)
		_try(save, got, "night_one", night and kinds == 1)
		_try(save, got, "night_final", night and number >= 20)
		_try(save, got, "last_gem", last_gem)
		_try(save, got, "landlord", sim.sites.size() >= 3 and owned == sim.sites.size())
		_try(save, got, "no_sites", sim.sites.size() >= 3 and owned == 0)
		_try(save, got, "hill", sim.level.high.size() >= 3 and on_high == sim.level.high.size())
		_try(save, got, "rich", sim.gold >= 1000)
		_try(save, got, "rich1500", sim.gold >= 1500)
		_try(save, got, "broke", sim.gold <= 5)
		_try(save, got, "all_three", kinds == 3)
		_try(save, got, "few3", sim.most_towers <= 3)
		_try(save, got, "few", number >= 5 and sim.most_towers <= 5)
		_try(save, got, "few_late", number >= 15 and sim.most_towers <= 8)
		_try(save, got, "early_all", sim.early_calls >= sim.level.waves.size() - 1)
		var score := sim.score(number)
		_try(save, got, "score", score >= SCORE_GOAL)
		for n in [3000, 10000, 15000, 20000]:
			_try(save, got, "score%d" % n, score >= n)
		if number >= 3:
			_try(save, got, "no_upgrades", sim.upgrades == 0)
			_try(save, got, "no_meteor", sim.meteors == 0)
			_try(save, got, "no_woods", sim.woods_cut == 0)
			_try(save, got, "no_early", sim.early_calls == 0)
			if kinds == 1:
				_try(save, got, "only_" + str(sim.built.keys()[0]), true)
	else:
		_try(save, got, "so_close", sim.wave >= sim.level.waves.size())
		_try(save, got, "overrun", sim.wave <= 5)
	return got


## Everything a "stat" achievement can count: the lifetime stats plus what the campaign shows.
## ids is every lair's level id in campaign order.
static func values(save: SaveData, ids: Array) -> Dictionary:
	var v := save.stats.duplicate()
	var beaten := 0
	var brilliant := 0
	var nights := 0
	var night_brilliant := 0
	for i in ids.size():
		var id: String = ids[i]
		if save.stars(id) > 0 and i == beaten:
			beaten += 1   # counted only while the run of beaten lairs from the start holds
		if save.best_rank(id) == "Brilliant":
			brilliant += 1
		var night := SaveData.mission_id(id, true)
		if save.stars(night) > 0:
			nights += 1
		if save.best_rank(night) == "Brilliant":
			night_brilliant += 1
	v["beaten"] = beaten
	v["brilliant"] = brilliant
	v["nights"] = nights
	v["night_brilliant"] = night_brilliant
	v["stars"] = save.points_total()
	v["total"] = save.total_score()
	v["spent"] = save.points_spent()
	return v


## Campaign-wide ones. ids is every lair's level id in campaign order; chapters hold `per_chapter` lairs.
static func check_progress(save: SaveData, ids: Array, per_chapter := 10) -> Array[String]:
	var got: Array[String] = []
	var v := values(save, ids)
	for a: Dictionary in LIST:
		if a.has("stat"):
			_try(save, got, a["id"], int(v.get(a["stat"], 0)) >= int(a["goal"]))
	# Also battle ones the save proves, for players who won before achievements existed.
	_try(save, got, "first_win", save.points_total() > 0)
	_try(save, got, "brilliant", v["brilliant"] > 0)
	_try(save, got, "night_win", v["nights"] > 0)
	_try(save, got, "chapter1", v["beaten"] >= mini(per_chapter, ids.size()))
	_try(save, got, "chapter2", v["beaten"] >= ids.size())
	_try(save, got, "all_brilliant", v["brilliant"] >= ids.size())
	_try(save, got, "all_night", v["nights"] >= ids.size())
	_try(save, got, "arts20", v["spent"] >= 20)
	for tree: String in Defs.SKILLS:
		var full := true
		for sk: Dictionary in Defs.SKILLS[tree]:
			full = full and int(save.skills.get(sk["id"], 0)) >= int(sk["max"])
		_try(save, got, "branch_" + tree, full)
	return got


static func _try(save: SaveData, got: Array[String], id: String, ok: bool) -> void:
	if ok and save.earn(id):
		got.append(id)
