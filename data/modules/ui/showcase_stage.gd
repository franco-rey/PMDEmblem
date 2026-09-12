class_name ShowcaseStage
extends SubViewportContainer

const VIEW_SIZE: Vector2i = Vector2i(560, 460)
const ROTATE_STEP_DEGREES: float = 45.0
const ZOOM_SPEED: float = 10.0
const MIN_ZOOM: float = 5.0
const MAX_ZOOM: float = 65.0
const DEFAULT_ZOOM: float = 30.0
const ZOOM_SMOOTHNESS: float = 0.65
const DELTA_SMOOTHING: float = 10.0
const ORTHO_PER_FOV: float = 0.1
const TURN_SPEED: float = 9.0
const ORBIT_SPEED_DEGREES: float = 20.0
const ISO_PITCH: float = 34.0
const TOP_PITCH: float = 78.0
const SNAP_STEP_DEGREES: float = 45.0
const QUADRANT_EPSILON: float = 0.001
const FL_ROT_SPEED_DIVIDER: float = 0.25
const FREE_LOOK_ROT_FACTOR: float = 2.0
const ROT_SPEED: float = 1.0
const FREE_LOOK_MIN_PITCH: float = -20.0
const FREE_LOOK_MAX_PITCH: float = 45.0

var _viewport: SubViewport = null
var _stage: Node3D = null
var _camera: Camera3D = null
var _yaw: float = 45.0
var _yaw_target: float = 45.0
var _pitch: float = ISO_PITCH
var _pitch_target: float = ISO_PITCH
var _target_fov: float = DEFAULT_ZOOM
var _current_fov: float = DEFAULT_ZOOM
var _orbit: int = 0
var _top_down: bool = false
var _free_look: bool = false
var _twist_input: float = 0.0
var _pitch_input: float = 0.0
var _focus: Vector3 = Vector3(0.0, 0.05, 0.0)
var _radius: float = 3.4
var _ortho_per_fov: float = ORTHO_PER_FOV


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.name = "ShowcaseViewport"
	_viewport.size = VIEW_SIZE
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_stage = Node3D.new()
	_stage.name = "Stage"
	_viewport.add_child(_stage)
	_build_sun()
	_build_camera()
	_build_scene()
	_orbit = 1
	set_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)


func _build_scene() -> void:
	pass


func _after_frame() -> void:
	pass


func set_zoom(fov: float) -> void:
	_target_fov = clampf(fov, MIN_ZOOM, MAX_ZOOM)
	_current_fov = _target_fov


func _process(delta: float) -> void:
	_read_camera_actions()
	if _free_look and not Input.is_action_pressed("camera_free_look"):
		_deactivate_free_look()
	if _free_look:
		_yaw_target += rad_to_deg(_twist_input * FREE_LOOK_ROT_FACTOR * delta)
		_yaw = _yaw_target
		_pitch_target = clampf(_pitch_target + rad_to_deg(_pitch_input * FREE_LOOK_ROT_FACTOR * delta), FREE_LOOK_MIN_PITCH, FREE_LOOK_MAX_PITCH)
		_pitch = _pitch_target
		_twist_input = 0.0
		_pitch_input = 0.0
	elif _orbit != 0:
		_yaw_target += float(_orbit) * ORBIT_SPEED_DEGREES * delta
		_yaw = _yaw_target
	else:
		_yaw = rad_to_deg(lerp_angle(deg_to_rad(_yaw), deg_to_rad(_yaw_target), clampf(delta * TURN_SPEED, 0.0, 1.0)))
	if not _free_look:
		_pitch = lerpf(_pitch, _pitch_target, clampf(delta * TURN_SPEED, 0.0, 1.0))
	if not is_equal_approx(_current_fov, _target_fov):
		_current_fov = lerpf(_current_fov, _target_fov, clampf(ZOOM_SMOOTHNESS * DELTA_SMOOTHING * delta, 0.0, 1.0))
	_place_camera()
	_after_frame()


