class_name TacticsParticipant
extends Node3D

@export var res: TacticsParticipantResource = load("res://data/models/world/combat/participant/participant.tres")
@export var camera: TacticsCameraResource = load("res://data/models/view/camera/tactics/camera.tres")
@export var controls: TacticsControlsResource = load("res://data/models/view/control/tactics/control.tres")
var serv: TacticsParticipantService
@onready var arena: TacticsArena = %TacticsArena
@onready var player: TacticsPlayer = %TacticsPlayer
@onready var opponent: TacticsOpponent = %TacticsOpponent


func _ready() -> void:
	serv = TacticsParticipantService.new(res, camera, controls)
	serv.setup(self)
	res.connect("called_skip_turn", skip_turn)


func act(delta: float, is_player: bool, parent: Node3D) -> void:
	serv.act(delta, is_player, parent, self)


func configure(my_camera: Resource, my_control: Resource) -> void:
	serv.configure(my_camera, my_control)


func is_configured(parent: Node3D) -> bool:
	return serv.is_configured(parent)


func can_act(parent: Node3D) -> bool:
	return serv.can_act(parent)


func reset_turn(parent: Node3D) -> void:
	serv.reset_turn(parent)


func skip_turn() -> void:
	serv.skip_turn(player)
