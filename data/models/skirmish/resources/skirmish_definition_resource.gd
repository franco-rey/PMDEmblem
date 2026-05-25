class_name SkirmishDefinitionResource
extends Resource

const OBJECTIVE_DEFEAT_ALL_ENEMIES: int = 0
const OBJECTIVE_DEFEND_TILE: int = 1
const OBJECTIVE_SURVIVE_N_TURNS: int = 2

@export var skirmish_id: String = ""
@export var display_name: String = ""
@export var map: MapDefinitionResource
@export var seed: int = 0
@export var player_team: Array[PokemonInstanceResource] = []
@export var enemy_team: Array[PokemonInstanceResource] = []
@export var objective: int = OBJECTIVE_DEFEAT_ALL_ENEMIES
@export var objective_payload: Dictionary = {}
@export var reward_profile: String = ""
@export var generation_metadata: Dictionary = {}
