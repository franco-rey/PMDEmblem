class_name SkirmishDefinitionResource
extends Resource

const OBJECTIVE_DEFEAT_ALL_ENEMIES: int = 0
const OBJECTIVE_DEFEND_TILE: int = 1
const OBJECTIVE_SURVIVE_N_TURNS: int = 2
const CONTROL_MODE_PLAYER_VS_CPU: String = "pvc"
const CONTROL_MODE_PLAYER_VS_PLAYER: String = "pvp"
const CONTROL_MODE_CPU_VS_CPU: String = "bots"

@export var skirmish_id: String = ""
@export var display_name: String = ""
@export var map: MapDefinitionResource
@export var seed: int = 0
@export var player_team: Array[PokemonInstanceResource] = []
@export var enemy_team: Array[PokemonInstanceResource] = []
@export var control_mode: String = CONTROL_MODE_PLAYER_VS_CPU
@export var objective: int = OBJECTIVE_DEFEAT_ALL_ENEMIES
@export var objective_payload: Dictionary = {}
@export var reward_profile: String = ""
@export var generation_metadata: Dictionary = {}
