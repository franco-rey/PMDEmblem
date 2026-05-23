class_name TacticsLevel
extends Node3D
## Tactics system initialization & turn_stage management.
##
## Hosts the Speed-ordered initiative scheduler (M3) or, when the
## `use_speed_scheduler` flag is off, the legacy player-then-opponent loop.
## Combat resolution (M2) is unchanged either way.[br][br]
## Dependencies: [TacticsArena], [TacticsTile], [TacticsCamera], [TacticsControls], [TacticsParticipant], [TacticsOpponent], [TacticsPlayer], [TacticsPawn], [BattleScheduler]

#region: --- Props ---
const RESULT_ONGOING: int = 0
const RESULT_PLAYER_WIN: int = 1
const RESULT_PLAYER_LOSS: int = 2
const TYPE_CHART_PATH: String = "res://data/models/pokemon/generated/types/type_chart.tres"

## Camera resource for the tactics system
@export var camera: TacticsCameraResource = load("res://data/models/view/camera/tactics/camera.tres")
## Radius of the camera boundary
@export var camera_boundary_radius: float = 10.0
## UI control resource for the tactics system
@export var ui_control: TacticsControlsResource = load("res://data/models/view/control/tactics/control.tres")
## M3: drive the battle from the Speed-ordered scheduler instead of the legacy
## team-phase loop. Defaults to true; flip to false in a scene to fall back to
## the legacy loop while diagnosing scheduler regressions.
@export var use_speed_scheduler: bool = true
## Reference to the TacticsParticipant node
var participant: TacticsParticipant
## Reference to the TacticsPlayer node
var player: TacticsPlayer = null
## Reference to the TacticsOpponent node
var opponent: TacticsOpponent
## Reference to the TacticsArena node
var arena: TacticsArena
## Current turn stage (0: init, 1: handle) - only consulted in legacy mode
var turn_stage: int = 0
## Battle-scoped RNG. M4+ will inject the seed; M3 keeps it fixed at 0 so
## seeded skirmishes (and the scheduler's tie-break) are reproducible.
var battle_rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Battle event stream. M2 prints it; later milestones can attach UI consumers.
var battle_log: BattleLog = BattleLog.new()
var battle_finished: bool = false
## M3 scheduler. Null until `_start_scheduler()` runs (once both participants
## report configured).
var scheduler: BattleScheduler = null
## Flat list of [BattleUnit] adapters, one per spawned pawn. Mirrors the
## scene's pawns; the scheduler reads its queue from here.
var battle_units: Array[BattleUnit] = []
var _scheduler_started: bool = false
var _type_chart: TypeChartResource = null
#endregion

#region: --- Processing ---
func _ready() -> void:
	battle_rng.seed = 0
	battle_log.event_appended.connect(_on_battle_event_appended)
	if not ui_control:
		push_error("TacticsControls needs a ControlResource from /data/models/view/control/tactics/")
	if not camera:
		push_error("TacticsCamera needs a CameraResource from /data/models/view/camera/tactics/")

	# Initialize node references
	participant = $TacticsParticipant
	player = $TacticsParticipant/TacticsPlayer
	opponent = $TacticsParticipant/TacticsOpponent
	arena = $TacticsArena

	arena.configure_tiles() # Configure arena tiles
	participant.configure(camera, ui_control) # Configure participant with camera and UI control

	# Update camera boundary radius if necessary
	if camera.boundary_radius != camera_boundary_radius:
		camera.boundary_radius = camera_boundary_radius

	if use_speed_scheduler:
		scheduler = BattleScheduler.new()
		scheduler.turn_started.connect(_on_turn_started)

func _physics_process(delta: float) -> void:
	if battle_finished:
		return
	if use_speed_scheduler:
		_run_scheduler_loop(delta)
	else:
		match turn_stage:
			0: _init_turn() # Initialize turn
			1: _handle_turn(delta) # Handle ongoing turn
	_check_and_handle_battle_end()
#endregion

#region: --- Methods ---
## Checks requirements to begin the first turn.[br]Used by [TacticsPlayer], [TacticsOpponent]
func _init_turn() -> void:
	if participant.is_configured(player) and participant.is_configured(opponent):
		turn_stage = 1 # Move to turn handling stage if both player and opponent are configured

