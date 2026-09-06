class_name SoundCues
extends RefCounted

const TABLE_PATH: String = "res://data/models/audio/sound_cues.json"

static var _table: Dictionary = {}
static var _loaded: bool = false


static func table() -> Dictionary:
	if _loaded:
		return _table
	_loaded = true
	if FileAccess.file_exists(TABLE_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
		if parsed is Dictionary:
			_table = parsed
	return _table


static func resolve(cue_id: String) -> String:
	var parts: PackedStringArray = cue_id.split(".", false, 1)
	if parts.size() != 2:
		return ""
	var group: Dictionary = table().get(parts[0], {})
	return String(group.get(parts[1], ""))


static func all_ids() -> Array[String]:
	var out: Array[String] = []
	for group_name in table():
		var group: Variant = table()[group_name]
		if group is Dictionary:
			for cue_name in group:
				out.append("%s.%s" % [group_name, cue_name])
	return out
