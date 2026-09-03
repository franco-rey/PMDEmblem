class_name TacticsPlayer
extends TacticsParticipant

var player_serv: TacticsPlayerService


func _ready() -> void:
	super._ready()
	player_serv = TacticsPlayerService.new(res, camera, controls, arena)


func _physics_process(_delta: float) -> void:
	var opposing: Node = res.targets if res.targets != null and is_instance_valid(res.targets) else get_node("../TacticsOpponent")
	var other: Node = get_node("../TacticsOpponent") if opposing == self else self
	player_serv.toggle_enemy_stats(opposing, other)


func is_pawn_configured() -> bool:
	return player_serv.is_pawn_configured(self)


func show_available_pawn_actions() -> void:
	player_serv.show_available_pawn_actions()


func show_available_movements() -> void:
	player_serv.show_available_movements()


func display_attackable_targets() -> void:
	player_serv.display_attackable_targets()


func move_pawn() -> void:
	player_serv.move_pawn()
