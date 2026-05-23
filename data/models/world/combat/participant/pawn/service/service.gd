class_name TacticsPawnService
extends RefCounted
## Service class for managing pawn operations in the tactics game

## Service for handling pawn movement
var movement: TacticsPawnMovementService
## Service for handling pawn combat
var combat: TacticsPawnCombatService
## Service for handling pawn animations
var animation: TacticsPawnAnimationService
## Service for handling pawn HUD operations
var ui: TacticsPawnHudService
## Reference to the pawn's sprite
var character: TacticsPawnSprite


## Initializes the TacticsPawnService and its sub-services
func _init() -> void:
	movement = TacticsPawnMovementService.new()
	combat = TacticsPawnCombatService.new()
	animation = TacticsPawnAnimationService.new()
	ui = TacticsPawnHudService.new()


## Sets up the pawn service, particularly the animation service
##
## @param pawn: The TacticsPawn to set up
func setup(pawn: TacticsPawn) -> void:
	animation.setup(pawn)


## Processes pawn-related operations every frame
##
## @param pawn: The TacticsPawn to process
## @param delta: Time elapsed since the last frame
func process(pawn: TacticsPawn, delta: float) -> void:
	pawn.get_node("Character").rotate_sprite(pawn.global_basis)
	movement.move_along_path(pawn, delta)
	animation.start_animator(pawn)
	_update_sprite_anim_state(pawn, delta)
	ui.tint_when_unable_to_act(pawn)
	ui.update_character_health(pawn)


## Computes the pawn's current sprite animation state and hands it to the
## sprite node, which swaps textures only when the state actually changes.
##
## Priority (highest first):
##   HURT  — active for HURT_DURATION seconds after taking damage
##   SLEEP — when the pawn has fainted
##   HOP   — while is_jumping
##   WALK  — while is_moving (and not jumping)
##   IDLE  — default, including alive pawns whose turn is spent
##
## @param pawn: The TacticsPawn whose sprite state to update
## @param delta: Time elapsed since the last frame
func _update_sprite_anim_state(pawn: TacticsPawn, delta: float) -> void:
	if pawn.res.hurt_remaining > 0.0:
		pawn.res.hurt_remaining = max(0.0, pawn.res.hurt_remaining - delta)

	var state: String
	if pawn.res.hurt_remaining > 0.0:
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


## Initiates an attack on a target pawn
##
## @param pawn: The attacking TacticsPawn
## @param target_pawn: The TacticsPawn being attacked
## @param delta: Time elapsed since the last frame
## @return: Whether the attack was successful
func attack_target_pawn(pawn: TacticsPawn, target_pawn: TacticsPawn, delta: float) -> bool:
	return combat.attack_target_pawn(pawn, target_pawn, delta)
