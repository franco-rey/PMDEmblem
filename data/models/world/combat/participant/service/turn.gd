class_name TacticsParticipantTurnService
extends RefCounted

var res: TacticsParticipantResource
var camera: TacticsCameraResource
var controls: TacticsControlsResource


func _init(_res: TacticsParticipantResource, _camera: TacticsCameraResource, _controls: TacticsControlsResource) -> void:
	res = _res
	camera = _camera
	controls = _controls


func handle_human_turn(delta: float, actor_parent: Node3D, target_parent: Node3D, participant: TacticsParticipant) -> void:
	res.targets = target_parent
	if res.turn_just_started:
		camera.target = actor_parent.get_children().front()
		res.turn_just_started = false

	controls.lock_horizontal_pan = res.stage in [res.STAGE_DISPLAY_TARGETS, res.STAGE_SELECT_ATTACK_TARGET, res.STAGE_SELECT_THROW_TARGET]
	controls.set_actions_menu_visibility(res.stage in [res.STAGE_SHOW_ACTIONS, res.STAGE_SHOW_MOVEMENTS, res.STAGE_SELECT_LOCATION, res.STAGE_DISPLAY_TARGETS, res.STAGE_SELECT_ATTACK_TARGET], res.curr_pawn)

	match res.stage:
		res.STAGE_SELECT_PAWN: controls.select_pawn(actor_parent)
		res.STAGE_SHOW_ACTIONS: participant.player.show_available_pawn_actions()
		res.STAGE_SHOW_MOVEMENTS: participant.player.show_available_movements()
		res.STAGE_SELECT_LOCATION: controls.select_new_location()
		res.STAGE_MOVE_PAWN: participant.player.move_pawn()
		res.STAGE_SELECT_MOVE: controls.select_move()
		res.STAGE_DISPLAY_TARGETS: participant.player.display_attackable_targets()
		res.STAGE_SELECT_ATTACK_TARGET: controls.select_pawn_to_attack()
		res.STAGE_ATTACK: participant.serv.combat_service.attack_pawn(delta, true)
		res.STAGE_SELECT_ITEM_ACTION: controls.select_item_action()
		res.STAGE_SELECT_THROW_TARGET: controls.select_throw_target()
		res.STAGE_ITEM_ACTION: participant.serv.combat_service.perform_item_action(delta, true)
		res.STAGE_SELECT_TRAVEL: controls.select_travel()


func handle_ai_turn(delta: float, actor_parent: Node3D, target_parent: Node3D, participant: TacticsParticipant) -> void:
	res.targets = target_parent
	controls.set_actions_menu_visibility(false, null)
	controls.lock_horizontal_pan = false
	if camera.spectator:
		camera.target = null
	if res.stage > 4:
		res.stage = 0
		DebugLog.debug_nospam("turn_stage", res.stage)
	match res.stage:
		res.STAGE_SELECT_PAWN: participant.opponent.opponent_serv.choose_pawn(actor_parent)
		res.STAGE_SHOW_ACTIONS: participant.opponent.opponent_serv.chase_nearest_enemy(actor_parent, target_parent)
		res.STAGE_SHOW_MOVEMENTS: participant.opponent.opponent_serv.is_pawn_done_moving()
		res.STAGE_SELECT_LOCATION: participant.opponent.opponent_serv.choose_pawn_to_attack()
		res.STAGE_MOVE_PAWN: participant.serv.combat_service.attack_pawn(delta, false)


func handle_player_turn(delta: float, player: TacticsPlayer, participant: TacticsParticipant) -> void:
	handle_human_turn(delta, player, participant.get_node("%TacticsOpponent"), participant)


func handle_opponent_turn(delta: float, opponent: TacticsOpponent, participant: TacticsParticipant) -> void:
	handle_ai_turn(delta, opponent, participant.get_node("%TacticsPlayer"), participant)


func can_act(parent: Node3D) -> bool:
	for p: TacticsPawn in parent.get_children():
		if p.can_act():
			return true
	return false


func reset_turn(parent: Node3D) -> void:
	res.turn_just_started = true
	for p: TacticsPawn in parent.get_children():
		p.reset_turn()


func skip_turn(fallback_parent: Node3D) -> void:
	if res.curr_pawn != null:
		res.curr_pawn.end_pawn_turn()
		res.stage = res.STAGE_SELECT_PAWN
		return
	for pawn: TacticsPawn in fallback_parent.get_children():
		pawn.end_pawn_turn()
	res.stage = res.STAGE_SELECT_PAWN
