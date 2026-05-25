class_name TacticsLevel
extends Node3D

signal battle_ended(result: int)

const RESULT_ONGOING: int = 0
const RESULT_PLAYER_WIN: int = 1
const RESULT_PLAYER_LOSS: int = 2
const TYPE_CHART_PATH: String = "res://data/models/pokemon/generated/types/type_chart.tres"

@export var camera: TacticsCameraResource = load("res://data/models/view/camera/tactics/camera.tres")
@export var camera_boundary_radius: float = 10.0
@export var ui_control: TacticsControlsResource = load("res://data/models/view/control/tactics/control.tres")
@export var use_speed_scheduler: bool = true
@export var battle_seed: int = 0
var participant: TacticsParticipant
var player: TacticsPlayer = null
var opponent: TacticsOpponent
var arena: TacticsArena
var turn_stage: int = 0
var battle_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var battle_log: BattleLog = BattleLog.new()
var intrinsic_service: BattleIntrinsicService = BattleIntrinsicService.new()
var battle_conditions: Dictionary = {}
var battle_finished: bool = false
var scheduler: BattleScheduler = null
var battle_units: Array[BattleUnit] = []
var _scheduler_started: bool = false
var _type_chart: TypeChartResource = null

func _ready() -> void:
	battle_rng.seed = battle_seed
	battle_log.event_appended.connect(_on_battle_event_appended)
	if not ui_control:
		push_error("TacticsControls needs a ControlResource from /data/models/view/control/tactics/")
	if not camera:
		push_error("TacticsCamera needs a CameraResource from /data/models/view/camera/tactics/")

	participant = $TacticsParticipant
	player = $TacticsParticipant/TacticsPlayer
	opponent = $TacticsParticipant/TacticsOpponent
	arena = $TacticsArena

	arena.configure_tiles()
	participant.configure(camera, ui_control)

	if camera.boundary_radius != camera_boundary_radius:
		camera.boundary_radius = camera_boundary_radius

	if use_speed_scheduler:
		scheduler = BattleScheduler.new()
		scheduler.turn_started.connect(_on_turn_started)
		scheduler.turn_completed.connect(_on_turn_completed)
		scheduler.round_started.connect(_on_round_started)

func _physics_process(delta: float) -> void:
	if battle_finished:
		return
	if use_speed_scheduler:
		_run_scheduler_loop(delta)
	else:
		match turn_stage:
			0: _init_turn()
			1: _handle_turn(delta)
	_check_and_handle_battle_end()

func _init_turn() -> void:
	if participant.is_configured(player) and participant.is_configured(opponent):
		turn_stage = 1

func _handle_turn(delta: float) -> void:
	DebugLog.debug_nospam("player_can_act", participant.can_act(player))

	if participant.can_act(player):
		if not participant.is_configured(player):
			participant.configure(camera, ui_control)
		participant.act(delta, true, player)

	elif participant.can_act(opponent):
		if not participant.is_configured(opponent):
			participant.configure(camera, ui_control)
		participant.act(delta, false, opponent)

	else:
		if DebugLog.debug_enabled:
			print_rich("[color=green]0Oo◦° O-----------------------------------O °◦oO0[/color]")
			print_rich("[color=green]0Oo◦°[/color][color=red] >}=----->> [/color][color=yellow][ Turn reset! ][/color][color=red] <<-----={< [/color][color=green]°◦oO0[/color]")
			print_rich("[color=green]0Oo◦° O-----------------------------------O °◦oO0[/color]")
		player.reset_turn(player)
		opponent.reset_turn(opponent)


func _run_scheduler_loop(delta: float) -> void:
	if not _scheduler_started:
		if not (participant.is_configured(player) and participant.is_configured(opponent)):
			return
		_start_scheduler()
		return

	_sweep_fainted_units()

	var unit: BattleUnit = scheduler.get_active_unit()
	if unit == null:
		return

	var pawn: TacticsPawn = unit.pawn
	if pawn == null or not pawn.is_alive():
		scheduler.remove_unit(unit)
		return

	if not pawn.can_act():
		scheduler.complete_active_unit()
		return

	if participant.res.stage == participant.res.STAGE_SELECT_PAWN:
		participant.res.stage = participant.res.STAGE_SHOW_ACTIONS
		participant.res.curr_pawn = pawn

	var actor_parent: Node3D = player if unit.team == PokemonInstanceResource.Team.PLAYER else opponent
	var target_parent: Node3D = opponent if unit.team == PokemonInstanceResource.Team.PLAYER else player
	var is_human: bool = unit.control_type == PokemonInstanceResource.ControlType.PLAYER

	if not participant.is_configured(actor_parent):
		participant.configure(camera, ui_control)

	participant.act(delta, is_human, actor_parent, target_parent)
	_sweep_fainted_units()


func _start_scheduler() -> void:
	battle_conditions = {}
	battle_units = _build_battle_units()
	scheduler.start_battle(battle_units, int(battle_rng.seed))
	_scheduler_started = true
	intrinsic_service.log_battle_start(battle_units, battle_log, self)


