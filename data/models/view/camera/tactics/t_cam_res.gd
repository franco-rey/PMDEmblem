class_name TacticsCameraResource
extends Resource

signal called_move_camera
signal called_free_look
signal called_rotate_camera
signal edge_pan_toggled(enabled: bool)

@export_category("Movement")
@export_range(1, 100) var move_speed: int
var rot_speed: float
@export_range(1, 100) var rotation_speed: int:
	set(val):
		rot_speed = float(val) / 10.0
@export_range(0.01, 1) var smoothing: float = 0.1
var target_velocity: Vector3 = Vector3.ZERO
var target: Node3D = null:
	set(val):
		target = val
		DebugLog.debug_nospam("cam", val)

@export_category("Zoom")
@export_range(0.01, 1) var zoom_speed: float = 0.5
@export_range(0.01, 1) var zoom_smoothness: float = 0.1
@export_range(0.01, 1) var zoom_duration: float = 0.5
@export_range(0.1, 50) var min_zoom: float = 1.0
@export_range(10.0, 100.0) var max_zoom: float = 10.0
var current_fov: float = 50.0
var target_fov: float = 50.0

@export_category("Panning")
@export var boundary_radius: float = 10.0
var edge_pan_enabled: bool = false
var spectator: bool = false
var boundary_center: Vector3 = Vector3.ZERO
@export_range(1, 50) var border_pan_px_threshold: float = 1.0
@export_range(0.01, 1.0) var mouse_pan_speed: float = 0.5
@export_range(0.01, 1.0) var joy_pan_speed: float = 0.5
const PANNING_DELAY: float = 0.05
var panning_timer: float = 0.0

@export_category("Rotation")
@export_range(0.1, 10) var quad_snap_duration: float = 0.2
var is_snapping_to_quad: bool = false:
	set(val):
		is_snapping_to_quad = val
		DebugLog.debug_nospam("quad_snap", val)
var orbit_direction: int = 0
const ORBIT_SPEED_DEGREES: float = 20.0
var is_rotating: bool = false:
	set(val):
		is_rotating = val
		DebugLog.debug_nospam("cam_rotating", val)
@export var x_rot: int
@export var y_rot: int
@export var z_rot: int
const PERSPECTIVE_ISOMETRIC: String = "isometric"
const PERSPECTIVE_TOP_DOWN: String = "top_down"
const TOP_DOWN_PITCH: int = -80
var perspective: String = PERSPECTIVE_ISOMETRIC
var isometric_pitch: int = -30
var mouse_pos: Vector2
var in_free_look: bool:
	set(val):
		in_free_look = val
		DebugLog.debug_nospam("in_free_look", val)
var free_look_timer: float = 0.0
const R_JOYSTICK_X: JoyAxis = JoyAxis.JOY_AXIS_RIGHT_X
const R_JOYSTICK_Y: JoyAxis = JoyAxis.JOY_AXIS_RIGHT_Y
const CONTROLLER_DEADZONE: float = 0.1
const RIGHT_STICK_SENSITIVITY: float = 1.0
const FREE_LOOK_TIMEOUT: float = 0.05
var twist_input: float
var pitch_input: float
var viewport_size: Vector2i

func move_camera(h: float, v: float, joystick: bool, delta: float) -> void:
	called_move_camera.emit(h, v, joystick, delta)


func zoom_step(direction: int) -> void:
	target_fov = clampf(target_fov + float(signi(direction)) * zoom_speed, min_zoom, max_zoom)


func toggle_perspective() -> String:
	if perspective == PERSPECTIVE_ISOMETRIC:
		isometric_pitch = x_rot
		perspective = PERSPECTIVE_TOP_DOWN
		x_rot = TOP_DOWN_PITCH
	else:
		perspective = PERSPECTIVE_ISOMETRIC
		x_rot = isometric_pitch
	is_rotating = true
	return perspective


func toggle_orbit(direction: int) -> void:
	orbit_direction = 0 if orbit_direction == direction else direction
	is_rotating = false


func rotate_camera(delta: float, twist: float = 0.0) -> void:
	called_rotate_camera.emit(delta, twist)


func free_look(delta: float) -> void:
	called_free_look.emit(delta)