## Turn state management.[br]Used by [TacticsPlayer], [TacticsOpponent]
func _handle_turn(delta: float) -> void:
	DebugLog.debug_nospam("player_can_act", participant.can_act(player))

	if participant.can_act(player):
		if not participant.is_configured(player):
			participant.configure(camera, ui_control) # Configure player if not already done
		participant.act(delta, true, player) # Player's turn to act

	elif participant.can_act(opponent):
		if not participant.is_configured(opponent):
			participant.configure(camera, ui_control) # Configure opponent if not already done
		participant.act(delta, false, opponent) # Opponent's turn to act

	else:
		if DebugLog.debug_enabled:
			print_rich("[color=green]0Oo◦° O-----------------------------------O °◦oO0[/color]")
			print_rich("[color=green]0Oo◦°[/color][color=red] >}=----->> [/color][color=yellow][ Turn reset! ][/color][color=red] <<-----={< [/color][color=green]°◦oO0[/color]")
			print_rich("[color=green]0Oo◦° O-----------------------------------O °◦oO0[/color]")
		player.reset_turn(player) # Reset player's turn
		opponent.reset_turn(opponent) # Reset opponent's turn
#endregion


## M3 main loop. Runs while `use_speed_scheduler` is true.
##
## Flow per physics frame:
##   1. Lazily start the scheduler once both participants are configured.
##   2. Sweep any newly-fainted units out of the scheduler's queue.
##   3. If the active unit can no longer act, complete its turn.
##   4. Otherwise, hand the active unit to the matching team controller for
##      one more tick of input / animation / AI.
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

	# In scheduler mode the legacy STAGE_SELECT_PAWN is meaningless mid-turn -
	# there is only one active unit. Snap the stage back to SHOW_ACTIONS so the
	# action menu / opponent stage machine keeps moving.
	if participant.res.stage == participant.res.STAGE_SELECT_PAWN:
		participant.res.stage = participant.res.STAGE_SHOW_ACTIONS
		participant.res.curr_pawn = pawn

	var is_player: bool = unit.control_type == PokemonInstanceResource.ControlType.PLAYER
	var team_parent: Node3D = player if is_player else opponent

	if not participant.is_configured(team_parent):
		participant.configure(camera, ui_control)

	participant.act(delta, is_player, team_parent)
	_sweep_fainted_units()


func _start_scheduler() -> void:
	battle_units = _build_battle_units()
	scheduler.start_battle(battle_units, int(battle_rng.seed))
	_scheduler_started = true


func _build_battle_units() -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	var insertion: int = 0
	for team_node in [player, opponent]:
		var team_kind: int = PokemonInstanceResource.Team.PLAYER if team_node == player else PokemonInstanceResource.Team.ENEMY
		var control_kind: int = PokemonInstanceResource.ControlType.PLAYER if team_node == player else PokemonInstanceResource.ControlType.AI
		for child in team_node.get_children():
			if child is TacticsPawn:
				var p: TacticsPawn = child
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
	pawn.reset_turn()
	pawn.res.use_legacy_attack_fallback = false
	if not pawn.stats.move_slots.is_empty():
		var idx: int = pawn.stats.first_usable_move_index(false)
		pawn.res.selected_move_index = max(0, idx)

	var p_res: TacticsParticipantResource = participant.res
	p_res.curr_pawn = pawn
	p_res.stage = p_res.STAGE_SHOW_ACTIONS
	p_res.attackable_pawn = null
	p_res.display_opponent_stats = false
	# Camera focuses on the active unit regardless of team. The legacy
	# `turn_just_started` flag would otherwise snap focus to the first player
	# pawn; suppress it so the scheduler's choice wins.
	p_res.turn_just_started = false
	camera.target = pawn

	battle_log.append({
		"kind": "turn_started",
		"unit": pawn,
		"team": unit.team,
	})


func get_type_chart() -> TypeChartResource:
	if _type_chart == null:
		_type_chart = load(TYPE_CHART_PATH) as TypeChartResource
	return _type_chart


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
		# In scheduler mode this branch can be reached if one team has zero
		# living units (covered by `is_battle_over`) but the result helper
		# treats a missing team as "ongoing". Default to a player loss in that
		# pathological case so the battle still terminates cleanly.
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
