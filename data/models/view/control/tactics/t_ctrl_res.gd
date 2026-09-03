class_name TacticsControlsResource
extends Resource

signal called_set_actions_menu_visibility
signal called_move_camera
signal called_camera_rotation
signal called_select_pawn
signal called_select_pawn_to_attack
signal called_select_move
signal called_select_item_action
signal called_select_throw_target
signal called_select_new_location
signal called_set_cursor_shape_to_move
signal called_set_cursor_shape_to_arrow

const PREVIEW_NONE: String = ""
const PREVIEW_MOVEMENT: String = "movement"
const PREVIEW_MOVE_SLOT: String = "move_slot"

@export var is_joystick: bool
@export var input_hints_folded: bool
var preview_mode: String = PREVIEW_NONE
var preview_move_slot_index: int = -1

var actions: Dictionary = {
	"Move": "_player_wants_to_move",
	"Wait": "_player_wants_to_wait",
	"Cancel": "_player_wants_to_cancel",
	"Attack": "_player_wants_to_attack",
	"Item": "_player_wants_to_use_item",
	"Debug_next_turn": "_player_wants_to_skip_turn"
}


func set_actions_menu_visibility(v: bool, p: Variant) -> void:
	called_set_actions_menu_visibility.emit(v, p if p is TacticsPawn and is_instance_valid(p) else null)


func move_camera(delta: float) -> void:
	called_move_camera.emit(delta)


func camera_rotation_inputs(delta: float) -> void:
	called_camera_rotation.emit(delta)


func select_pawn(player: Node3D) -> void:
	called_select_pawn.emit(player)


func select_pawn_to_attack() -> void:
	called_select_pawn_to_attack.emit()


func select_move() -> void:
	called_select_move.emit()


func select_item_action() -> void:
	called_select_item_action.emit()


func select_throw_target() -> void:
	called_select_throw_target.emit()


func select_new_location() -> void:
	called_select_new_location.emit()


func set_cursor_shape_to_move() -> void:
	called_set_cursor_shape_to_move.emit()


func set_cursor_shape_to_arrow() -> void:
	called_set_cursor_shape_to_arrow.emit()


func preview_movement() -> void:
	preview_mode = PREVIEW_MOVEMENT
	preview_move_slot_index = -1


func preview_move_slot(slot_index: int) -> void:
	preview_mode = PREVIEW_MOVE_SLOT
	preview_move_slot_index = slot_index


func clear_preview_movement() -> void:
	if preview_mode == PREVIEW_MOVEMENT:
		clear_hover_preview()


func clear_preview_move_slot(slot_index: int) -> void:
	if preview_mode == PREVIEW_MOVE_SLOT and preview_move_slot_index == slot_index:
		clear_hover_preview()


func clear_hover_preview() -> void:
	preview_mode = PREVIEW_NONE
	preview_move_slot_index = -1
