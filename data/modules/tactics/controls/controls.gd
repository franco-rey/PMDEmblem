class_name TacticsControls
extends Control

@export var controls: TacticsControlsResource = load("res://data/models/view/control/tactics/control.tres")
@export var t_cam: TacticsCameraResource = load("res://data/models/view/camera/tactics/camera.tres")
@export var participant: TacticsParticipantResource = load("res://data/models/world/combat/participant/participant.tres")
@export var arena: TacticsArenaResource = load("res://data/models/world/combat/arena/arena.tres")

var curr_pawn: TacticsPawn = null
var serv: TacticsControlsService

@onready var mouse_click_capture: InputCapture = $MouseClickCapture

func _ready() -> void:
	serv = TacticsControlsService.new(controls, t_cam, participant, arena, mouse_click_capture)
	serv.setup(self)

	for action: String in controls.actions.keys():
		var str_name: StringName = controls.actions[action]
		get_act(action).connect("pressed", Callable(self, str_name))

func _physics_process(delta: float) -> void:
	serv.physics_process(delta, self)

func _input(event: InputEvent) -> void:
	serv.handle_input(event)

func set_cursor_shape_to_move() -> void:
	CursorService.set_cursor_shape_to_move()


func set_cursor_shape_to_arrow() -> void:
	CursorService.set_cursor_shape_to_arrow()


func move_camera(delta: float) -> void:
	serv.move_camera(delta)


func camera_rotation_inputs(delta: float) -> void:
	serv.camera_rotation_inputs(delta)


func get_act(action: String) -> Button:
	return %Actions.get_node(action)


func get_actions() -> Control:
	return %Actions


func is_mouse_hovering_ui_elem() -> bool:
	return serv.is_mouse_hovering_ui_elem(self)


func set_actions_menu_visibility(v: bool, p: TacticsPawn) -> void:
	serv.set_actions_menu_visibility(v, p, self)


func get_3d_canvas_mouse_position(collision_mask: int) -> Object:
	return serv.get_3d_canvas_mouse_position(collision_mask, self)


func select_pawn(player: Node3D) -> void:
	serv.select_pawn(player, self)


func select_new_location() -> void:
	serv.select_new_location(self)


func select_pawn_to_attack() -> void:
	serv.select_pawn_to_attack(self)


func select_move() -> void:
	serv.select_move(self)


func select_travel() -> void:
	serv.select_travel(self)


func _player_wants_to_travel(option_index: int) -> void:
	(serv.ui_service as TacticsUIService).set_travel_picker_visibility(false, self, {})
	serv.pawn_selection_service.player_wants_to_travel(option_index)


func _player_previews_travel(option_index: int) -> void:
	var level: TacticsLevel = get_tree().root.find_child("TacticsLevel", true, false) as TacticsLevel
	if level != null and level.multiverse != null:
		level.multiverse.highlight_travel_option(option_index)


func _player_wants_to_cancel_travel() -> void:
	(serv.ui_service as TacticsUIService).set_travel_picker_visibility(false, self, {})
	serv.pawn_selection_service.player_wants_to_cancel_travel()


func select_item_action() -> void:
	serv.select_item_action(self)


func select_throw_target() -> void:
	serv.select_throw_target(self)


func _player_wants_to_use_item() -> void:
	serv.player_wants_to_use_item()


func _player_wants_to_select_item_use() -> void:
	var picker: Control = get_node_or_null("HBox/ItemPicker") as Control
	if participant == null or participant.stage != participant.STAGE_SELECT_ITEM_ACTION:
		return
	if picker != null and not picker.visible:
		return
	serv.player_wants_to_select_item_use()
	if picker != null and participant.stage != participant.STAGE_SELECT_ITEM_ACTION:
		picker.visible = false


func _player_wants_to_select_item_throw() -> void:
	var picker: Control = get_node_or_null("HBox/ItemPicker") as Control
	if participant == null or participant.stage != participant.STAGE_SELECT_ITEM_ACTION:
		return
	if picker != null and not picker.visible:
		return
	serv.player_wants_to_select_item_throw()
	if picker != null and participant.stage != participant.STAGE_SELECT_ITEM_ACTION:
		picker.visible = false


func _player_wants_to_cancel_item_picker() -> void:
	var picker: Control = get_node_or_null("HBox/ItemPicker") as Control
	if participant == null or participant.stage != participant.STAGE_SELECT_ITEM_ACTION:
		return
	if picker != null and not picker.visible:
		return
	serv.player_wants_to_cancel()
	if participant.stage == participant.STAGE_SHOW_ACTIONS:
		serv.set_actions_menu_visibility(true, participant.curr_pawn, self)


func _player_wants_to_move() -> void:
	serv.player_wants_to_move()


func _player_wants_to_cancel() -> void:
	serv.player_wants_to_cancel()


func _player_wants_to_cancel_move_picker() -> void:
	var picker: Control = get_node_or_null("HBox/MovePicker") as Control
	if participant == null or participant.stage != participant.STAGE_SELECT_MOVE:
		return
	if picker != null and not picker.visible:
		return
	serv.player_wants_to_cancel()
	if participant.stage == participant.STAGE_SHOW_ACTIONS:
		serv.set_actions_menu_visibility(true, participant.curr_pawn, self)


func _player_wants_to_wait() -> void:
	serv.player_wants_to_wait()


func _player_wants_to_skip_turn() -> void:
	serv.player_wants_to_skip_turn()


func _player_wants_to_attack() -> void:
	serv.player_wants_to_attack()


func _player_wants_to_select_move(slot_index: int) -> void:
	var picker: Control = get_node_or_null("HBox/MovePicker") as Control
	if participant == null or participant.stage != participant.STAGE_SELECT_MOVE:
		return
	if picker != null and not picker.visible:
		return
	serv.player_wants_to_select_move(slot_index)
	if picker != null and participant.stage != participant.STAGE_SELECT_MOVE:
		picker.visible = false
