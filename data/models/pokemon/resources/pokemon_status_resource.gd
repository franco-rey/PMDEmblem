class_name PokemonStatusResource
extends Resource
## Generated PMD status/in-battle modifier metadata.

@export var status_id: String = ""
@export var display_name: String = ""
@export var source_category: String = "battle"
@export var duration_policy: String = "battle"
@export var visual_key: String = ""
@export_file("*.png") var icon_path: String = ""
@export var source_event_tags: Array[String] = []
@export var supported_hook_families: Array[String] = []
@export var unsupported_hook_families: Array[String] = []


func label() -> String:
	if not display_name.is_empty():
		return display_name
	return status_id.capitalize()
