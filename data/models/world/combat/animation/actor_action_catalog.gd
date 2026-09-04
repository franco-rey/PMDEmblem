class_name ActorActionCatalog
extends RefCounted

const DEFAULT_PATH: String = "res://data/models/visuals/generated/gfx_actions.json"
const FALLBACK_ACTIONS: Array = [
	{"id": 0, "name": "None", "dash": false, "fallbacks": []},
	{"id": 1, "name": "Idle", "dash": false, "fallbacks": []},
	{"id": 2, "name": "Walk", "dash": false, "fallbacks": []},
	{"id": 3, "name": "Sleep", "dash": false, "fallbacks": []},
	{"id": 4, "name": "Hurt", "dash": false, "fallbacks": []},
	{"id": 5, "name": "Attack", "dash": true, "fallbacks": []},
	{"id": 6, "name": "Charge", "dash": false, "fallbacks": []},
	{"id": 7, "name": "Shoot", "dash": false, "fallbacks": ["Charge"]},
	{"id": 8, "name": "Strike", "dash": true, "fallbacks": ["Attack"]},
]

static var _shared: ActorActionCatalog = null

var actions_by_id: Dictionary = {}
var actions_by_name: Dictionary = {}
var source_path: String = ""
var hurt_action: int = 4
var walk_action: int = 2
var idle_action: int = 1
var sleep_action: int = 3
var charge_action: int = 6


static func shared() -> ActorActionCatalog:
	if _shared == null:
		_shared = ActorActionCatalog.new()
		_shared.load_from(DEFAULT_PATH)
	return _shared


func load_from(path: String) -> bool:
	actions_by_id.clear()
	actions_by_name.clear()
	source_path = path
	var parsed: Variant = null
	if FileAccess.file_exists(path):
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file != null:
			parsed = JSON.parse_string(file.get_as_text())
			file.close()
	var actions: Array = FALLBACK_ACTIONS
	if parsed is Dictionary:
		var dict: Dictionary = parsed
		if dict.get("actions", null) is Array:
			actions = dict["actions"]
		hurt_action = int(dict.get("hurt_action", hurt_action))
		walk_action = int(dict.get("walk_action", walk_action))
		idle_action = int(dict.get("idle_action", idle_action))
		sleep_action = int(dict.get("sleep_action", sleep_action))
		charge_action = int(dict.get("charge_action", charge_action))
	for raw in actions:
		if not (raw is Dictionary):
			continue
		var action: Dictionary = raw
		var id: int = int(action.get("id", -1))
		var name: String = String(action.get("name", ""))
		if id < 0 or name.is_empty():
			continue
		var fallbacks: Array[String] = []
		for fallback in action.get("fallbacks", []):
			fallbacks.append(String(fallback))
		var record: Dictionary = {"id": id, "name": name, "dash": bool(action.get("dash", false)), "fallbacks": fallbacks}
		actions_by_id[id] = record
		actions_by_name[name] = record
	return parsed is Dictionary


func name_for(action_id: int) -> String:
	var record: Variant = actions_by_id.get(action_id, null)
	return String((record as Dictionary).get("name", "")) if record is Dictionary else ""


func id_for(action_name: String) -> int:
	var record: Variant = actions_by_name.get(action_name, null)
	return int((record as Dictionary).get("id", -1)) if record is Dictionary else -1


func is_dash(action_name: String) -> bool:
	var record: Variant = actions_by_name.get(action_name, null)
	return bool((record as Dictionary).get("dash", false)) if record is Dictionary else false


func fallback_chain(action_name: String) -> Array[String]:
	var out: Array[String] = []
	if action_name.is_empty():
		return out
	out.append(action_name)
	var record: Variant = actions_by_name.get(action_name, null)
	if record is Dictionary:
		for fallback in (record as Dictionary).get("fallbacks", []):
			var name: String = String(fallback)
			if not out.has(name):
				out.append(name)
	return out


func resolve_source_state(sprite_set: PokemonSpriteSetResource, action_name: String) -> Dictionary:
	if sprite_set == null or action_name.is_empty():
		return {}
	var chain: Array[String] = fallback_chain(action_name)
	for candidate in chain:
		var key: String = sprite_set.state_key_for_source_name(candidate)
		if not key.is_empty():
			return {
				"state_key": key,
				"source_name": candidate,
				"requested": action_name,
				"tier": "exact" if candidate == action_name else "source_fallback",
			}
	return {}
