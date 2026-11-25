class_name GameIcon
extends Control
## A round, framed picture for a hero, tower, map building, skill, spell or achievement, drawn in
## code like everything else (towers, heroes and buildings come from Art, so they match the map).
## key: "hero:k", "tower:frost", "site:mine", "skill:moss_dmg", "spell:meteor", "ach:night5", or a
## bare glyph name ("skull", "moon", ...). lit: full colour with a gold rim; otherwise dimmed.

const GOLD := Color("e8b84a")
const BONE := Color("efe4cc")
const INK := Color("1a120c")

@export var key := ""
@export var lit := true
@export var framed := true   # the round medallion behind the picture

## Achievement id -> glyph, for those a prefix can't decide (see for_achievement).
const ACH := {
	"first_win": "swords", "chapter1": "banner", "chapter2": "banner", "wicked": "hand", "survived": "gem_broken",
	"last_gem": "gem", "purist": "tower:moss", "few3": "tower:frost", "few": "tower:frost", "few_late": "tower:frost",
	"all_three": "towers", "no_upgrades": "medal", "no_meteor": "medal", "no_woods": "tree", "no_early": "hourglass",
	"no_sites": "medal", "fire_sale": "coin", "hill": "hill", "champion": "hero:x", "rich": "coins", "rich1500": "coins",
	"broke": "coin", "so_close": "gem_broken", "overrun": "gem_broken", "landlord": "site:mine", "lost50": "gem_broken",
	"race_loss": "flag", "race_draw": "flag", "brilliant_fast": "hourglass", "brilliant_last": "crown", "night_final": "moon",
	"night_thread": "moon", "night_one": "moon",
	"chapter3": "banner", "mastery_longhouse": "tower:moss", "mastery_lodge": "tower:moss", "mastery_ossuary": "tower:frost",
	"mastery_mausoleum": "tower:frost", "mastery_twin": "tower:ash", "mastery_sunlance": "tower:ash", "mastery_all": "towers",
	"masteries25": "up", "masteries100": "up", "twin_kills": "tower:ash", "hunter_champion": "hero:x",
	"sink1": "hero:l", "sink_all": "hero:l", "drowned100": "hero:l",
	"collapse_kill": "hero:e", "collapses25": "hero:e", "sluice5": "site:sluice", "sluices50": "site:sluice", "dry_feet": "hero:m",
	"diver_meteor": "meteor", "altars10": "site:altar",
	"chapter4": "banner", "sapper_keg": "hero:a", "no_stun": "hero:a", "rubble10": "hero:u", "trebuchet_fast": "hero:u",
	"silence_proof": "hero:i", "pavior_early": "hero:v", "beacons10": "site:beacon", "workshops10": "site:workshop", "night_dusk": "moon",
	"chapter5": "crown", "final_brilliant": "hero:S", "final_night": "moon", "tier3": "book",
	"skylancer10": "hero:y", "shield_waste": "hero:j", "chant_broken5": "hero:n", "chapel_first": "site:chapel", "hallowed_none": "site:chapel",
	"seraph_no_raise": "hero:S", "chapels25": "site:chapel", "ossuary_burst": "tower:frost", "sunlance3": "tower:ash", "mastery_one_each": "towers",
}
## Prefixes, checked in order: the first one an id starts with gives its glyph.
const ACH_PREFIX := [
	["slain_", ""], ["by_", ""], ["built_", ""], ["only_", ""], ["ability_", ""], ["branch_", ""],
	["night", "moon"], ["brilliant", "gem"], ["all_brilliant", "gem"], ["all_night", "moon"], ["beaten", "banner"],
	["stars", "star"], ["score", "trophy"], ["total", "trophy"], ["arts", "book"], ["towers", "towers"], ["maxed", "up"],
	["upgrades", "up"], ["abilit", "spark"], ["kills", "skull"], ["meteor", "meteor"], ["den", "orb"], ["saved", "gem"],
	["early", "hourglass"], ["skip", "hourglass"], ["hour", "hourglass"], ["raze", "site:camp"], ["camps", "site:camp"],
	["mines", "site:mine"], ["wells", "site:well"], ["woods", "tree"], ["dread", "dread"], ["lava", "flame"],
	["built", "towers"], ["high", "hill"], ["sold", "coin"], ["spent", "coins"], ["coins", "coins"], ["potions", "potion"],
	["battles", "swords"], ["wins", "swords"], ["losses", "gem_broken"], ["race", "flag"],
]
## Skill id suffix -> the badge on its tower.
const SKILL_BADGE := {"dmg": "blade", "drill": "blade", "rate": "rate", "range": "range", "vet": "vet", "legend": "crown"}
const ABILITY_BADGE := {"moss": "volley", "frost": "dread", "ash": "flame"}
const HOARD := {"den_charge": "orb", "hoard_gold": "coins", "hoard_mana": "potion", "hoard_regen": "spring", "meteor_dmg": "meteor",
	"gem_magnet": "gem", "sturdy": "hill",
	"land_veins": "site:mine", "land_springs": "site:well", "land_axes": "tree", "land_heights": "hill", "land_spoils": "site:camp", "land_timber": "tree", "den_dmg": "orb", "den_haste": "orb",
	"land_lantern": "spark", "land_flood": "site:sluice", "land_rites": "site:altar",
	"den_fury": "orb", "dragon_patience": "potion", "hoard_tithe": "coins"}


