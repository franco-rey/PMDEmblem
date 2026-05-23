class_name PokemonInstanceResource
extends Resource
## A single battle-ready Pokemon. References a species + form, plus per-unit
## state (level, current HP, move slots with PP, team / control affiliation,
## tactical movement override).
##
## This is the resource pawn `Expertise` nodes will reference once the M1
## compatibility layer is in place. Generated species/form/move resources are
## kept under `data/models/pokemon/generated/`; instance overrides live under
## `data/models/pokemon/overrides/instances/` so hand-tuned battle units can be
## edited without touching the importer's output.

const MAX_MOVE_SLOTS: int = 4
## Sentinel for `current_hp` meaning "fill from form base HP at spawn time".
const CURRENT_HP_AUTO: int = 0

enum Team {
	PLAYER = 0,
	ENEMY = 1,
	NEUTRAL = 2,
	ALLY = 3,
}

enum ControlType {
	PLAYER = 0,
	AI = 1,
	AUTO = 2,
}

@export var species: PokemonSpeciesResource
@export var form_index: int = 0
@export var level: int = 1
## 0 = auto-fill to max HP at spawn. Otherwise treated as the unit's current HP.
@export var current_hp: int = CURRENT_HP_AUTO

@export var move_slots: Array[PokemonMoveResource] = []
@export var pp_state: Array[int] = []

@export var team: int = Team.PLAYER
@export var control_type: int = ControlType.PLAYER
@export var nickname: String = ""

## Tactical-movement-tile override. 0 means "derive from species/form" (M1
## leaves the legacy placeholder values in place via this override; M2+ may
## introduce a real Speed-to-tile mapping).
@export var movement_override: int = 0

@export var recruited: bool = false
## Free-form runtime modifiers reserved for later milestones (status, item
## effects, buffs). M1 just exposes the slot.
@export var runtime_modifiers: Dictionary = {}
@export var temporary_statuses: Array[String] = []


func display_name() -> String:
	if not nickname.is_empty():
		return nickname
	if species != null and not species.canonical_name.is_empty():
		return species.canonical_name
	if species != null:
		return species.species_id.capitalize()
	return ""


func resolved_form() -> PokemonFormResource:
	if species == null:
		return null
	if species.forms.is_empty():
		return null
	if form_index < 0 or form_index >= species.forms.size():
		return species.default_form()
	return species.forms[form_index]


func is_player_controlled() -> bool:
	return control_type == ControlType.PLAYER


func is_enemy_team() -> bool:
	return team == Team.ENEMY
