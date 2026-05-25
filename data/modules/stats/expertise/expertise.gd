@tool
class_name Expertise
extends Node

@export var pokemon_instance: PokemonInstanceResource
@export var starting_stats: StatsResource
@export var starting_skills: Array[String]

@onready var stats: Stats = $Stats


func _ready() -> void:
	if pokemon_instance != null:
		stats.init_from_pokemon(pokemon_instance)
		return
	if starting_stats != null:
		stats.init(starting_stats)
		return
	push_error("Expertise needs either a PokemonInstanceResource (Pokemon Instance) or a StatsResource (Starting Stats).")
