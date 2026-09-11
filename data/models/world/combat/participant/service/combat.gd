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

	if _handle_pending_travel(is_player):
		return
	if not res.curr_pawn.can_act() or not is_player:
		res.stage = res.STAGE_SELECT_PAWN
	elif res.curr_pawn.can_act() and is_player:
		res.stage = res.STAGE_SHOW_ACTIONS


func _handle_pending_travel(is_player: bool) -> bool:
	var level: TacticsLevel = _battle_level()
	if level == null or level.multiverse.pending_travel.is_empty():
		return false
	var mv: MultiverseController = level.multiverse
	if level.is_remote_pawn(res.curr_pawn):
		return true
	var rule: Dictionary = mv.travel_rule(String(mv.pending_travel.get("move_id", "")))
	var options: Array = mv.pending_travel.get("options", [])
	if bool(rule.get("random", false)):
		return mv.commit_travel(mv.pick_random_option())
	if bool(rule.get("force_new", false)) or (options.size() == 1 and String((options[0] as Dictionary).get("kind", "")) == "new" and not is_player and not mv.cpu_policy.is_valid()):
		return mv.commit_travel(0)
	if not is_player:
		var choice: int = mv.cpu_choice()
		if choice >= 0:
			return mv.commit_travel(choice)
		mv.cancel_travel()
		return false
	res.stage = res.STAGE_SELECT_TRAVEL
	mv.show_travel_preview()
	return true


func _battle_level() -> TacticsLevel:
	var node: Node = res.curr_pawn
	while node != null:
		if node is TacticsLevel:
			return node as TacticsLevel
		node = node.get_parent()
	return null


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
