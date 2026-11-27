extends SceneTree
## Writes each lair's "site_mana" (the factor on every building cut's mana, Defs.SITE_MANA) from its place
## in the campaign: rises by chapter and by lair within the chapter. Run after the campaign order changes:
##   godot --headless --path . -s res://tools/set_site_mana.gd


func _init() -> void:
	var order := _campaign_order()
	var f: Dictionary = Defs.SITE_MANA
	for pos in order.size():
		var chapter := pos / Defs.LAIRS_PER_CHAPTER + 1
		var k := pos % Defs.LAIRS_PER_CHAPTER
		var v := snappedf(float(f["base"]) + float(f["chapter"]) * (chapter - 1) + float(f["lair"]) * k, 0.01)
		_write(order[pos], v)
	quit()


## The campaign order, read from main.gd's LEVELS (loading main.gd itself needs the autoloads).
func _campaign_order() -> Array:
	var src := FileAccess.get_file_as_string("res://scripts/main.gd")
	var at := src.find("const LEVELS")
	var line := src.substr(at, src.find("]", at + 30) - at)
	var out := []
	for m in RegEx.create_from_string("res://levels/level_\\d+\\.json").search_all(line):
		out.append(m.get_string())
	return out


## Text edit, so the file keeps its layout: replace the line, or add it after "site_cuts" (else "wave_gap").
func _write(path: String, v: float) -> void:
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var text := " \"site_mana\": %s," % str(v)
	var at := -1
	for i in lines.size():
		if lines[i].strip_edges().begins_with("\"site_mana\""):
			lines[i] = text
			at = -2
			break
		if at == -1 and lines[i].strip_edges().begins_with("\"site_cuts\""):
			at = i
	if at == -1:
		for i in lines.size():
			if lines[i].strip_edges().begins_with("\"wave_gap\""):
				at = i
	if at >= 0:
		lines.insert(at + 1, text)
	var fa := FileAccess.open(path, FileAccess.WRITE)
	fa.store_string("\n".join(lines))
	fa.close()
	print("%s  site_mana %s" % [path.get_file(), str(v)])
