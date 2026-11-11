extends SceneTree
## Makes new full-game codes for demo builds (Edition.try_code). The codes themselves go to a
## private text file outside the project, never into the public repository; the game only holds
## their hashes, in scripts/data/unlock_codes.gd, which this rewrites with the new ones added.
## Run from the project folder (count, then the private file to append the codes to):
##   godot --headless --path . -s res://tools/make_codes.gd -- 50 "C:/Users/me/Desktop/Gemhold codes/codes.txt"

const LETTERS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"   # no 0/O or 1/I, easy to read out
const HASH_FILE := "res://scripts/data/unlock_codes.gd"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: -- <count> <private codes file>")
		quit(1)
		return
	var count := int(args[0])
	var out_path := args[1]
	var hashes: Array[String] = []
	hashes.assign(UnlockCodes.HASHES)
	var crypto := Crypto.new()
	var lines := PackedStringArray()
	for i in count:
		var bytes := crypto.generate_random_bytes(12)
		var code := ""
		for b in bytes:
			code += LETTERS[b % LETTERS.length()]
		lines.append("%s-%s-%s" % [code.substr(0, 4), code.substr(4, 4), code.substr(8, 4)])
		hashes.append(Edition.code_hash(code))
	var f := FileAccess.open(out_path, FileAccess.READ_WRITE if FileAccess.file_exists(out_path) else FileAccess.WRITE)
	if f == null:
		printerr("can't write " + out_path)
		quit(1)
		return
	f.seek_end()
	for l in lines:
		f.store_line(l)
	f.close()
	var g := FileAccess.open(HASH_FILE, FileAccess.WRITE)
	g.store_string("class_name UnlockCodes\nextends RefCounted\n## SHA-256 hashes of the full-game codes (Edition.code_hash). Made by tools/make_codes.gd;\n## the codes themselves are kept privately, outside this repository.\n\nconst HASHES: Array[String] = [\n")
	for h in hashes:
		g.store_string("\t\"%s\",\n" % h)
	g.store_string("]\n")
	g.close()
	print("%d codes added to %s (%d in the game)" % [count, out_path, hashes.size()])
	quit(0)