static func make(k: String, px: float, on := true) -> GameIcon:
	var ic := GameIcon.new()
	ic.key = k
	ic.lit = on
	ic.custom_minimum_size = Vector2(px, px)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic


## The picture for an achievement.
static func for_achievement(id: String) -> String:
	if ACH.has(id):
		return ACH[id]
	for p: Array in ACH_PREFIX:
		var pre: String = p[0]
		if not id.begins_with(pre):
			continue
		if p[1] != "":
			return p[1]
		var rest := id.trim_prefix(pre).rstrip("0123456789")
		match pre:
			"slain_":
				return "hero:" + rest
			"branch_":
				return "orb" if rest == "den" else "tower:" + rest
			_:
				return "tower:" + rest
	return "medal"


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	if framed:
		draw_circle(c, s * 0.48, Color("2a2016") if lit else Color("1d1712"))
		draw_circle(c, s * 0.42, Color("3a2c1e") if lit else Color("241c15"))
		draw_arc(c, s * 0.47, 0, TAU, 40, GOLD if lit else Color("4a3c2c"), maxf(2.0, s * 0.045), true)
		draw_arc(c, s * 0.40, 0, TAU, 40, Color(0, 0, 0, 0.4), maxf(1.0, s * 0.02), true)
	var k := s / 100.0 * (0.82 if framed else 1.0)
	var xf := Transform2D(0.0, Vector2(k, k), 0.0, c)
	draw_set_transform_matrix(xf)
	paint(self, key, xf)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if not lit:   # unearned: a dark veil over the picture
		draw_circle(c, s * (0.42 if framed else 0.5), Color(0.08, 0.06, 0.04, 0.55))


