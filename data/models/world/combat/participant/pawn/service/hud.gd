class_name TacticsPawnHudService
extends RefCounted


func update_character_health(pawn: TacticsPawn) -> void:
	var _health_label: Label3D = pawn.get_node("Character/CharacterUI/HealthLabel")
	_health_label.text = str(pawn.stats.curr_health) + "/" + str(pawn.stats.max_health)


func tint_when_unable_to_act(pawn: TacticsPawn) -> void:
	var _char_node: TacticsPawnSprite = pawn.get_node("Character")
	var spent: bool = not pawn.is_alive() or pawn.res.has_acted_this_round
	_char_node.modulate = Color(0.5, 0.5, 0.5) if spent else Color(1, 1, 1)
