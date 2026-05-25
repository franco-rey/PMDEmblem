class_name PokemonFormResource
extends Resource
## A single form (base, mega, alolan, etc.) of a Pokemon species.
##
## All combat-meaningful per-form data lives here: types, six base stats,
## sprite set. The species resource owns an array of these and points at one
## as the default.

@export var species_id: String = ""
@export var form_index: int = 0
@export var generation: int = 0

## Lowercase PMD type slug ("fighting", "ghost"). Mono-typed Pokemon use
## `type2 = "none"` to match PMDODump's convention.
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
## (genderless, male, female) raw weights from PMD.
@export var gender_weights: Vector3i = Vector3i.ZERO
@export var exp_table: String = ""
@export var exp_table_values: PackedInt32Array = PackedInt32Array()
@export var exp_yield: int = 0
@export var join_rate: int = 0
@export var temporary: bool = false

@export var sprite_set: PokemonSpriteSetResource

## PMD intrinsic slugs. M6/M7 resolve these to generated intrinsic resources
## where hooks are supported, otherwise readiness reports keep them explicit.
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


## Total of the six base stats. Useful for validation and balance reports.
func base_stat_total() -> int:
	return base_hp + base_atk + base_def + base_spa + base_spd + base_speed