## Draws a key in a 100×100 box centred on the origin of xf, which ci's draw transform must
## already be set to (badges nest their own transform inside it).
static func paint(ci: CanvasItem, k: String, xf := Transform2D.IDENTITY) -> void:
	var tm := 0.6   # icons are still: a fixed moment for anything that sways
	if k.begins_with("ach:"):
		k = for_achievement(k.trim_prefix("ach:"))
	if k.begins_with("hero:"):
		var code := k.trim_prefix("hero:")
		var u: float = {"x": 28.0, "u": 22.0, "I": 14.0, "S": 24.0, "y": 26.0}.get(code, 33.0)
		Paint.ellipse(ci, Vector2(0, 14 + u * 0.95), u * 0.8, u * 0.24, Color(0, 0, 0, 0.35))
		Art.hero(ci, code, 0.0, 14.0, 14.0, u, 1.0, 0.35, tm)
	elif k.begins_with("tower:"):
		_tower(ci, k.trim_prefix("tower:"), Vector2.ZERO, 1.0)
	elif k.begins_with("site:"):
		var kind := k.trim_prefix("site:")
		ci.draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(1.4, 1.4), 0.0, Vector2.ZERO))
		Paint.ellipse(ci, Vector2(2, 20), 30, 9, Color(0, 0, 0, 0.35))
		Art.site(ci, kind, Vector2(0, 2), not Defs.HERO_SITES.has(kind), tm, Vector2i.ZERO)
		ci.draw_set_transform_matrix(xf)
	elif k.begins_with("skill:"):
		_skill(ci, k.trim_prefix("skill:"), xf)
	elif k.begins_with("spell:"):
		_glyph(ci, {"meteor": "meteor"}.get(k.trim_prefix("spell:"), "spark"))
	else:
		_glyph(ci, k)


static func _tower(ci: CanvasItem, type: String, at: Vector2, sc: float) -> void:
	var s := 70.0 * sc
	var x := at.x
	var y := at.y + 8.0 * sc
	Paint.ellipse(ci, Vector2(x, y + s * 0.3), s * 0.4, s * 0.13, Color("6a6258"))
	Paint.ellipse(ci, Vector2(x, y + s * 0.27), s * 0.36, s * 0.1, Color("a69c8e"))
	match type:
		"moss":
			Art.hut(ci, x, y, s, 3, false, 0.6, 0.0)
		"frost":
			Art.crypt(ci, x, y, s, 3, false, 0.6)
		_:
			Art.shrine(ci, x, y, s, 3, false, 0.6, Vector2.ZERO)


## A skill: its tower (or a Hoard picture) with a badge saying what the skill improves.
static func _skill(ci: CanvasItem, id: String, xf: Transform2D) -> void:
	var line := id.trim_suffix("2").trim_suffix("3")   # tier II and III skills share their line's picture
	if HOARD.has(line):
		paint(ci, HOARD[line], xf)
		return
	var type := id.get_slice("_", 0)
	var what := id.get_slice("_", 1)
	if type == "mastery":   # a level IV mastery: its tower with the IV chevrons
		for t: String in Defs.MASTERIES:
			if Defs.MASTERIES[t].any(func(m: Dictionary) -> bool: return m["id"] == what):
				type = t
		what = "vet"
	_tower(ci, type, Vector2(-8, -6), 0.85)
	var badge: String = ABILITY_BADGE.get(type, "spark") if what == "ability" else SKILL_BADGE.get(what, "spark")
	var b := Vector2(24, 24)
	ci.draw_circle(b, 19.0, INK)
	ci.draw_arc(b, 19.0, 0, TAU, 28, GOLD, 2.5, true)
	ci.draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(0.34, 0.34), 0.0, b))
	_glyph(ci, badge)
	ci.draw_set_transform_matrix(xf)


static func _star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	ci.draw_colored_polygon(pts, col)


