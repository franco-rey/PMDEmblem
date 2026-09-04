class_name PokemonFormResource
extends Resource

@export var species_id: String = ""
@export var form_index: int = 0
@export var generation: int = 0

@export var type1: String = "none"
@export var type2: String = "none"

@export var base_hp: int = 0
@export var base_atk: int = 0
@export var base_def: int = 0
@export var base_spa: int = 0
@export var base_spd: int = 0
@export var base_speed: int = 0

@export var height: float = 0.0
@export var weight: float = 0.0
@export var gender_weights: Vector3i = Vector3i.ZERO
@export var exp_table: String = ""
@export var exp_table_values: PackedInt32Array = PackedInt32Array()
@export var exp_yield: int = 0
@export var join_rate: int = 0
@export var temporary: bool = false

@export var sprite_set: PokemonSpriteSetResource

@export var intrinsic1: String = ""
@export var intrinsic2: String = ""
@export var intrinsic3: String = ""


func types() -> Array[String]:
	var out: Array[String] = []
	if not type1.is_empty() and type1 != "none":
		out.append(type1)
	if not type2.is_empty() and type2 != "none":
		out.append(type2)
	return out


func base_stat_total() -> int:
	return base_hp + base_atk + base_def + base_spa + base_spd + base_speed
