class_name TacticsPawnService
extends RefCounted

var movement: TacticsPawnMovementService
var combat: TacticsPawnCombatService
var animation: TacticsPawnAnimationService
var ui: TacticsPawnHudService
var character: TacticsPawnSprite


func _init() -> void:
	movement = TacticsPawnMovementService.new()
	combat = TacticsPawnCombatService.new()
	animation = TacticsPawnAnimationService.new()
	ui = TacticsPawnHudService.new()


func setup(pawn: TacticsPawn) -> void:
	animation.setup(pawn)


func process(pawn: TacticsPawn, delta: float) -> void:
	movement.move_along_path(pawn, delta)
	animation.start_animator(pawn)
	_update_sprite_anim_state(pawn, delta)
	pawn.get_node("Character").rotate_sprite(pawn.global_basis)
	ui.tint_when_unable_to_act(pawn)
	ui.update_character_health(pawn)


func _update_sprite_anim_state(pawn: TacticsPawn, delta: float) -> void:
	if pawn.res.hurt_remaining > 0.0:
		pawn.res.hurt_remaining = max(0.0, pawn.res.hurt_remaining - delta)
	if pawn.res.forced_anim_remaining > 0.0:
		pawn.res.forced_anim_remaining = max(0.0, pawn.res.forced_anim_remaining - delta)
		if pawn.res.forced_anim_remaining <= 0.0:
			pawn.res.forced_anim_state = ""

	var state: String
	if pawn.res.forced_anim_remaining > 0.0 and not pawn.res.forced_anim_state.is_empty():
		state = pawn.res.forced_anim_state
	elif pawn.res.hurt_remaining > 0.0:
		state = TacticsPawnSprite.ANIM_HURT
	elif not pawn.is_alive():
		state = TacticsPawnSprite.ANIM_SLEEP
	elif pawn.res.is_jumping:
		state = TacticsPawnSprite.ANIM_HOP
	elif pawn.res.is_moving:
		state = TacticsPawnSprite.ANIM_WALK
	else:
		state = TacticsPawnSprite.ANIM_IDLE

	(pawn.get_node("Character") as TacticsPawnSprite).set_anim_state(state)


func attack_target_pawn(pawn: TacticsPawn, target_pawn: TacticsPawn, delta: float) -> bool:
	return combat.attack_target_pawn(pawn, target_pawn, delta)