## The plain pictures, each in a 100-unit box.
static func _glyph(ci: CanvasItem, g: String) -> void:
	match g:
		"skull":
			ci.draw_circle(Vector2(0, -8), 30, BONE)
			ci.draw_rect(Rect2(-17, 14, 34, 18), BONE)
			ci.draw_circle(Vector2(-12, -6), 9, INK)
			ci.draw_circle(Vector2(12, -6), 9, INK)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(0, 4), Vector2(-5, 13), Vector2(5, 13)]), INK)
			for i in 3:
				ci.draw_line(Vector2(-10 + i * 10, 18), Vector2(-10 + i * 10, 32), INK, 2.5)
		"swords":
			for d in [-1.0, 1.0]:
				ci.draw_line(Vector2(-30 * d, 30), Vector2(30 * d, -30), Color("dfe6ec"), 7.0)
				ci.draw_line(Vector2(-30 * d, 30), Vector2(-18 * d, 18), Color("6a4422"), 9.0)
				ci.draw_line(Vector2(-26 * d, 12), Vector2(-12 * d, 26), GOLD, 6.0)
		"banner":
			ci.draw_line(Vector2(-22, 40), Vector2(-22, -40), Color("6a4422"), 6.0)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-19, -38), Vector2(32, -30), Vector2(20, -10), Vector2(32, 10), Vector2(-19, 4)]), Color("a8343e"))
			_star(ci, Vector2(4, -16), 10, GOLD)
		"moon":
			ci.draw_circle(Vector2(0, 0), 32, Color("dfe6ff"))
			ci.draw_circle(Vector2(14, -10), 28, Color("2a2016"))
			_star(ci, Vector2(22, 20), 6, Color("bcc9ff"))
		"gem":
			Paint.glow(ci, Vector2.ZERO, 40, Color(1, 0.38, 0.5, 0.5))
			Paint.gem(ci, Vector2(0, 4), 30)
		"gem_broken":
			Paint.gem(ci, Vector2(0, 4), 30)
			ci.draw_polyline(PackedVector2Array([Vector2(-6, -26), Vector2(4, -6), Vector2(-4, 8), Vector2(6, 30)]), INK, 4.0)
		"hand":
			Paint.gem(ci, Vector2(10, -6), 22)
			ci.draw_rect(Rect2(-34, 4, 34, 26), Color("f0c9a0"))
			for i in 4:
				ci.draw_rect(Rect2(-34 + i * 9, -14, 7, 20), Color("f0c9a0"))
		"star":
			_star(ci, Vector2(0, 2), 40, GOLD)
			_star(ci, Vector2(0, 2), 22, Color("ffe08a"))
		"trophy":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-26, -34), Vector2(26, -34), Vector2(18, 0), Vector2(0, 8), Vector2(-18, 0)]), GOLD)
			ci.draw_arc(Vector2(-26, -20), 12, PI / 2, PI * 1.5, 12, GOLD, 5.0)
			ci.draw_arc(Vector2(26, -20), 12, -PI / 2, PI / 2, 12, GOLD, 5.0)
			ci.draw_rect(Rect2(-5, 6, 10, 18), Color("c9952e"))
			ci.draw_rect(Rect2(-20, 24, 40, 10), Color("8a6420"))
		"book":
			ci.draw_rect(Rect2(-32, -28, 64, 56), Color("5a2a7a"))
			ci.draw_rect(Rect2(-26, -24, 52, 48), Color("efe4cc"))
			ci.draw_line(Vector2(0, -24), Vector2(0, 24), Color("8a7a66"), 2.0)
			_star(ci, Vector2(-13, -2), 9, Color("7e6cf0"))
			for i in 4:
				ci.draw_line(Vector2(6, -14 + i * 9), Vector2(20, -14 + i * 9), Color("8a7a66"), 2.0)
		"flag":
			ci.draw_line(Vector2(-24, 40), Vector2(-24, -40), Color("6a4422"), 5.0)
			for r in 3:
				for col in 3:
					ci.draw_rect(Rect2(-21 + col * 16, -38 + r * 14, 16, 14), INK if (r + col) % 2 == 0 else BONE)
		"meteor":
			for i in 4:
				ci.draw_line(Vector2(-6 - i * 9, -6 - i * 9) + Vector2(-8, 8), Vector2(-6 - i * 9, -6 - i * 9) + Vector2(8, -8), Color(1, 0.6, 0.2, 0.7 - i * 0.15), 10.0 - i * 2.0)
			Paint.glow(ci, Vector2(10, 10), 34, Color(1, 0.42, 0.13, 0.7))
			ci.draw_circle(Vector2(10, 10), 18, Color("ff6a20"))
			ci.draw_circle(Vector2(10, 10), 9, Color("ffe08a"))
		"orb", "volley_orb":
			Paint.glow(ci, Vector2.ZERO, 44, Color(0.35, 0.5, 1, 0.8))
			ci.draw_circle(Vector2.ZERO, 22, Color(0.45, 0.62, 1))
			ci.draw_circle(Vector2.ZERO, 12, Color(0.95, 0.97, 1))
			for a in [0.4, 2.5, 4.4]:
				ci.draw_polyline(PackedVector2Array([Vector2.ZERO, Vector2(cos(a), sin(a)) * 24, Vector2(cos(a + 0.5), sin(a + 0.5)) * 34]), Color(0.85, 0.9, 1), 3.0)
		"coin":
			ci.draw_circle(Vector2.ZERO, 30, GOLD)
			ci.draw_arc(Vector2.ZERO, 30, 0, TAU, 32, Color("8a6420"), 4.0, true)
			ci.draw_circle(Vector2.ZERO, 14, Color("c9952e"))
		"coins":
			for i in 4:
				Paint.ellipse(ci, Vector2(-8, 26 - i * 10), 26, 9, Color("c9952e") if i % 2 else GOLD)
			ci.draw_circle(Vector2(18, -6), 20, GOLD)
			ci.draw_arc(Vector2(18, -6), 20, 0, TAU, 24, Color("8a6420"), 3.0, true)
		"potion":
			Paint.glow(ci, Vector2(0, 10), 40, Color(0.5, 0.42, 0.95, 0.5))
			ci.draw_circle(Vector2(0, 12), 26, Color("7e6cf0"))
			ci.draw_rect(Rect2(-9, -30, 18, 22), Color("b8b0e8"))
			ci.draw_rect(Rect2(-12, -38, 24, 9), Color("6a4422"))
			ci.draw_circle(Vector2(-9, 4), 6, Color(1, 1, 1, 0.7))
		"spring":
			_glyph(ci, "potion")
			ci.draw_polyline(PackedVector2Array([Vector2(16, -10), Vector2(30, -26), Vector2(44, -10)]), Color("c9c0ff"), 7.0)
		"hourglass":
			ci.draw_rect(Rect2(-26, -38, 52, 7), Color("6a4422"))
			ci.draw_rect(Rect2(-26, 31, 52, 7), Color("6a4422"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-20, -31), Vector2(20, -31), Vector2(3, 0), Vector2(20, 31), Vector2(-20, 31), Vector2(-3, 0)]), Color(0.85, 0.9, 1, 0.5))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-14, -22), Vector2(14, -22), Vector2(0, -2)]), GOLD)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(0, 14), Vector2(16, 30), Vector2(-16, 30)]), GOLD)
		"up":
			for i in 3:
				ci.draw_polyline(PackedVector2Array([Vector2(-28, 22 - i * 22), Vector2(0, -2 - i * 22), Vector2(28, 22 - i * 22)]), GOLD, 9.0)
		"spark":
			Paint.glow(ci, Vector2.ZERO, 40, Color(0.79, 0.75, 1, 0.6))
			_star(ci, Vector2.ZERO, 34, Color("c9c0ff"))
		"flame":
			Paint.glow(ci, Vector2(0, 6), 40, Color(1, 0.48, 0.16, 0.55))
			var outer := PackedVector2Array([Vector2(-22, 30)])
			outer.append_array(Paint.quad(Vector2(-22, 30), Vector2(-26, -6), Vector2(2, -38), 8))
			outer.append_array(Paint.quad(Vector2(2, -38), Vector2(26, -4), Vector2(22, 30), 8))
			ci.draw_colored_polygon(outer, Color("ff5a1a"))
			ci.draw_circle(Vector2(0, 16), 13, Color("ffd25a"))
		"dread":
			var ghost := PackedVector2Array([Vector2(-24, 32), Vector2(-24, -8)])
			ghost.append_array(Paint.quad(Vector2(-24, -8), Vector2(0, -50), Vector2(24, -8), 10))
			ghost.append_array(PackedVector2Array([Vector2(24, 32), Vector2(12, 22), Vector2(0, 32), Vector2(-12, 22)]))
			ci.draw_colored_polygon(ghost, Color("c9c0ff"))
			ci.draw_circle(Vector2(-9, -8), 6, INK)
			ci.draw_circle(Vector2(9, -8), 6, INK)
			ci.draw_circle(Vector2(0, 10), 7, INK)
		"tree":
			ci.draw_rect(Rect2(-5, 14, 10, 24), Color("5a3a1e"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -40), Vector2(28, 0), Vector2(-28, 0)]), Color("3e6a2c"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -20), Vector2(32, 20), Vector2(-32, 20)]), Color("2f5a22"))
			ci.draw_line(Vector2(14, 30), Vector2(40, 4), Color("8a8a8a"), 5.0)   # an axe leaning on it
			ci.draw_colored_polygon(PackedVector2Array([Vector2(34, 0), Vector2(46, -4), Vector2(44, 14)]), Color("c9d2da"))
		"hill":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-38, 30), Vector2(-26, -6), Vector2(26, -6), Vector2(38, 30)]), Color("6a6258"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-26, -6), Vector2(-16, -20), Vector2(16, -20), Vector2(26, -6)]), Color("cfc6b0"))
			Paint.glow(ci, Vector2(0, -14), 30, Color(1, 0.85, 0.45, 0.45))
			_star(ci, Vector2(10, -30), 7, Color("fff2c0"))
		"towers":
			_tower(ci, "frost", Vector2(-20, 0), 0.62)
			_tower(ci, "ash", Vector2(20, 0), 0.62)
			_tower(ci, "moss", Vector2(0, 12), 0.62)
		"crown":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-34, 22), Vector2(-34, -20), Vector2(-17, 0), Vector2(0, -30), Vector2(17, 0), Vector2(34, -20), Vector2(34, 22)]), GOLD)
			Paint.gem(ci, Vector2(0, 8), 9)
		"blade":   # damage
			ci.draw_line(Vector2(-30, 30), Vector2(26, -26), Color("dfe6ec"), 12.0)
			ci.draw_line(Vector2(-34, 14), Vector2(-14, 34), GOLD, 9.0)
		"rate":   # attack speed
			for i in 2:
				ci.draw_polyline(PackedVector2Array([Vector2(-26 + i * 26, -28), Vector2(2 + i * 26, 0), Vector2(-26 + i * 26, 28)]), GOLD, 11.0)
		"range":
			for i in 3:
				ci.draw_arc(Vector2(-30, 30), 22 + i * 20, -PI / 2, 0, 12, GOLD, 8.0)
			ci.draw_circle(Vector2(-30, 30), 9, BONE)
		"vet":   # rank chevrons
			for i in 3:
				ci.draw_polyline(PackedVector2Array([Vector2(-30, -16 + i * 20), Vector2(0, -32 + i * 20), Vector2(30, -16 + i * 20)]), GOLD, 9.0)
		"volley":
			for d in [-14.0, 14.0]:
				ci.draw_line(Vector2(-30, 24 + d), Vector2(26, -20 + d), Color("dfe6ec"), 6.0)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(34, -26 + d), Vector2(18, -22 + d), Vector2(28, -10 + d)]), Color("dfe6ec"))
		_:   # a plain medal
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-16, -40), Vector2(-2, -40), Vector2(6, -14), Vector2(-8, -14)]), Color("a8343e"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(16, -40), Vector2(2, -40), Vector2(-6, -14), Vector2(8, -14)]), Color("2f4f8a"))
			ci.draw_circle(Vector2(0, 10), 26, GOLD)
			_star(ci, Vector2(0, 10), 16, Color("ffe08a"))
