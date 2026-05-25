class_name StatsResource
extends Resource

@export var override_name: String = ""
@export var expertise: String = ""

@export_category("Init")
@export_enum("Tank", "Flank", "Physical", "Distance", "Support") var strategy: int
@export var level: int = 1
@export_file("*.png") var sprite: String = "res://assets/textures/actor/"

@export_category("Base")
@export var movement: int = 3
@export var jump: float = movement / 2.0
@export var max_health: int = 5

@export_category("Offensive")
@export var attack_range: int = 1
@export var attack_power: int = 1


func set_jump() -> void:
	jump = floor(movement / 2.0)
