class_name TacticsParticipantService
extends RefCounted

var res: TacticsParticipantResource
var camera: TacticsCameraResource
var controls: TacticsControlsResource
var turn_service: TacticsParticipantTurnService
var combat_service: TacticsParticipantCombatService


func _init(_res: TacticsParticipantResource, _camera: TacticsCameraResource, _controls: TacticsControlsResource) -> void:
	res = _res
	camera = _camera
	controls = _controls
	turn_service = TacticsParticipantTurnService.new(res, camera, controls)
	combat_service = TacticsParticipantCombatService.new(res, camera, controls)


func setup(_participant: TacticsParticipant) -> void:
	if not controls:
		push_error("TacticsControls needs a ControlResource from /data/models/view/control/tactics/")
	if not camera:
		push_error("TacticsCamera needs a CameraResource from /data/models/view/camera/tactics/")
	if not res:
		push_error("TacticsParticipant needs a ParticipantResource from /data/models/world/combat/participant/")


func act(delta: float, is_player: bool, parent: Node3D, participant: TacticsParticipant) -> void:
	DebugLog.debug_nospam("participant_turn", is_player)
	DebugLog.debug_nospam("turn_stage", res.stage)

	if is_player:
		var player: TacticsPlayer = parent as TacticsPlayer
		turn_service.handle_player_turn(delta, player, participant)
	else:
		var opponent: TacticsOpponent = parent as TacticsOpponent
		turn_service.handle_opponent_turn(delta, opponent, participant)


func configure(my_camera: Resource, my_control: Resource) -> void:
	camera = my_camera
	controls = my_control


func is_configured(parent: Node3D) -> bool:
	return parent.is_pawn_configured()


func can_act(parent: Node3D) -> bool:
	return turn_service.can_act(parent)


func reset_turn(parent: Node3D) -> void:
	turn_service.reset_turn(parent)


func skip_turn(player: TacticsPlayer) -> void:
	turn_service.skip_turn(player)
