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
