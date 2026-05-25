class_name PokemonIntrinsicResource
extends Resource

@export var intrinsic_id: String = ""
@export var display_name: String = ""
@export var source_event_tags: Array[String] = []
@export var supported_hook_families: Array[String] = []
@export var unsupported_hook_families: Array[String] = []
@export_multiline var report_summary: String = ""


func label() -> String:
	if not display_name.is_empty():
		return display_name
	return intrinsic_id.capitalize()
