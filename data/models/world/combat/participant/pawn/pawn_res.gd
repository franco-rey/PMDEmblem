class_name TacticsPawnResource
extends Resource

signal pawn_moved
signal pawn_attacked
signal turn_ended

const MIN_HEIGHT_TO_JUMP: int = 1
const GRAVITY_STRENGTH: int = 7
const MIN_TIME_FOR_ATTACK: float = 1.0
const ANIMATION_FRAMES: int = 1
const HURT_DURATION: float = 0.5
const PRESENTATION_TIMEOUT: float = 8.0

var pawn_hud_enabled: bool = false
var can_move: bool = true
var can_attack: bool = true
var is_jumping: bool = false
var is_moving: bool = false

var move_direction: Vector3 = Vector3.ZERO
var pathfinding_tilestack: Array[Variant] = []
var gravity: Vector3 = Vector3.ZERO
var wait_delay: float = 0.0
var walk_speed: int = TacticsConfig.pawn.base_walk_speed
var hurt_remaining: float = 0.0
var forced_anim_state: String = ""
var forced_anim_remaining: float = 0.0
var forced_anim_one_shot: bool = true
var forced_anim_pending: bool = false
var selected_move_index: int = 0
var use_legacy_attack_fallback: bool = false
var has_acted_this_round: bool = false
var presentation_locked: bool = false
var presentation_wait: float = 0.0
var intent_executed: bool = false


func reset_turn() -> void:
	can_move = true
	can_attack = true


func end_pawn_turn() -> void:
	can_move = false
	can_attack = false
	turn_ended.emit()


func force_animation(state: String, duration: float = 0.35, one_shot: bool = true) -> void:
	if state.is_empty():
		return
	forced_anim_state = state
	forced_anim_remaining = maxf(duration, 0.05)
	forced_anim_one_shot = one_shot
	forced_anim_pending = true


func clear_forced_animation() -> void:
	forced_anim_state = ""
	forced_anim_remaining = 0.0
	forced_anim_pending = false


func set_moving(value: bool) -> void:
	is_moving = value
	if value:
		pawn_moved.emit()


func set_attacking(value: bool) -> void:
	can_attack = value
	if not value:
		pawn_attacked.emit()