func _build_battle_units() -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	var insertion: int = 0
	for team_node in [player, opponent]:
		var team_kind: int = PokemonInstanceResource.Team.PLAYER if team_node == player else PokemonInstanceResource.Team.ENEMY
		for child in team_node.get_children():
			if child is TacticsPawn:
				var p: TacticsPawn = child
				var control_kind: int = PokemonInstanceResource.ControlType.PLAYER if team_node == player else PokemonInstanceResource.ControlType.AI
				if p.stats != null and p.stats.pokemon_instance != null:
					control_kind = p.stats.pokemon_instance.control_type
				out.append(BattleUnit.new(p, p.stats, team_kind, control_kind, insertion))
				insertion += 1
	return out


func _sweep_fainted_units() -> void:
	if scheduler == null:
		return
	for unit in battle_units:
		if unit.pawn == null:
			continue
		if not unit.is_alive():
			scheduler.remove_unit(unit)


func _on_turn_started(unit: BattleUnit) -> void:
	if unit == null or unit.pawn == null:
		return
	var pawn: TacticsPawn = unit.pawn
	if not pawn.is_alive():
		return
	_expire_turn_start_statuses(pawn)
	intrinsic_service.on_turn_started(pawn, self, battle_log)
	pawn.reset_turn()
	pawn.res.has_acted_this_round = false
	pawn.res.use_legacy_attack_fallback = false
	if not pawn.stats.move_slots.is_empty():
		var idx: int = pawn.stats.first_usable_move_index(false)
		pawn.res.selected_move_index = max(0, idx)

	var p_res: TacticsParticipantResource = participant.res
	p_res.curr_pawn = pawn
	p_res.stage = p_res.STAGE_SHOW_ACTIONS
	p_res.attackable_pawn = null
	p_res.display_opponent_stats = false
	p_res.turn_just_started = false
	camera.target = pawn

	battle_log.append({
		"kind": "turn_started",
		"unit": pawn,
		"team": unit.team,
	})


func _expire_turn_start_statuses(pawn: TacticsPawn) -> void:
	if pawn == null or pawn.stats == null:
		return
	for status_id: String in ["protect", "counter"]:
		var removed: Dictionary = pawn.stats.remove_battle_status(status_id)
		if removed.is_empty():
			continue
		battle_log.append({
			"kind": "status_removed",
			"unit": pawn,
			"status_id": status_id,
			"source": "turn_start_expired",
		})


func _on_turn_completed(unit: BattleUnit) -> void:
	if unit == null or unit.pawn == null:
		return
	unit.pawn.res.has_acted_this_round = true


func _on_round_started() -> void:
	for unit in battle_units:
		if unit.pawn != null:
			unit.pawn.res.has_acted_this_round = false


func get_type_chart() -> TypeChartResource:
	if _type_chart == null:
		_type_chart = load(TYPE_CHART_PATH) as TypeChartResource
	return _type_chart


func set_battle_condition(condition_id: String, payload: Dictionary = {}) -> void:
	var key: String = condition_id.strip_edges().to_lower()
	if key.is_empty():
		return
	var stored: Dictionary = payload.duplicate(true)
	stored["condition_id"] = key
	battle_conditions[key] = stored


func has_battle_condition(condition_id: String) -> bool:
	var key: String = condition_id.strip_edges().to_lower()
	return not key.is_empty() and battle_conditions.has(key)


func battle_condition(condition_id: String) -> Dictionary:
	var key: String = condition_id.strip_edges().to_lower()
	var raw: Variant = battle_conditions.get(key, {})
	return raw.duplicate(true) if raw is Dictionary else {}


func current_weather() -> String:
	for key in ["rain", "sunny", "sandstorm", "hail", "snow"]:
		if battle_conditions.has(key):
			return key
	return ""


func check_battle_end(player_units: Array, enemy_units: Array) -> int:
	if _all_fainted(enemy_units):
		return RESULT_PLAYER_WIN
	if _all_fainted(player_units):
		return RESULT_PLAYER_LOSS
	return RESULT_ONGOING


func _check_and_handle_battle_end() -> void:
	if player == null or opponent == null:
		return
	if use_speed_scheduler:
		if not _scheduler_started:
			return
		if not scheduler.is_battle_over():
			return
	var result: int = check_battle_end(player.get_children(), opponent.get_children())
	if result == RESULT_ONGOING:
		if not use_speed_scheduler:
			return
		result = RESULT_PLAYER_LOSS

	battle_finished = true
	turn_stage = 2
	_refill_pp_for_units(player.get_children())
	_refill_pp_for_units(opponent.get_children())
	battle_log.append({
		"kind": "battle_ended",
		"winner": "player" if result == RESULT_PLAYER_WIN else "opponent",
	})
	battle_ended.emit(result)
	if ui_control != null:
		ui_control.set_actions_menu_visibility(false, null)


func _all_fainted(units: Array) -> bool:
	var saw_unit: bool = false
	for unit in units:
		if not unit is TacticsPawn:
			continue
		saw_unit = true
		if unit.is_alive():
			return false
	return saw_unit


func _refill_pp_for_units(units: Array) -> void:
	for unit in units:
		if unit is TacticsPawn:
			unit.stats.refill_all_pp()


func _on_battle_event_appended(event: Dictionary) -> void:
	print_rich("[color=gray]battle:[/color] %s" % _format_battle_event(event))


func _format_battle_event(event: Dictionary) -> String:
	var readable: Dictionary = event.duplicate()
	for key in ["attacker", "defender", "unit"]:
		if readable.has(key) and readable[key] is Node:
			readable[key] = (readable[key] as Node).name
	return str(readable)
