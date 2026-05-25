class_name PokemonMoveResource
extends Resource
## A single Pokemon move imported from PMDODump's `Skill/<slug>.json`.
##
## The resource carries PMD power, accuracy, PP, range, target alignment,
## effect breadcrumbs, structured runtime effect records, strike count, and
## requested animation key. Runtime handlers consume the structured records and
## keep unsupported source events visible for readiness reports.

## PMD damage categories. Numeric values match PMD's `Data.Category` so the
## importer can copy the field verbatim.
const CATEGORY_PHYSICAL: int = 1
const CATEGORY_SPECIAL: int = 2
const CATEGORY_STATUS: int = 3

## How a move projects onto the tactical grid.
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

## PMD `TargetAlignments` bitmask values. A move may combine these.
const TARGET_SELF: int = 1
const TARGET_FRIEND: int = 2
const TARGET_FOE: int = 4

## Sentinel for "never miss" - PMD stores -1 in `Data.HitRate` for sure-hit moves.
const ACCURACY_NEVER_MISS: int = -1

@export var move_id: String = ""
@export var index_number: int = 0
@export var name: String = ""
@export_multiline var description: String = ""

@export var type: String = "none"
@export var category: int = CATEGORY_STATUS
@export var base_power: int = 0
## -1 = never miss; otherwise percentage in [0, 100].
@export var accuracy: int = ACCURACY_NEVER_MISS
@export var pp: int = 0

@export var tactical_range_kind: int = TacticalRangeKind.UNSUPPORTED
@export var tactical_range_value: int = 1
@export var target_alignment: int = TARGET_FOE

## Every PMD `$type` event seen on this move (BeforeActions / OnHits / AfterActions).
## Useful as a debugging breadcrumb.
@export var effect_tags: Array[String] = []
## Subset of `effect_tags` that the engine doesn't understand yet. These stay
## visible in readiness/import reports until a real handler is added.
@export var unsupported_effect_tags: Array[String] = []
## Structured M6 effect records derived from PMDODump events. Raw tags remain
## as source breadcrumbs; these dictionaries drive supported runtime handlers.
@export var effect_records: Array[Dictionary] = []
## PMD `Object.Strikes`. Values greater than 1 repeat hit/effect resolution.
@export var strike_count: int = 1
## Normalized move-use animation key requested by combat. Runtime falls back
## through `PokemonSpriteSetResource` when the exact key is unavailable.
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


## Utility for the M2 combat slice and for validation reports. Returns "Aura
## Sphere" rather than the raw slug "aura_sphere" when a display name exists.
func display_name() -> String:
	if not name.is_empty():
		return name
	return move_id
