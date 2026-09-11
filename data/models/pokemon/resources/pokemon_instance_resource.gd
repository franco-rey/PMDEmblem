class_name PokemonInstanceResource
extends Resource

const MAX_MOVE_SLOTS: int = 4
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
@export var shiny: bool = false
@export var level: int = 1
@export var experience: int = 0
@export var current_hp: int = CURRENT_HP_AUTO

@export var move_slots: Array[PokemonMoveResource] = []
@export var pp_state: Array[int] = []
@export var known_move_ids: Array[String] = []

@export var team: int = Team.PLAYER
@export var control_type: int = ControlType.PLAYER
@export var nickname: String = ""

@export var movement_override: int = 0

@export var recruited: bool = false
@export var nature_id: String = ""
@export var permanent_modifiers: Dictionary = {}
@export var held_item: PokemonItemResource
@export var runtime_modifiers: Dictionary = {}
@export var temporary_statuses: Array[String] = []
@export var ability_override: String = ""
@export var gender: int = -1
@export var loadout_locked: bool = false


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