func _read_camera_actions() -> void:
	if Input.is_action_just_pressed("camera_zoom_in"):
		_zoom_by(-ZOOM_SPEED)
	elif Input.is_action_just_pressed("camera_zoom_out"):
		_zoom_by(ZOOM_SPEED)
	if Input.is_action_just_pressed("camera_perspective"):
		if not _free_look:
			_top_down = not _top_down
			_pitch_target = TOP_PITCH if _top_down else ISO_PITCH
			_orbit = 0
		return
	if Input.is_action_just_pressed("camera_orbit_left"):
		_toggle_orbit(-1)
	elif Input.is_action_just_pressed("camera_orbit_right"):
		_toggle_orbit(1)
	elif Input.is_action_just_pressed("camera_rotate_left"):
		if not _free_look:
			_orbit = 0
			_yaw_target -= ROTATE_STEP_DEGREES
	elif Input.is_action_just_pressed("camera_rotate_right"):
		if not _free_look:
			_orbit = 0
			_yaw_target += ROTATE_STEP_DEGREES
	elif Input.is_action_just_pressed("camera_free_look"):
		_orbit = 0
		_free_look = true
		Input.set_default_cursor_shape(Input.CURSOR_MOVE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(-ZOOM_SPEED)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(ZOOM_SPEED)


func _zoom_by(increment: float) -> void:
	_target_fov = clampf(_target_fov + increment, MIN_ZOOM, MAX_ZOOM)


func _input(event: InputEvent) -> void:
	if _free_look and event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		_twist_input = -motion.relative.x * (FL_ROT_SPEED_DIVIDER * ROT_SPEED)
		_pitch_input = -motion.relative.y * (FL_ROT_SPEED_DIVIDER * ROT_SPEED)


func _toggle_orbit(direction: int) -> void:
	var previous: int = _orbit
	_orbit = 0 if _orbit == direction else direction
	if _orbit == 0 and previous != 0:
		_yaw_target = _next_quadrant(previous)


func _deactivate_free_look() -> void:
	_free_look = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_yaw_target = _nearest_quadrant()


func _next_quadrant(direction: int) -> float:
	var index: float = fposmod(_yaw_target, 360.0) / SNAP_STEP_DEGREES
	var stepped: float = ceilf(index - QUADRANT_EPSILON) if direction > 0 else floorf(index + QUADRANT_EPSILON)
	return stepped * SNAP_STEP_DEGREES


func _nearest_quadrant() -> float:
	return roundf(fposmod(_yaw_target, 360.0) / SNAP_STEP_DEGREES) * SNAP_STEP_DEGREES


func _place_camera() -> void:
	if _camera == null:
		return
	var yaw: float = deg_to_rad(_yaw)
	var pitch: float = deg_to_rad(_pitch)
	var flat: float = cos(pitch) * _radius
	_camera.size = _current_fov * _ortho_per_fov * (maxf(1.0, float(_viewport.size.y)) / float(VIEW_SIZE.y))
	_camera.position = _focus + Vector3(sin(yaw) * flat, sin(pitch) * _radius, cos(yaw) * flat)
	_camera.look_at_from_position(_camera.position, _focus, Vector3.UP)


func _matte(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic_specular = 0.0
	material.roughness = 0.9
	return material


func _build_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.position = Vector3(0.0, 4.0, 0.0)
	sun.rotation_degrees = Vector3(-50.0, -40.0, 0.0)
	sun.light_indirect_energy = 0.0
	sun.light_volumetric_fog_energy = 0.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_viewport.add_child(sun)
	var world := WorldEnvironment.new()
	world.name = "ShowcaseEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.68, 0.86, 1.0)
	env.ambient_light_energy = 1.25
	world.environment = env
	_viewport.add_child(world)


func _build_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "ShowcaseCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _current_fov * _ortho_per_fov * (maxf(1.0, float(_viewport.size.y)) / float(VIEW_SIZE.y))
	camera.current = true
	_viewport.add_child(camera)
	_camera = camera
	_place_camera()
