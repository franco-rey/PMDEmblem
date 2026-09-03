class_name PokemonMoveResource
extends Resource

const CATEGORY_PHYSICAL: int = 1
const CATEGORY_SPECIAL: int = 2
const CATEGORY_STATUS: int = 3

enum TacticalRangeKind {
	UNSUPPORTED = 0,
	MELEE = 1,
	LINE = 2,
	PROJECTILE = 3,
	CONE = 4,
	AREA = 5,
	SELF = 6,
	ALLY = 7,
	ROOM = 8,
	MAP = 9,
}

const TARGET_SELF: int = 1
const TARGET_FRIEND: int = 2
const TARGET_FOE: int = 4

const ACCURACY_NEVER_MISS: int = -1

@export var move_id: String = ""
@export var index_number: int = 0
@export var name: String = ""
@export_multiline var description: String = ""

@export var type: String = "none"
@export var category: int = CATEGORY_STATUS
@export var base_power: int = 0
@export var accuracy: int = ACCURACY_NEVER_MISS
@export var pp: int = 0

@export var tactical_range_kind: int = TacticalRangeKind.UNSUPPORTED
@export var tactical_range_value: int = 1
@export var target_alignment: int = TARGET_FOE

@export var effect_tags: Array[String] = []
@export var unsupported_effect_tags: Array[String] = []
@export var effect_records: Array[Dictionary] = []
@export var strike_count: int = 1
@export var flags: Array[String] = []
@export var animation_key: String = ""


func is_damaging() -> bool:
	return category == CATEGORY_PHYSICAL or category == CATEGORY_SPECIAL


func is_sure_hit() -> bool:
	return accuracy == ACCURACY_NEVER_MISS


func can_target_foes() -> bool:
	return (target_alignment & TARGET_FOE) != 0


func can_target_allies() -> bool:
	return (target_alignment & TARGET_FRIEND) != 0


func can_target_self() -> bool:
	return (target_alignment & TARGET_SELF) != 0


func display_name() -> String:
	if not name.is_empty():
		return name
	return move_id


func has_flag(flag: String) -> bool:
	return flags.has(flag)
