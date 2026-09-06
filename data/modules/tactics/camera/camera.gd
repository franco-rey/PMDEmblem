class_name TacticsCamera
extends CharacterBody3D

@export var res: TacticsCameraResource = load("res://data/models/view/camera/tactics/camera.tres")
@export var controls: TacticsControlsResource = load("res://data/models/view/control/tactics/control.tres")

var serv: TacticsCameraService

@onready var t_pivot: Node3D = $TwistPivot
@onready var p_pivot: Node3D = $TwistPivot/PitchPivot
@onready var cam_node: Camera3D = $TwistPivot/PitchPivot/Camera3D


func _ready() -> void:
	serv = TacticsCameraService.new(res, controls)
	serv.setup(self, cam_node)
	res.boundary_center = global_position
	res.connect("called_rotate_camera", rotate_camera)
	res.connect("called_move_camera", move_camera)
	res.connect("called_snap_orbit", snap_orbit)


func _process(delta: float) -> void:
	serv.process(delta / maxf(Engine.time_scale, 0.001), self)


func _unhandled_input(event: InputEvent) -> void:
	serv.handle_input(event)


func move_camera(h: float, v: float, joystick: bool, delta: float) -> void:
	serv.move.move_camera(h, v, joystick, delta, self)


func rotate_camera(delta: float, twist: int = 0) -> void:
	res.is_rotating = true
	serv.rotate.add_angle_to_horiz_rotation(twist)
	serv.rotate.rotate_camera(delta, t_pivot, p_pivot)


func snap_orbit(direction: int) -> void:
	serv.rotate.snap_orbit_to_quadrant(self, direction)


func free_look(delta: float) -> void:
	serv.rotate.free_look(delta, t_pivot, p_pivot)


func zoom_camera(zoom_increment: float) -> void:
	serv.zoom.zoom_camera(zoom_increment)


func reset_cam_zoom() -> void:
	serv.zoom.reset_cam_zoom(cam_node, self)
