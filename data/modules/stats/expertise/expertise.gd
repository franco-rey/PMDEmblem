@tool
class_name Expertise
extends Node
## The expertise of a game actor.
##
## Provides the pawn's runtime `Stats` node with its initial values. Two paths
## are supported - the M1 Pokemon path takes precedence when both are set:
##
## - `pokemon_instance`: a `PokemonInstanceResource` from the M1 data slice.
##   Drives `Stats.init_from_pokemon()`, deriving legacy fields (`max_health`,
##   `attack_power`, `movement`, `sprite`, `expertise`) from the species/form
##   so existing pawn / combat / sprite code keeps working unchanged.
## - `starting_stats`: legacy `StatsResource` (the pre-Pokemon class/mob model).
##   Kept as a fallback so pawns that haven't been migrated continue to spawn.

## M1 Pokemon-driven instance. When set, it takes precedence over `starting_stats`.
@export var pokemon_instance: PokemonInstanceResource
## Legacy StatsResource fallback. Used only if `pokemon_instance` is null.
@export var starting_stats: StatsResource
## Array of initial skills for the actor (legacy field, unused by M1).
@export var starting_skills: Array[String]

## Node containing the actor's stats
@onready var stats: Stats = $Stats


func _ready() -> void:
	if pokemon_instance != null:
		stats.init_from_pokemon(pokemon_instance)
		return
	if starting_stats != null:
		stats.init(starting_stats)
		return
	push_error("Expertise needs either a PokemonInstanceResource (Pokemon Instance) or a StatsResource (Starting Stats).")
