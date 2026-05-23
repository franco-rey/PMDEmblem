class_name TacticsLevel
extends Node3D
## Tactics system initialization & turn_stage management.
##
## This is the Tactics Level's topmost script.[br][br]
## Dependencies: [TacticsArena], [TacticsTile], [TacticsCamera], [TacticsControls], [TacticsParticipant], [TacticsOpponent], [TacticsPlayer], [TacticsPawn]

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
## Reference to the TacticsParticipant node
var participant: TacticsParticipant
## Reference to the TacticsPlayer node
var player: TacticsPlayer = null
## Reference to the TacticsOpponent node
var opponent: TacticsOpponent
## Reference to the TacticsArena node
var arena: TacticsArena
## Current turn stage (0: init, 1: handle)
var turn_stage: int = 0
## Battle-scoped RNG. M4+ will inject the seed; M2 keeps it fixed for repeatable tests.
var battle_rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Battle event stream. M2 prints it; later milestones can attach UI consumers.
var battle_log: BattleLog = BattleLog.new()
var battle_finished: bool = false
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

func _physics_process(delta: float) -> void:
	if battle_finished:
		return
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
	var result: int = check_battle_end(player.get_children(), opponent.get_children())
	if result == RESULT_ONGOING:
		return

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
