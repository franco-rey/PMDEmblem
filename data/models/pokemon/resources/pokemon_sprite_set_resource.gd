class_name PokemonSpriteSetResource
extends Resource

const ABSENT_FRAME: int = -1

@export_file("*.png") var idle_path: String = ""
@export_file("*.png") var walk_path: String = ""
@export_file("*.png") var hurt_path: String = ""
@export_file("*.png") var sleep_path: String = ""
@export_file("*.png") var hop_path: String = ""

@export_file("*.xml") var anim_data_path: String = ""
@export_file("*.json") var anchors_path: String = ""
@export var shadow_size: int = 0
@export var animation_schema_version: int = 1

@export var world_pixel_size: float = 0.04

@export var cell_size: Vector2i = Vector2i.ZERO
@export var frame_counts: Dictionary = {}
@export var grounding_offset: float = 0.0

@export var portrait_paths: Array[String] = []
@export var validation_warnings: Array[String] = []
@export var animation_states: Dictionary = {}
@export var move_animation_map: Dictionary = {}


func iter_animation_paths() -> Array:
	return [
		["idle", idle_path],
		["walk", walk_path],
		["hurt", hurt_path],
		["sleep", sleep_path],
		["hop", hop_path],
	]


func is_complete() -> bool:
	for pair in iter_animation_paths():
		if String(pair[1]).is_empty():
			return false
	return true


func has_animation_state(state_key: String) -> bool:
	if state_key.is_empty():
		return false
	if animation_states.has(state_key):
		var entry: Variant = animation_states[state_key]
		if entry is Dictionary:
			return not String((entry as Dictionary).get("path", "")).is_empty()
		return true
	match state_key:
		"idle": return not idle_path.is_empty()
		"walk": return not walk_path.is_empty()
		"hurt": return not hurt_path.is_empty()
		"sleep", "faint": return not sleep_path.is_empty()
		"hop", "attack", "physical_attack", "special_attack": return not hop_path.is_empty()
	return false


func state_entry(state_key: String) -> Dictionary:
	var entry: Variant = animation_states.get(state_key, null)
	return entry if entry is Dictionary else {}


func state_key_for_source_name(source_name: String) -> String:
	if source_name.is_empty():
		return ""
	var wanted: String = source_name.to_lower()
	var alias_match: String = ""
	for key in animation_states.keys():
		var entry: Variant = animation_states[key]
		if not (entry is Dictionary):
			continue
		var dict: Dictionary = entry
		if String(dict.get("source_name", "")).to_lower() != wanted:
			continue
		if dict.has("alias_of"):
			if alias_match.is_empty():
				alias_match = String(key)
			continue
		return String(key)
	return alias_match


func has_source_state(source_name: String) -> bool:
	return not state_key_for_source_name(source_name).is_empty()
