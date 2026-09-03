class_name TacticsParticipantCombatService
extends RefCounted

var res: TacticsParticipantResource
var camera: TacticsCameraResource
var controls: TacticsControlsResource


func _init(_res: TacticsParticipantResource, _camera: TacticsCameraResource, _controls: TacticsControlsResource) -> void:
	res = _res
	camera = _camera
	controls = _controls


func attack_pawn(delta: float, is_player: bool) -> void:
	if res.pending_intent != null and res.pending_intent.actor != res.curr_pawn:
		res.pending_intent = null
		res.throw_options = []
	if res.pending_intent != null and res.pending_intent.is_item_action():
		perform_item_action(delta, is_player)
		return
	if not res.attackable_pawn:
		res.curr_pawn.res.can_attack = false
	else:
		if not res.curr_pawn.attack_target_pawn(res.attackable_pawn, delta):
			return
		controls.set_actions_menu_visibility(false, res.attackable_pawn)
		camera.target = res.curr_pawn

	res.attackable_pawn = null
	if res.display_opponent_stats:
		res.display_opponent_stats = false

	if not res.curr_pawn.can_act() or not is_player:
		res.stage = res.STAGE_SELECT_PAWN
	elif res.curr_pawn.can_act() and is_player:
		res.stage = res.STAGE_SHOW_ACTIONS


func perform_item_action(delta: float, is_player: bool) -> void:
	var pawn: TacticsPawn = res.curr_pawn
	if res.pending_intent != null and res.pending_intent.actor != pawn:
		res.pending_intent = null
	if pawn == null or res.pending_intent == null:
		res.pending_intent = null
		res.stage = res.STAGE_SHOW_ACTIONS if is_player else res.STAGE_SELECT_PAWN
		return
	if not pawn.perform_intent(res.pending_intent, delta):
		return
	controls.set_actions_menu_visibility(false, pawn)
	camera.target = pawn
	res.pending_intent = null
	res.attackable_pawn = null
	res.throw_options = []
	if res.display_opponent_stats:
		res.display_opponent_stats = false
	if not pawn.can_act() or not is_player:
		res.stage = res.STAGE_SELECT_PAWN
	else:
		res.stage = res.STAGE_SHOW_ACTIONS
