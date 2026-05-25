class_name TacticsPawnAnimationService
extends RefCounted


func setup(pawn: TacticsPawn) -> void:
	pawn.get_node("Character").setup(pawn.stats, pawn.expertise)


func start_animator(pawn: TacticsPawn) -> void:
	pawn.get_node("Character").start_animator(pawn.res.move_direction, pawn.res.is_jumping)
