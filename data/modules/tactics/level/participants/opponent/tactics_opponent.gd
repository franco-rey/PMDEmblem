class_name TacticsOpponent
extends TacticsParticipant

var opponent_serv: TacticsOpponentService


func _ready() -> void:
	super._ready()
	opponent_serv = TacticsOpponentService.new(res, camera, controls, arena)


func is_pawn_configured() -> bool:
	return opponent_serv.is_pawn_configured(self)


func choose_pawn() -> void:
	print("choose_pawn() if forwarding.")
	opponent_serv.choose_pawn(self)


func chase_nearest_enemy() -> void:
	opponent_serv.chase_nearest_enemy(self, get_node("../TacticsPlayer"))


func is_pawn_done_moving() -> void:
	opponent_serv.is_pawn_done_moving()


func choose_pawn_to_attack() -> void:
	opponent_serv.choose_pawn_to_attack()
