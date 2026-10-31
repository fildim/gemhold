class_name Prefs
extends RefCounted
## Player settings that are not campaign progress (sound, music, whether the first-lair tips
## are done), kept in user://settings.cfg so resetting progress leaves them alone.

const PATH := "user://settings.cfg"

static var _cfg: ConfigFile
static var path := PATH:   # tests point this elsewhere
	set(v):
		path = v
		_cfg = null


static func _file() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(path)   # a missing file just means defaults
	return _cfg


static func get_value(key: String, default: Variant) -> Variant:
	return _file().get_value("prefs", key, default)


static func set_value(key: String, value: Variant) -> void:
	_file().set_value("prefs", key, value)
	_file().save(path)
