class_name ActionPresentationCatalog
extends RefCounted

const DEFAULT_PATH: String = "res://data/models/visuals/generated/action_presentation_manifest.json"

static var _shared: ActionPresentationCatalog = null

var entries: Dictionary = {}
var throw_defaults: Dictionary = {}
var source_path: String = ""
var loaded: bool = false


static func shared() -> ActionPresentationCatalog:
	if _shared == null:
		_shared = ActionPresentationCatalog.new()
		_shared.load_from(DEFAULT_PATH)
	return _shared


func load_from(path: String) -> bool:
	entries.clear()
	throw_defaults = {}
	source_path = path
	loaded = false
	if not FileAccess.file_exists(path):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return false
	var dict: Dictionary = parsed
	if dict.get("entries", null) is Dictionary:
		entries = dict["entries"]
	if dict.get("throw_defaults", null) is Dictionary:
		throw_defaults = dict["throw_defaults"]
	loaded = true
	return true


func skill(move_id: String) -> Dictionary:
	var entry: Variant = entries.get("skill:%s" % move_id, null)
	return entry if entry is Dictionary else {}


func item(item_id: String) -> Dictionary:
	var entry: Variant = entries.get("item:%s" % item_id, null)
	return entry if entry is Dictionary else {}


func has_skill(move_id: String) -> bool:
	return entries.has("skill:%s" % move_id)


func has_item(item_id: String) -> bool:
	return entries.has("item:%s" % item_id)


func asset(entry: Dictionary, category: String, key: String) -> Dictionary:
	var assets: Variant = entry.get("assets", {})
	if not (assets is Dictionary):
		return {}
	var record: Variant = (assets as Dictionary).get("%s:%s" % [category, key], null)
	return record if record is Dictionary else {}


func skill_ids() -> Array[String]:
	var out: Array[String] = []
	for key in entries.keys():
		var text: String = String(key)
		if text.begins_with("skill:"):
			out.append(text.substr(6))
	out.sort()
	return out


func item_ids() -> Array[String]:
	var out: Array[String] = []
	for key in entries.keys():
		var text: String = String(key)
		if text.begins_with("item:"):
			out.append(text.substr(5))
	out.sort()
	return out
