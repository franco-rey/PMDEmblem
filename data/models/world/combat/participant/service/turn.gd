class_name TacticsParticipantTurnService
extends RefCounted

var res: TacticsParticipantResource
var camera: TacticsCameraResource
var controls: TacticsControlsResource


func _init(_res: TacticsParticipantResource, _camera: TacticsCameraResource, _controls: TacticsControlsResource) -> void:
	res = _res
	camera = _camera
	controls = _controls


func handle_player_turn(delta: float, player: TacticsPlayer, participant: TacticsParticipant) -> void:
	res.targets = participant.get_node("%TacticsOpponent")
	if res.turn_just_started:
		camera.target = player.get_children().front()
		res.turn_just_started = false

	controls.move_camera(delta)
	controls.camera_rotation_inputs(delta)
	controls.set_actions_menu_visibility(res.stage in [res.STAGE_SHOW_ACTIONS, res.STAGE_SHOW_MOVEMENTS, res.STAGE_SELECT_LOCATION, res.STAGE_DISPLAY_TARGETS, res.STAGE_SELECT_ATTACK_TARGET], res.curr_pawn)

	match res.stage:
		res.STAGE_SELECT_PAWN: controls.select_pawn(player)
		res.STAGE_SHOW_ACTIONS: player.show_available_pawn_actions()
		res.STAGE_SHOW_MOVEMENTS: player.show_available_movements()
		res.STAGE_SELECT_LOCATION: controls.select_new_location()
		res.STAGE_MOVE_PAWN: player.move_pawn()
		res.STAGE_SELECT_MOVE: controls.select_move()
		res.STAGE_DISPLAY_TARGETS: player.display_attackable_targets()
		res.STAGE_SELECT_ATTACK_TARGET: controls.select_pawn_to_attack()
		res.STAGE_ATTACK: participant.serv.combat_service.attack_pawn(delta, true)


func handle_opponent_turn(delta: float, opponent: TacticsOpponent, participant: TacticsParticipant) -> void:
	res.targets = participant.get_node("%TacticsPlayer")
	controls.set_actions_menu_visibility(false, null)
	if res.stage > 4:
		res.stage = 0
		DebugLog.debug_nospam("turn_stage", res.stage)
	match res.stage:
		res.STAGE_SELECT_PAWN: opponent.choose_pawn()
		res.STAGE_SHOW_ACTIONS: opponent.chase_nearest_enemy()
		res.STAGE_SHOW_MOVEMENTS: opponent.is_pawn_done_moving()
		res.STAGE_SELECT_LOCATION: opponent.choose_pawn_to_attack()
		res.STAGE_MOVE_PAWN: participant.serv.combat_service.attack_pawn(delta, false)


func can_act(parent: Node3D) -> bool:
	for p: TacticsPawn in parent.get_children():
		if p.can_act():
			return true
	return false


func reset_turn(parent: Node3D) -> void:
	res.turn_just_started = true
	for p: TacticsPawn in parent.get_children():
		p.reset_turn()


func skip_turn(player: TacticsPlayer) -> void:
	for pawn: TacticsPawn in player.get_children():
		pawn.end_pawn_turn()
	res.stage = res.STAGE_SELECT_PAWN
