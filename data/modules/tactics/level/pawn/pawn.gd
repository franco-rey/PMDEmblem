class_name TacticsPawn
extends CharacterBody3D

@export var controls: TacticsControlsResource = load("res://data/models/view/control/tactics/control.tres")

var res: TacticsPawnResource
var serv: TacticsPawnService

@onready var stats: Stats = $Expertise/Stats
@onready var expertise: String = $Expertise/Stats.expertise
@onready var character: TacticsPawnSprite = $Character


func _ready() -> void:
	res = TacticsPawnResource.new()
	serv = TacticsPawnService.new()
	serv.setup(self)
	controls.set_actions_menu_visibility(false, self)
	show_pawn_stats(false)


func _physics_process(delta: float) -> void:
	serv.process(self, delta)


func center() -> bool:
	return character.adjust_to_center(self)


func show_pawn_stats(v: bool) -> void:
	$Character/CharacterUI.visible = v


func get_tile() -> TacticsTile:
	return $Tile.get_collider()


func is_alive() -> bool:
	return stats != null and stats.is_active()


func can_pawn_move() -> bool:
	return res.can_move and is_alive()


func can_pawn_attack() -> bool:
	return res.can_attack and is_alive()


func can_act() -> bool:
	return (res.can_move or res.can_attack) and is_alive()


func reset_turn() -> void:
	if not is_alive():
		res.can_move = false
		res.can_attack = false
		return
	res.reset_turn()


func end_pawn_turn() -> void:
	res.end_pawn_turn()


func attack_target_pawn(target_pawn: TacticsPawn, delta: float) -> bool:
	return serv.attack_target_pawn(self, target_pawn, delta)


func move_along_path(delta: float) -> void:
	serv.movement.move_along_path(self, delta)
