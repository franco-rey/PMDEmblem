class_name PokemonItemResource
extends Resource

enum UseKind {
	NONE = 0,
	CONSUMABLE = 1,
	HELD = 2,
	BAG_PASSIVE = 3,
	TM = 4,
	EVOLUTION = 5,
	MATERIAL = 6,
}

@export var item_id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
@export var released: bool = true
@export var category: String = "unknown"
@export var use_kind: int = UseKind.NONE

@export var price: int = 0
@export var rarity: int = 0
@export var max_stack: int = 0
@export var cannot_drop: bool = false
@export var bag_effect: bool = false
@export var usage_type: int = 0
@export var sort_category: int = 0
@export var sprite_key: String = ""
@export_file("*.png") var icon_path: String = ""
@export var icon_index: int = 0

@export var item_states: Array[String] = []
@export var source_effect_tags: Array[String] = []
@export var unsupported_effect_tags: Array[String] = []
@export var effect_records: Array[Dictionary] = []
@export var passive_effect_records: Array[Dictionary] = []
@export var source_json_path: String = ""


func display_name() -> String:
	return name if not name.is_empty() else item_id


func is_consumable() -> bool:
	return use_kind == UseKind.CONSUMABLE or use_kind == UseKind.TM


func is_holdable() -> bool:
	return use_kind == UseKind.HELD
